import Foundation
import Combine
import AVFoundation
import SwiftUI
import UIKit
import UserNotifications
import BackgroundTasks

enum TimerMode: String, CaseIterable {
    case repeatCount = "repeat_count"
    case endTime = "end_time"
    case totalDuration = "total_duration"
    
    var localizedTitle: String {
        LanguageManager.shared.localized(rawValue)
    }
}

enum ReminderType: String, CaseIterable {
    case bothTimeAndCountdown = "both_time_and_countdown"
    case countdown = "countdown"
    
    var localizedTitle: String {
        LanguageManager.shared.localized(rawValue)
    }
}

class TimerManager: NSObject, ObservableObject {
    @Published var remainingTime: TimeInterval = 25 * 60 // 25 minutes in seconds
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var selectedInterval: Int = 25 {
        didSet {
            calculateTotalBlocks()
            calculateTotalCycles()
            // 如果暂停状态，应用新的时间设置
            if isPaused {
                // 关键：直接更新时间设置，确保显示正确的时间
                let cycleSeconds = TimeInterval(selectedInterval * 60)
                remainingTime = cycleSeconds
                intervalTime = cycleSeconds
                
                // 发送变更通知以更新UI
                objectWillChange.send()
                print("⌛ 暂停状态下更新间隔: \(oldValue) -> \(selectedInterval)分钟")
            } else if !isRunning {
                resetTimer()
            }
        }
    }
    @Published var selectedMode: TimerMode = .repeatCount {
        didSet {
            calculateTotalBlocks()
            calculateTotalCycles()
            if isPaused {
                // 暂停状态下切换模式，应用新的时间设置但保持暂停
                setupCurrentCycleTime(keepPaused: true)
                objectWillChange.send()
            } else if oldValue != selectedMode {
                resetTimer()
            }
        }
    }
    @Published var repeatCount: Int = 4 {
        didSet {
            calculateTotalBlocks()
            calculateTotalCycles()
            if isPaused && selectedMode == .repeatCount {
                // 在暂停状态下，如果修改了重复次数，更新UI
                objectWillChange.send()
            } else if selectedMode == .repeatCount && !isRunning && !isPaused {
                resetTimer()
            }
        }
    }
    @Published var currentRepeatCount: Int = 0
    @Published var endTime: Date = {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 18
        components.minute = 30
        return Calendar.current.date(from: components) ?? Date().addingTimeInterval(25 * 60)
    }() {
        didSet {
            calculateTotalBlocks()
            calculateTotalCycles()
            if isPaused && selectedMode == .endTime {
                // 在暂停状态下，如果修改了结束时间，更新当前周期时间和UI
                setupCurrentCycleTime(keepPaused: true)
                objectWillChange.send()
            } else if selectedMode == .endTime && !isRunning && !isPaused {
                resetTimer()
            }
        }
    }
    @Published var totalDuration: TimeInterval = 3600 {
        didSet {
            calculateTotalBlocks()
            calculateTotalCycles()
            if isPaused && selectedMode == .totalDuration {
                // 在暂停状态下，如果修改了总时长，更新当前周期时间和UI
                setupCurrentCycleTime(keepPaused: true)
                objectWillChange.send()
            } else if selectedMode == .totalDuration && !isRunning && !isPaused {
                resetTimer()
            }
        }
    }
    
    // Voice settings
    @Published var reminderType: ReminderType = .countdown
    @Published var enableBreathingPrompt: Bool = true
    
    private var timer: DispatchSourceTimer?
    private let synthesizer = AVSpeechSynthesizer()
    private var startTime: Date?
    private var lastReminderTime: Date?
    
    // 添加新的属性
    @Published var timeRemaining: TimeInterval = 0
    @Published var totalCycles: Int = 1
    @Published var currentCycle: Int = 1
    
    let availableIntervals = [1, 5, 10, 15, 25, 30, 60]
    
    // 进度属性
    private var initialTime: TimeInterval = 25 * 60
    private var intervalTime: TimeInterval = 25 * 60
    private var remainingTotalTime: TimeInterval = 3600 // 1小时，用于跟踪总时长模式下剩余的总时间
    // 专注时长统计
    private var focusActiveSeconds: TimeInterval = 0
    private var lastTickDate: Date? = nil
    
    // 添加新属性跟踪当前循环次数
    @Published var currentCycleCount: Int = 1
    @Published var totalCycleCount: Int = 1
    
    // 添加深呼吸相关属性
    @Published var isBreathing = false
    private var breathingCount = 0
    private let totalBreathingCount = 5
    
    // 添加方块进度相关属性
    @Published var totalBlocks: Int = 1
    @Published var completedBlocks: Int = 0
    
    // 倒计时段落文本
    var segmentStatusText: String {
        switch selectedMode {
        case .repeatCount:
            return "\(currentRepeatCount + 1)/\(repeatCount)"
        case .endTime:
            return "\(currentCycleCount)/\(totalCycleCount)"
        case .totalDuration:
            return "\(currentCycleCount)/\(totalCycleCount)"
        }
    }
    
    @Published var progressPercentage: CGFloat = 1.0
    
    var timeString: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // 添加新的属性来跟踪暂停/恢复读音提示播放状态
    private var hasPausedThisSession = false
    private var hasResumedThisSession = false
    
    // 添加音频会话状态监控属性
    private var audioSessionMonitorTimer: Timer?
    private var lastAudioSessionState: (isActive: Bool, category: String, mode: String)?
    
    // 添加后台任务相关属性
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var backgroundTimer: Timer?
    private let backgroundTaskIdentifier = "com.elvali.VoicePomodoro.refresh"
    private var isBackgroundTaskRegistered = false
    
    // 跳过深呼吸标志
    private var isBreathingSkipped = false
    
    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
        setupNotifications()
        startAudioSessionMonitoring()
        setupBackgroundTask()
    }
    
    // 设置后台任务
    private func setupBackgroundTask() {
        // 设置后台任务处理
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBackgroundTask),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func handleBackgroundTask() {
        // 开始后台任务
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        // 如果正在运行计时器，启动后台计时器
        if isRunning && !isPaused {
            startBackgroundTimer()
        }
    }
    
    private func startBackgroundTimer() {
        // 停止现有的后台计时器
        backgroundTimer?.invalidate()
        
        // 创建新的后台计时器
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.performBackgroundUpdate()
        }
        
        // 确保计时器在后台也能运行
        if let timer = backgroundTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func endBackgroundTask() {
        // 停止后台计时器
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        
        // 结束后台任务
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    // 修改音频会话配置
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // 设置音频会话优先级
            try audioSession.setPreferredIOBufferDuration(0.005)
            try audioSession.setPreferredSampleRate(44100.0)
            
            print("🎧 音频会话已配置 - 类别: 播放，允许后台播放")
        } catch {
            print("⚠️ 配置音频会话失败: \(error.localizedDescription)")
        }
    }
    
    // 设置通知监听，处理应用状态变化
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleAppWillResignActive() {
        // 应用进入后台时，保持音频会话激活
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            
            // 如果正在运行计时器，启动后台任务
            if isRunning && !isPaused {
                handleBackgroundTask()
            }
            
            print("🎧 应用进入后台 - 保持音频会话激活")
        } catch {
            print("⚠️ 应用进入后台时保持音频会话失败: \(error.localizedDescription)")
        }
    }
    
    @objc private func handleAppDidBecomeActive() {
        // 结束后台任务
        endBackgroundTask()
        
        // 重新设置音频会话
        setupAudioSession()
        
        // 更新计时器状态
        updateTimerOnForeground()
        
        print("🎧 应用返回前台 - 重新设置音频会话")
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .began {
            print("🎧 音频中断开始")
            // 音频被中断时的处理，例如暂停计时器
            if isRunning && !isPaused {
                pauseTimer()
            }
        } else if type == .ended {
            print("🎧 音频中断结束")
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // 用户希望恢复音频，尝试恢复计时器
                    setupAudioSession()
                    if isPaused {
                        // 可以考虑是否自动恢复计时器
                        // resumeTimer()
                    }
                }
            }
        }
    }
    
    @objc private func handleAudioRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .newDeviceAvailable:
            // 新音频设备连接（如耳机插入）
            print("🎧 新音频设备连接")
            setupAudioSession()
        case .oldDeviceUnavailable:
            // 音频设备断开（如耳机拔出）
            print("🎧 音频设备断开")
            setupAudioSession()
        default:
            print("🎧 音频路由变化: \(reason.rawValue)")
            setupAudioSession()
        }
    }
    
    // 添加音频会话监控方法
    private func startAudioSessionMonitoring() {
        // 每5秒检查一次音频会话状态
        audioSessionMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkAudioSessionState()
        }
    }
    
    private func checkAudioSessionState() {
        let session = AVAudioSession.sharedInstance()
        let currentState = (
            isActive: session.isOtherAudioPlaying,
            category: session.category.rawValue,
            mode: session.mode.rawValue
        )
        
        // 检查状态是否发生变化
        if lastAudioSessionState?.isActive != currentState.isActive ||
           lastAudioSessionState?.category != currentState.category ||
           lastAudioSessionState?.mode != currentState.mode {
            
            print("🎧 音频会话状态变化：")
            print("- 是否激活：\(currentState.isActive)")
            print("- 当前类别：\(currentState.category)")
            print("- 当前模式：\(currentState.mode)")
            
            // 如果音频会话未激活，尝试恢复
            if !currentState.isActive {
                restoreAudioSession()
            }
        }
        
        lastAudioSessionState = currentState
    }
    
    // 添加音频会话恢复机制
    private func restoreAudioSession() {
        print("🔄 尝试恢复音频会话...")
        
        // 如果当前正在播放语音，先停止
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // 重新配置音频会话
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ 音频会话恢复成功")
            
            // 如果正在运行计时器，重新播放当前状态
            if isRunning && !isPaused {
                speakCurrentState()
            }
        } catch {
            print("❌ 音频会话恢复失败: \(error.localizedDescription)")
        }
    }
    
    // 添加当前状态语音播报
    private func speakCurrentState() {
        let lang = LanguageManager.shared.isEnglish
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        
        var message = ""
        switch selectedMode {
        case .repeatCount:
            message = lang ?
                "Continuing focus session, \(minutes) minutes and \(seconds) seconds remaining" :
                "继续专注会话，还剩\(minutes)分\(seconds)秒"
        case .endTime:
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let endTimeStr = formatter.string(from: endTime)
            message = lang ?
                "Continuing focus session until \(endTimeStr), \(minutes) minutes and \(seconds) seconds remaining" :
                "继续专注会话直到\(endTimeStr)，还剩\(minutes)分\(seconds)秒"
        case .totalDuration:
            message = lang ?
                "Continuing focus session, \(minutes) minutes and \(seconds) seconds remaining" :
                "继续专注会话，还剩\(minutes)分\(seconds)秒"
        }
        
        speakMessage(message)
    }
    
    // 在关键操作前确保音频会话激活
    private func ensureAudioSessionActive() {
        let session = AVAudioSession.sharedInstance()
        if !session.isOtherAudioPlaying {
            do {
                try session.setActive(true, options: .notifyOthersOnDeactivation)
                print("✅ 确保音频会话激活成功")
            } catch {
                print("❌ 确保音频会话激活失败: \(error.localizedDescription)")
            }
        }
    }
    
    func startTimer() {
        ensureAudioSessionActive()
        isBreathing = false
        if isPaused {
            // 直接从暂停点继续，不调用 resumeTimer，不重置时间
            isPaused = false
            isRunning = true
            lastTickDate = Date()
            startTicking()
            return
        }
        stopTimer()
        isRunning = true
        isPaused = false
        focusActiveSeconds = 0
        currentCycle = 1
        currentRepeatCount = 0 // 重置重复计数
        lastTickDate = Date()
        calculateTotalBlocks()
        calculateTotalCycles() // 计算总周期数
        startTime = Date() // <--- 新增，记录开始时间
        setupCurrentCycleTime() // 确保每次都设置本周期的倒计时
        speakStartTime()
        startTicking()
    }
    
    // 准备下一个周期的时间设置
    private func setupCurrentCycleTime(keepPaused: Bool = false, resetTime: Bool = false) {
        let cycleSeconds = TimeInterval(selectedInterval * 60)
        
        // 如果需要重置时间，根据模式设置
        if resetTime {
            switch selectedMode {
            case .repeatCount, .totalDuration:
                remainingTime = cycleSeconds
                intervalTime = cycleSeconds
            case .endTime:
                let now = Date()
                var targetEndTime = endTime
                if targetEndTime <= now {
                    targetEndTime = Calendar.current.date(byAdding: .day, value: 1, to: targetEndTime) ?? targetEndTime
                }
                let timeToEnd = targetEndTime.timeIntervalSince(now)
                remainingTime = min(cycleSeconds, max(0, timeToEnd))
                intervalTime = remainingTime
                print("⏱️ 结束时间模式重置 - 结束时间: \(targetEndTime), 剩余时间: \(Int(remainingTime/60))分钟")
            }
            
            if !keepPaused {
                startTime = Date()
            }
            print("⏱️ 重置计时: 新间隔设置为 \(Int(remainingTime/60))分钟")
            updateProgress()
            return
        }
        
        switch selectedMode {
        case .repeatCount:
            remainingTime = cycleSeconds
            intervalTime = cycleSeconds
            if !keepPaused {
                startTime = Date()
            }
        case .endTime:
            let now = Date()
            var targetEndTime = endTime
            if targetEndTime <= now {
                targetEndTime = Calendar.current.date(byAdding: .day, value: 1, to: targetEndTime) ?? targetEndTime
            }
            let timeToEnd = targetEndTime.timeIntervalSince(now)
            remainingTime = min(cycleSeconds, max(0, timeToEnd))
            intervalTime = remainingTime
            if !keepPaused {
                startTime = Date()
            }
            print("⏱️ 结束时间模式设置 - 结束时间: \(targetEndTime), 剩余时间: \(Int(remainingTime/60))分钟")
        case .totalDuration:
            let elapsedTime = TimeInterval((currentCycle - 1) * selectedInterval * 60)
            let remainingDuration = totalDuration - elapsedTime
            
            if currentCycle == totalCycles && remainingDuration < cycleSeconds {
                remainingTime = max(0, remainingDuration)
            } else {
                remainingTime = cycleSeconds
            }
            
            intervalTime = remainingTime
            if !keepPaused {
                startTime = Date()
            }
        }
        
        updateProgress()
        objectWillChange.send()
    }
    
    private func startTicking() {
        timer?.cancel()
        timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer?.schedule(deadline: .now() + 1, repeating: 1)
        timer?.setEventHandler { [weak self] in
            self?.tick()
        }
        timer?.resume()
    }
    
    private func tick() {
        guard isRunning, !isPaused, !isBreathing else { return }
        
        if remainingTime > 0 {
            // 更新实际专注时间
            let now = Date()
            if let last = lastTickDate {
                focusActiveSeconds += now.timeIntervalSince(last)
            }
            lastTickDate = now
            
            // 每秒倒计时
            remainingTime -= 1
            
            // 更新UI
            updateProgress()
            
            // 检查是否需要语音播报或深呼吸
            checkBreathingAndVoice()
        } else {
            handleIntervalCompleted()
        }
    }
    
    private func handleIntervalCompleted() {
        timer?.cancel()
        isRunning = false
        // 检查是否是最后一个周期
        let isLastCycle = checkIsLastCycle()
        if isLastCycle {
            completedBlocks = totalBlocks
            speakEndTime()
            stopTimer()
            return
        }
        // 更新已完成方块数
        updateCompletedBlocks()
        // 检查是否启用了深呼吸引导
        if enableBreathingPrompt {
            // 先播报"x分钟时间到"
            speakCycleEndNotice()
            // 延迟2秒后再开始深呼吸
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self = self else { return }
                self.startBreathing()
            }
        } else {
            // 如果没启用深呼吸，直接播放过渡提示并开始下一个周期
            speakCycleEndNotice()
            // 延迟稍稍再开始下一个周期
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self = self else { return }
                self.prepareForNextCycle()
            }
        }
    }
    
    // 检查是否是最后一个周期
    private func checkIsLastCycle() -> Bool {
        switch selectedMode {
        case .repeatCount:
            return currentRepeatCount + 1 >= repeatCount
        case .endTime:
            return Date() >= endTime
        case .totalDuration:
            let completedTime = TimeInterval(currentCycle * selectedInterval * 60)
            return completedTime >= totalDuration
        }
    }
    
    // 播放周期结束提示
    private func speakCycleEndNotice() {
        let lang = LanguageManager.shared.isEnglish
        let interval = selectedInterval
        // 所有模式统一语音内容
        let message: String
        if enableBreathingPrompt {
            message = lang ?
                "\(interval) minutes completed. Now start deep breathing." :
                "\(interval)分钟到，现在开始深呼吸"
        } else {
            message = lang ?
                "\(interval) minutes completed." :
                "\(interval)分钟到"
        }
        speakMessage(message)
    }
    
    // 准备下一个周期
    private func prepareForNextCycle() {
        isBreathing = false
        currentCycle += 1
        currentRepeatCount += 1
        print("📊 准备下一个周期: \(currentCycle)/\(totalCycles), 模式: \(selectedMode.rawValue)")
        
        // 更新已完成方块数
        updateCompletedBlocks()
        
        setupCurrentCycleTime()
        
        // 只有在不使用深呼吸功能时才需要播放新周期开始提示
        if !enableBreathingPrompt {
            speakNewCycleStart()
        }
        
        // 延迟稍稍再开始计时，给用户时间准备
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            self.isRunning = true
            self.startTicking()
        }
        
        updateProgress()
    }
    
    // 播放新周期开始提示
    private func speakNewCycleStart() {
        let lang = LanguageManager.shared.isEnglish
        let interval = selectedInterval
        let message = lang ?
            "Starting next \(interval) minutes focus time" :
            "开始下一个\(interval)分钟专注时间"
        
        speakMessage(message)
    }
    
    private func completeBreathing() {
        // 更新进度显示
        updateProgress()
        
        isBreathing = false
        // 播放完成提示
        let lang = LanguageManager.shared.isEnglish
        let completionMessage = lang ? 
            "Deep breathing completed. Let's continue focusing." :
            "深呼吸完成了，让我们继续专注。"
        
        speakMessage(completionMessage)
        
        // 2秒后开始下一个周期
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            self.isBreathing = false
            self.lastTickDate = Date()
            self.prepareForNextCycle()
        }
        
        updateProgress()
    }
    
    func announceTime(isStart: Bool) {
        if isStart {
            speakStartTime()
        } else {
            speakEndTime()
        }
    }
    
    private func speakStartTime() {
        let lang = LanguageManager.shared.isEnglish
        let interval = selectedInterval
        
        // 准备语音消息
        var message = ""
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let currentTimeStr = formatter.string(from: Date())
        
        switch selectedMode {
        case .repeatCount:
            if reminderType == .bothTimeAndCountdown {
                message = lang ?
                    "Current time is \(currentTimeStr), starting \(interval) minutes focus" :
                    "现在是\(currentTimeStr)，开始\(interval)分钟专注"
            } else {
                message = lang ?
                    "Starting \(interval) minutes focus" :
                    "开始\(interval)分钟专注"
            }
        case .endTime:
            let endTimeStr = formatter.string(from: endTime)
            if reminderType == .bothTimeAndCountdown {
                message = lang ?
                    "Focus end time is \(endTimeStr), current time is \(currentTimeStr), starting \(interval) minutes focus" :
                    "专注结束时间为\(endTimeStr)，现在是\(currentTimeStr)，开始\(interval)分钟专注"
            } else {
                message = lang ?
                    "Focus end time is \(endTimeStr), starting \(interval) minutes focus" :
                    "专注结束时间为\(endTimeStr)，开始\(interval)分钟专注"
            }
        case .totalDuration:
            let hours = Int(totalDuration) / 3600
            if reminderType == .bothTimeAndCountdown {
                message = lang ?
                    "Now it's \(currentTimeStr), in the next \(hours) hours, starting \(interval) minutes focus" :
                    "现在是\(currentTimeStr)，在接下来的\(hours)小时中，开始\(interval)分钟专注"
            } else {
                message = lang ?
                    "In the next \(hours) hours, starting \(interval) minutes focus" :
                    "在接下来的\(hours)小时中，开始\(interval)分钟专注"
            }
        }
        
        // 播放消息
        speakMessage(message)
    }
    
    private func speakCycleEndAndStart() {
        let lang = LanguageManager.shared.isEnglish
        let interval = selectedInterval
        
        // 准备语音消息
        var message = ""
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let currentTimeStr = formatter.string(from: Date())
        
        if reminderType == .bothTimeAndCountdown {
            message = lang ?
                "\(interval) minutes end, current time is \(currentTimeStr), starting \(interval) minutes focus" :
                "\(interval)分钟到，现在是\(currentTimeStr)，开始\(interval)分钟专注"
        } else {
            message = lang ?
                "\(interval) minutes end, starting \(interval) minutes focus" :
                "\(interval)分钟到，开始\(interval)分钟专注"
        }
        
        // 播放消息
        speakMessage(message)
    }
    
    private func speakEndTime() {
        let lang = LanguageManager.shared.isEnglish
        let interval = selectedInterval
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let currentTimeStr = formatter.string(from: Date())
        let totalFocusHours = Int(focusActiveSeconds) / 3600
        let totalFocusMinutes = (Int(focusActiveSeconds) % 3600) / 60
        var message = ""
        switch selectedMode {
        case .repeatCount:
            if reminderType == .bothTimeAndCountdown {
                message = lang ?
                    "Current time is \(currentTimeStr), \(repeatCount) rounds of \(interval) minutes focus time's up. Congratulations, you have focused for \(totalFocusHours) hours and \(totalFocusMinutes) minutes." :
                    "现在是\(currentTimeStr)，\(repeatCount)轮的\(interval)分钟专注时间到。恭喜你，您一共专注了\(totalFocusHours)小时\(totalFocusMinutes)分钟"
            } else {
                message = lang ?
                    "\(repeatCount)轮的\(interval)分钟专注时间到。恭喜你，您一共专注了\(totalFocusHours)小时\(totalFocusMinutes)分钟" :
                    "\(repeatCount)轮的\(interval)分钟专注时间到。恭喜你，您一共专注了\(totalFocusHours)小时\(totalFocusMinutes)分钟"
            }
        case .endTime:
            let endTimeStr = formatter.string(from: endTime)
            if reminderType == .bothTimeAndCountdown {
                message = lang ?
                    "\(interval) minutes time's up, now it's \(currentTimeStr), reaching focus end time of \(endTimeStr). Congratulations, you have focused for \(totalFocusHours) hours and \(totalFocusMinutes) minutes." :
                    "\(interval)分钟时间到，现在是\(currentTimeStr)，到达专注设定的结束时间\(endTimeStr)，恭喜你，您一共专注了\(totalFocusHours)小时\(totalFocusMinutes)分钟"
            } else {
                message = lang ?
                    "\(interval)分钟时间到，到达专注设定的结束时间\(endTimeStr)，恭喜你，您一共专注了\(totalFocusHours)小时\(totalFocusMinutes)分钟" :
                    "\(interval)分钟时间到，到达专注设定的结束时间\(endTimeStr)，恭喜你，您一共专注了\(totalFocusHours)小时\(totalFocusMinutes)分钟"
            }
        case .totalDuration:
            let totalHours = Int(totalDuration) / 3600
            if reminderType == .bothTimeAndCountdown {
                message = lang ?
                    "\(interval) minutes time's up, now it's \(currentTimeStr), completing \(totalHours) hours of focus time. Congratulations, you have focused for \(totalFocusHours) hours and \(totalFocusMinutes) minutes." :
                    "\(interval)分钟时间到，现在是\(currentTimeStr)，\(totalHours)小时的专注时间结束，恭喜你，您一共专注了\(totalFocusHours)小时\(totalFocusMinutes)分钟"
            } else {
                message = lang ?
                    "\(interval)分钟时间到，\(totalHours)小时的专注时间结束，恭喜你，您一共专注了\(totalFocusHours)小时\(totalFocusMinutes)分钟" :
                    "\(interval)分钟时间到，\(totalHours)小时的专注时间结束，恭喜你，您一共专注了\(totalFocusHours)小时\(totalFocusMinutes)分钟"
            }
        }
        speakMessage(message)
    }
    
    private func checkBreathingAndVoice() {
        // 只保留深呼吸提示，移除中间进度语音播报
        // 深呼吸只在周期结束时由 handleIntervalCompleted 触发，这里无需处理
    }
    
    private func startBreathing() {
        isBreathing = true
        breathingCount = 0
        lastTickDate = nil
        isBreathingSkipped = false
        progressPercentage = 0 // 深呼吸阶段，圆环保持空
        // 更新进度显示
        updateProgress()
        
        // 播放开始深呼吸提示
        let lang = LanguageManager.shared.isEnglish
        let breathingStartPrompt = lang ? "Let's start deep breathing, 5 times" : "让我们开始深呼吸，一共5次"
        speakMessage(breathingStartPrompt)
        
        // 2秒后开始第一次呼吸
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.performInhale()
        }
        
        updateProgress()
    }
    
    private func performInhale() {
        if isBreathingSkipped { return }
        guard breathingCount < totalBreathingCount else {
            completeBreathing()
            return
        }
        // 吸气阶段
        let lang = LanguageManager.shared.isEnglish
        let breathInPrompt = lang ? "Breathe in" : "吸气"
        speakMessage(breathInPrompt)
        // 4秒后转到呼气阶段（原为3秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.performExhale()
        }
    }
    
    private func performExhale() {
        if isBreathingSkipped { return }
        // 呼气阶段
        let lang = LanguageManager.shared.isEnglish
        let breathOutPrompt = lang ? "Breathe out" : "呼气"
        speakMessage(breathOutPrompt)
        // 4秒后完成一个周期（原为3秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self = self else { return }
            self.breathingCount += 1
            // 判断是否已完成5次呼吸
            if self.breathingCount < self.totalBreathingCount {
                // 继续下一个周期
                self.performInhale()
            } else {
                // 完成所有呼吸
                self.completeBreathing()
            }
        }
    }
    
    // 不再需要原来的continueBreathing方法，移除或注释它，避免影响新逻辑
    private func continueBreathing() {
        // 此方法已被新的呼吸流程替代
        // 保留空方法以避免潜在的引用错误
    }
    
    func pauseTimer() {
        isRunning = false
        isPaused = true
        timer?.cancel()
        timer = nil
        lastTickDate = nil
        
        // 立即停止所有语音播放，包括深呼吸提示
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // 如果正在深呼吸，重置深呼吸状态
        if isBreathing {
            isBreathing = false
            breathingCount = 0
        }
        
        // 只在本次会话未播放过暂停提示时才播放
        if !hasPausedThisSession {
            // 播放暂停提示音
            let lang = LanguageManager.shared.isEnglish
            let pauseSound = lang ? "Timer paused" : "计时器已暂停"
            speakMessage(pauseSound)
            
            // 标记已播放暂停提示
            hasPausedThisSession = true
        }
    }
    
    func resumeTimer() {
        guard isPaused else { return }
        
        // 清除暂停状态
        isPaused = false
        isRunning = true
        
        // 重要：完全使用新设置重置当前周期时间
        setupCurrentCycleTime(resetTime: true)
        
        // 更新开始计时的时间点
        lastTickDate = Date()
        
        // 恢复语音播放
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
        
        // 播放继续提示音
        if !hasResumedThisSession {
            let lang = LanguageManager.shared.isEnglish
            let resumeSound = lang ? "Timer resumed with new settings" : "计时继续，已应用新设置"
            speakMessage(resumeSound)
            
            // 标记已播放恢复提示
            hasResumedThisSession = true
        }
        
        // 开始计时
        startTicking()
    }
    
    func stopTimer() {
        isRunning = false
        isPaused = false
        timer?.cancel()
        timer = nil
        lastTickDate = nil
        
        // 停止所有语音播放
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // 重置暂停/恢复提示状态，为下一次计时清除状态
        hasPausedThisSession = false
        hasResumedThisSession = false
    }
    
    private func checkVoiceAnnouncement() {
        // 在每个间隔的开始、中间或接近结束时播放语音
        
        // 刚开始、接近结束或者每分钟提示一次
        if (remainingTime == intervalTime) || // 刚开始
           (remainingTime == 60) || // 还剩1分钟
           (remainingTime == 30) || // 还剩30秒
           (Int(remainingTime) % 60 == 0) { // 每分钟提示一次
            // 暂停计时器
            isRunning = false
            timer?.cancel()
            timer = nil
            
            announceTime(isStart: true)
        }
        
        // 呼吸提示
        if enableBreathingPrompt && Int(remainingTime) % 60 == 0 && !isBreathing {
            // 暂停计时器
            isRunning = false
            timer?.cancel()
            timer = nil
            
            // 开始深呼吸
            startBreathing()
        }
    }
    
    private func startVoiceReminder() {
        // 播放开始提示
        let startMessage: String
        switch selectedMode {
        case .repeatCount:
            startMessage = LanguageManager.shared.isEnglish ?
                "Starting \(selectedInterval) minutes focus" :
                "开始\(selectedInterval)分钟专注"
        case .endTime:
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let endTimeString = formatter.string(from: endTime)
            startMessage = LanguageManager.shared.isEnglish ?
                "Focus end time is \(endTimeString), starting \(selectedInterval) minutes focus" :
                "专注结束时间为\(endTimeString)，开始\(selectedInterval)分钟专注"
        case .totalDuration:
            let totalHours = Int(totalDuration) / 3600
            startMessage = LanguageManager.shared.isEnglish ?
                "In the next \(totalHours) hours, starting \(selectedInterval) minutes focus" :
                "在接下来的\(totalHours)小时中，开始\(selectedInterval)分钟专注"
        }
        
        speakMessage(startMessage)
    }
    
    private func updateProgress() {
        // 只有在真正深呼吸阶段且倒计时为0时才不更新进度
        if isBreathing && remainingTime == 0 {
            return
        }
        if intervalTime > 0 {
            progressPercentage = max(0, min(1, CGFloat(remainingTime / intervalTime)))
        } else {
            progressPercentage = 0
        }
        objectWillChange.send()
    }
    
    private func checkVoiceReminder() {
        let now = Date()
        
        // 检查是否需要语音提醒
        if let lastReminder = lastReminderTime {
            let timeSinceLastReminder = now.timeIntervalSince(lastReminder)
            
            // 每分钟提醒一次
            if timeSinceLastReminder >= 60 {
                announceTime(isStart: true)
                lastReminderTime = now
            }
        } else {
            // 第一次提醒
            announceTime(isStart: true)
            lastReminderTime = now
        }
        
        // 检查是否需要深呼吸提醒
        if enableBreathingPrompt && !isBreathing {
            let minutes = Int(timeRemaining) / 60
            if minutes > 0 && minutes % 5 == 0 && Int(timeRemaining) % 60 == 0 {
                startBreathing()
            }
        }
    }
    
    private func calculateTotalBlocks() {
        switch selectedMode {
        case .repeatCount:
            totalBlocks = repeatCount
        case .endTime:
            let calendar = Calendar.current
            let now = Date()
            var targetEndTime = endTime
            if targetEndTime <= now {
                targetEndTime = calendar.date(byAdding: .day, value: 1, to: targetEndTime) ?? targetEndTime
            }
            let timeRemaining = targetEndTime.timeIntervalSince(now)
            let minutes = Int(round(timeRemaining / 60))
            totalBlocks = Int(ceil(Double(minutes) / Double(selectedInterval)))
        case .totalDuration:
            let minutes = Int(round(totalDuration / 60))
            totalBlocks = Int(ceil(Double(minutes) / Double(selectedInterval)))
        }
        
        // 确保至少有一个方块
        totalBlocks = max(1, totalBlocks)
        
        // 未开始倒计时时，已完成方块数为0
        // 但如果是暂停状态，保持当前完成方块数
        if !isRunning && !isPaused {
            completedBlocks = 0
        } else if isPaused {
            // 在暂停状态下，根据当前进度重新计算已完成方块数
            updateCompletedBlocks()
        }
        
        print("📊 计算总方块数: \(totalBlocks), 模式: \(selectedMode.rawValue)")
    }
    
    private func updateCompletedBlocks() {
        switch selectedMode {
        case .repeatCount:
            // 重复计数模式下，使用当前重复次数
            completedBlocks = currentRepeatCount
        case .endTime:
            // 结束时间模式下，使用当前周期数减1
            completedBlocks = currentCycle - 1
        case .totalDuration:
            // 总时长模式下，使用当前周期数减1
            completedBlocks = currentCycle - 1
        }
        
        // 确保不会超过总方块数
        completedBlocks = min(completedBlocks, totalBlocks)
        
        // 发送更新通知
        objectWillChange.send()
        
        print("📊 更新完成方块: \(completedBlocks)/\(totalBlocks), 模式: \(selectedMode.rawValue)")
    }
    
    private func speakProgress() {
        let lang = LanguageManager.shared.isEnglish
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        
        // 构建状态信息
        var statusInfo = ""
        switch selectedMode {
        case .repeatCount:
            statusInfo = lang ? 
                "Round \(currentCycle) of \(totalCycles), " : 
                "第\(currentCycle)轮，共\(totalCycles)轮， "
        case .endTime:
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let endTimeString = formatter.string(from: endTime)
            
            statusInfo = lang ?
                "Cycle \(currentCycle) of \(totalCycles), ending at \(endTimeString), " :
                "第\(currentCycle)个周期，共\(totalCycles)个周期，结束时间\(endTimeString)， "
        case .totalDuration:
            statusInfo = lang ?
                "Cycle \(currentCycle) of \(totalCycles), " :
                "第\(currentCycle)个周期，共\(totalCycles)个周期， "
        }
        
        // 构建倒计时信息
        let countdownInfo = lang ?
            "\(minutes) minutes and \(seconds) seconds remaining" :
            "还剩\(minutes)分\(seconds)秒"
        
        // 组合完整消息
        var message = statusInfo + countdownInfo
        
        // 如果设置为显示当前时间
        if reminderType == .bothTimeAndCountdown {
            let formatter = DateFormatter()
            formatter.dateFormat = lang ? "HH:mm" : "HH点mm分"
            let timeString = formatter.string(from: Date())
            
            message = lang ?
                "Current time is \(timeString), " + message :
                "现在是\(timeString)，" + message
        }
        
        // 播放消息
        speakMessage(message)
    }
    
    private func announceTotalFocusTime() {
        let lang = LanguageManager.shared.isEnglish
        let totalFocus = Int(focusActiveSeconds)
        let hours = totalFocus / 3600
        let mins = (totalFocus % 3600) / 60
        let msg = lang ? "Focus complete! Total: \(hours) hours \(mins) minutes." : "专注完成！总计：\(hours)小时\(mins)分钟。"
        speakMessage(msg)
    }
    
    // 添加回被删除的resetTimer方法，保持之前的功能
    func resetTimer() {
        stopTimer()
        
        isBreathing = false
        isRunning = false
        isPaused = false
        startTime = nil
        lastTickDate = nil
        focusActiveSeconds = 0
        currentCycle = 1
        totalCycles = 1
        completedBlocks = 0
        
        // 重置剩余时间，根据当前模式设置
        switch selectedMode {
        case .repeatCount:
            remainingTime = TimeInterval(selectedInterval * 60)
            intervalTime = remainingTime
        case .endTime:
            let now = Date()
            var targetEndTime = endTime
            if targetEndTime <= now {
                targetEndTime = Calendar.current.date(byAdding: .day, value: 1, to: targetEndTime) ?? targetEndTime
            }
            let timeToEnd = targetEndTime.timeIntervalSince(now)
            let cycleSeconds = TimeInterval(selectedInterval * 60)
            remainingTime = min(cycleSeconds, max(0, timeToEnd))
            intervalTime = remainingTime
            print("🔄 结束时间模式重置 - 结束时间: \(targetEndTime), 剩余时间: \(Int(remainingTime/60))分钟")
        case .totalDuration:
            remainingTime = TimeInterval(selectedInterval * 60)
            intervalTime = remainingTime
        }
        
        updateProgress()
        
        lastReminderTime = nil
        breathingCount = 0
        
        // 计算正确的周期总数
        calculateTotalCycles()
        
        // 重置暂停/恢复提示状态，为下一次计时做准备
        hasPausedThisSession = false
        hasResumedThisSession = false
        
        // 发送变更通知以更新UI
        objectWillChange.send()
        
        print("🔄 重置计时器 - 模式: \(selectedMode.rawValue), 剩余时间: \(Int(remainingTime/60))分钟")
    }
    
    // 添加计算总周期数的方法
    private func calculateTotalCycles() {
        let oldTotalCycles = totalCycles
        
        switch selectedMode {
        case .repeatCount:
            totalCycles = repeatCount
            print("🔄 计算总周期 (重复计数模式): \(oldTotalCycles) -> \(totalCycles)")
        case .endTime:
            let now = Date()
            var targetEndTime = endTime
            if targetEndTime <= now {
                targetEndTime = Calendar.current.date(byAdding: .day, value: 1, to: targetEndTime) ?? targetEndTime
            }
            let timeRemaining = targetEndTime.timeIntervalSince(now)
            let minutesRemaining = timeRemaining / 60
            totalCycles = Int(ceil(minutesRemaining / Double(selectedInterval)))
            print("🔄 计算总周期 (结束时间模式): \(oldTotalCycles) -> \(totalCycles) (结束时间: \(targetEndTime))")
        case .totalDuration:
            let minutesTotal = totalDuration / 60
            totalCycles = Int(ceil(minutesTotal / Double(selectedInterval)))
            print("🔄 计算总周期 (总时长模式): \(oldTotalCycles) -> \(totalCycles) (总时长: \(Int(totalDuration/60))分钟)")
        }
        
        // 确保至少有一个周期
        totalCycles = max(1, totalCycles)
    }
    
    // 在对象销毁时清理资源
    deinit {
        audioSessionMonitorTimer?.invalidate()
        audioSessionMonitorTimer = nil
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        NotificationCenter.default.removeObserver(self)
        print("🧹 TimerManager 销毁，已移除所有通知观察者和监控器")
    }
    
    private func speakMessage(_ message: String) {
        ensureAudioSessionActive()
        // 处理中文语音，在标点符号后添加停顿
        var processedMessage = message
        if !LanguageManager.shared.isEnglish {
            processedMessage = message.replacingOccurrences(of: "，", with: "， ")
                .replacingOccurrences(of: "。", with: "。 ")
                .replacingOccurrences(of: "、", with: "、 ")
                .replacingOccurrences(of: "：", with: "： ")
        }
        let utterance = AVSpeechUtterance(string: processedMessage)
        utterance.voice = AVSpeechSynthesisVoice(language: LanguageManager.shared.isEnglish ? "en-US" : "zh-CN")
        utterance.rate = 0.5
        utterance.volume = 1.0
        utterance.pitchMultiplier = 1.0
        // 如果当前有语音播放，先停止
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .word)
        }
        // 确保在后台也能播放，并触发 duck 效果
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            // 设置音频会话优先级
            try audioSession.setPreferredIOBufferDuration(0.005)
            synthesizer.speak(utterance)
            print("🔊 播放语音: \(message)")
        } catch {
            print("⚠️ 播放语音失败: \(error.localizedDescription)")
        }
    }
    
    // 添加供应用返回前台时调用的方法
    func updateTimerOnForeground() {
        // 如果计时器正在运行，但不在暂停状态
        if isRunning && !isPaused {
            // 1. 计算应用在后台的时间
            let now = Date()
            if let lastTickTime = lastTickDate {
                let elapsedTime = now.timeIntervalSince(lastTickTime)
                
                // 2. 更新计时器状态
                if elapsedTime > 0 {
                    // 更新专注时长
                    focusActiveSeconds += elapsedTime
                    
                    // 更新剩余时间
                    let newRemainingTime = max(0, remainingTime - elapsedTime)
                    
                    // 如果时间已经到零，处理周期完成
                    if newRemainingTime <= 0 {
                        // 计算经过了多少个完整周期
                        let cycleSeconds = TimeInterval(selectedInterval * 60)
                        let completedCycles = Int(floor(elapsedTime / cycleSeconds))
                        
                        if completedCycles > 0 {
                            // 增加已完成周期数
                            currentCycle += completedCycles
                            currentRepeatCount += completedCycles
                            
                            // 检查是否已完成所有周期
                            if checkIsLastCycle() {
                                completedBlocks = totalBlocks
                                speakEndTime()
                                stopTimer()
                                return
                            }
                            
                            // 如果还有周期要继续，设置新的周期时间
                            setupCurrentCycleTime()
                            print("⏰ 应用返回前台: 已完成 \(completedCycles) 个周期，当前周期 \(currentCycle)/\(totalCycles)")
                        } else {
                            // 剩余时间到0，但不足一个周期，处理一次周期完成
                            handleIntervalCompleted()
                            return
                        }
                    } else {
                        // 更新剩余时间
                        remainingTime = newRemainingTime
                        print("⏰ 应用返回前台: 更新剩余时间为 \(Int(remainingTime/60))分\(Int(remainingTime)%60)秒")
                    }
                }
            }
            
            // 3. 更新最后计时时间
            lastTickDate = now
            
            // 4. 重启计时器
            startTicking()
        }
        
        // 更新UI
        updateProgress()
    }
    
    // 添加供后台任务调用的方法
    func performBackgroundUpdate() {
        // 只在计时器运行且未暂停时执行
        guard isRunning && !isPaused else { return }
        
        // 更新计时状态
        if let lastTime = lastTickDate {
            let now = Date()
            let elapsedTime = now.timeIntervalSince(lastTime)
            
            // 更新专注时长
            focusActiveSeconds += elapsedTime
            
            // 更新剩余时间
            remainingTime = max(0, remainingTime - elapsedTime)
            
            // 如果时间已经到零，处理周期完成
            if remainingTime <= 0 {
                // 设置通知告知用户周期已完成
                scheduleCompletionNotification()
                
                // 处理周期完成逻辑
                handleBackgroundIntervalCompleted()
            } else {
                // 如果还有时间剩余，更新最后计时时间
                lastTickDate = now
                
                // 每隔一段时间发送进度通知
                if Int(remainingTime) % 300 == 0 { // 每5分钟
                    scheduleProgressNotification()
                }
            }
        }
    }
    
    // 处理后台周期完成
    private func handleBackgroundIntervalCompleted() {
        // 检查是否是最后一个周期
        if checkIsLastCycle() {
            completedBlocks = totalBlocks
            // 发送完成通知
            scheduleAllCompletedNotification()
            stopTimer()
            return
        }
        
        // 如果不是最后一个周期，准备下一个周期
        currentCycle += 1
        currentRepeatCount += 1
        updateCompletedBlocks()
        setupCurrentCycleTime()
    }
    
    // 发送周期完成通知
    private func scheduleCompletionNotification() {
        let content = UNMutableNotificationContent()
        let lang = LanguageManager.shared.isEnglish
        content.title = lang ? "Focus Session Completed" : "专注会话完成"
        content.body = lang ? 
            "\(selectedInterval) minutes completed. Starting next cycle." :
            "\(selectedInterval)分钟完成。开始下一个周期。"
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(identifier: "cycle-completion", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 发送通知失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 发送全部完成通知
    private func scheduleAllCompletedNotification() {
        let content = UNMutableNotificationContent()
        let lang = LanguageManager.shared.isEnglish
        content.title = lang ? "All Focus Sessions Completed" : "所有专注会话完成"
        
        let totalFocusHours = Int(focusActiveSeconds) / 3600
        let totalFocusMinutes = (Int(focusActiveSeconds) % 3600) / 60
        
        content.body = lang ? 
            "Congratulations! You've focused for \(totalFocusHours) hours and \(totalFocusMinutes) minutes." :
            "恭喜你！您总共专注了\(totalFocusHours)小时\(totalFocusMinutes)分钟。"
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(identifier: "all-completed", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 发送通知失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 发送进度通知
    private func scheduleProgressNotification() {
        let content = UNMutableNotificationContent()
        let lang = LanguageManager.shared.isEnglish
        content.title = lang ? "Focus Session Progress" : "专注会话进度"
        
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        
        content.body = lang ? 
            "Cycle \(currentCycle)/\(totalCycles), \(minutes) minutes and \(seconds) seconds remaining." :
            "第\(currentCycle)/\(totalCycles)个周期，剩余\(minutes)分\(seconds)秒。"
        
        let request = UNNotificationRequest(identifier: "progress-update", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 发送通知失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 添加跳过深呼吸的方法
    func skipBreathing() {
        // 停止所有语音播放
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isBreathingSkipped = true
        // 播放跳过提示
        let lang = LanguageManager.shared.isEnglish
        let skipMessage = lang ? "Skipping deep breathing, continuing focus" : "跳过深呼吸，继续专注"
        speakMessage(skipMessage)
        // 2秒后开始下一个周期
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            self.isBreathing = false
            self.lastTickDate = Date()
            self.prepareForNextCycle()
        }
    }
}

// 修改AVSpeechSynthesizerDelegate扩展
extension TimerManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // 在呼吸模式下什么也不做，因为我们现在使用定时器控制呼吸循环
        if isBreathing {
            return
        }
        
        // 确保音频会话处于正确状态
        do {
            if !AVAudioSession.sharedInstance().isOtherAudioPlaying {
                // 如果没有其他音频播放，重新配置我们的会话以便于下次使用
                try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            }
        } catch {
            print("⚠️ 重新激活音频会话失败: \(error.localizedDescription)")
        }
        
        // 非呼吸状态，如果计时器运行中且未暂停，继续计时
        if isRunning && !isPaused {
            lastTickDate = Date()
            startTicking()
        }
    }
} 

