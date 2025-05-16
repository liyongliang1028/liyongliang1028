import Foundation
import Combine
import AVFoundation
import SwiftUI

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
            if !isRunning && !isPaused {
                resetTimer()
            }
        }
    }
    @Published var selectedMode: TimerMode = .repeatCount {
        didSet {
            calculateTotalBlocks()
            if oldValue != selectedMode {
                resetTimer()
            }
        }
    }
    @Published var repeatCount: Int = 4 {
        didSet {
            calculateTotalBlocks()
            if selectedMode == .repeatCount && !isRunning && !isPaused {
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
            if selectedMode == .endTime && !isRunning && !isPaused {
                resetTimer()
            }
        }
    }
    @Published var totalDuration: TimeInterval = 3600 {
        didSet {
            calculateTotalBlocks()
            if selectedMode == .totalDuration && !isRunning && !isPaused {
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
    
    let availableIntervals = [1, 5, 10, 15, 25, 60]
    
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
    
    var progressPercentage: CGFloat {
        let progress = 1.0 - (remainingTime / intervalTime)
        return max(0, min(1, CGFloat(progress)))
    }
    
    var timeString: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // 添加新的属性来跟踪暂停/恢复读音提示播放状态
    private var hasPausedThisSession = false
    private var hasResumedThisSession = false
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func startTimer() {
        if isPaused {
            resumeTimer()
            return
        }
        stopTimer()
        isRunning = true
        isPaused = false
        isBreathing = false
        focusActiveSeconds = 0
        currentCycle = 1
        currentRepeatCount = 0 // 重置重复计数
        lastTickDate = Date()
        calculateTotalBlocks()
        startTime = Date() // <--- 新增，记录开始时间
        setupCurrentCycleTime() // 确保每次都设置本周期的倒计时
        speakStartTime()
        startTicking()
    }
    
    private func setupCurrentCycleTime() {
        let cycleSeconds = TimeInterval(selectedInterval * 60)
        switch selectedMode {
        case .repeatCount:
            // 每轮都是完整间隔
            remainingTime = cycleSeconds
            intervalTime = cycleSeconds
            startTime = Date() // <--- 新增，记录每轮开始时间
        case .endTime:
            let now = Date()
            var targetEndTime = endTime
            if targetEndTime <= now {
                targetEndTime = Calendar.current.date(byAdding: .day, value: 1, to: targetEndTime) ?? targetEndTime
            }
            let timeToEnd = targetEndTime.timeIntervalSince(now)
            // 计算本轮剩余时间：如果剩余时间大于间隔，取间隔，否则取剩余时间
            remainingTime = min(cycleSeconds, max(0, timeToEnd))
            intervalTime = remainingTime
            startTime = Date() // <--- 新增，记录每轮开始时间
        case .totalDuration:
            let elapsedTime = TimeInterval((currentCycle - 1) * selectedInterval * 60)
            let remainingDuration = totalDuration - elapsedTime
            // 计算本轮剩余时间：如果剩余时间大于间隔，取间隔，否则取剩余时间
            remainingTime = min(cycleSeconds, max(0, remainingDuration))
            intervalTime = remainingTime
            startTime = Date() // <--- 新增，记录每轮开始时间
        }
        updateProgress()
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
        
        switch selectedMode {
        case .repeatCount:
            currentRepeatCount += 1
            if currentRepeatCount >= repeatCount {
                completedBlocks = totalBlocks
                speakEndTime()
                stopTimer()
                return
            }
            speakCycleEndAndStart()
        case .endTime:
            if Date() >= endTime {
                completedBlocks = totalBlocks
                speakEndTime()
                stopTimer()
                return
            }
            speakCycleEndAndStart()
        case .totalDuration:
            let completedTime = TimeInterval(currentCycle * selectedInterval * 60)
            if completedTime >= totalDuration {
                completedBlocks = totalBlocks
                speakEndTime()
                stopTimer()
                return
            }
            speakCycleEndAndStart()
        }
        currentCycle += 1
        updateCompletedBlocks()
        setupCurrentCycleTime() // 确保每次新周期都设置本周期的倒计时
        isRunning = true
        startTicking()
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
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: lang ? "en-US" : "zh-CN")
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        synthesizer.speak(utterance)
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
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: lang ? "en-US" : "zh-CN")
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        synthesizer.speak(utterance)
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
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: lang ? "en-US" : "zh-CN")
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }
    
    private func checkBreathingAndVoice() {
        // 只保留深呼吸提示，移除中间进度语音播报
        if enableBreathingPrompt && !isBreathing {
            // 深呼吸逻辑：当剩余时间正好是5分钟的倍数时
            let minutes = Int(remainingTime) / 60
            if minutes > 0 && minutes % 5 == 0 && Int(remainingTime) % 60 == 0 {
                // 暂停计时器
                timer?.cancel()
                isRunning = false
                
                // 开始深呼吸
                startBreathing()
                return
            }
        }
        
        // 移除周期中间的语音提示
        // 以下代码被注释掉，不再在中间播放语音
        /*
        // 语音提醒逻辑：每隔一分钟或在特定时间点
        if (remainingTime == 60) || // 还剩1分钟
           (remainingTime == 30) || // 还剩30秒
           (Int(remainingTime) % 60 == 0 && remainingTime > 0) { // 每分钟提示一次
            // 暂停计时器
            timer?.cancel()
            isRunning = false
            
            // 播报进度
            speakProgress()
        }
        */
    }
    
    private func startBreathing() {
        isBreathing = true
        breathingCount = 0
        lastTickDate = nil
        // 播放开始深呼吸提示
        let lang = LanguageManager.shared.isEnglish
        let breathingStartPrompt = lang ? "Let's deep breath" : "让我们开始深呼吸"
        let breathingStartUtterance = AVSpeechUtterance(string: breathingStartPrompt)
        breathingStartUtterance.voice = AVSpeechSynthesisVoice(language: lang ? "en-US" : "zh-CN")
        breathingStartUtterance.volume = 1.0
        synthesizer.speak(breathingStartUtterance)
    }
    
    private func continueBreathing() {
        let lang = LanguageManager.shared.isEnglish
        if breathingCount < totalBreathingCount {
            // 吸气
            let breathInPrompt = lang ? "Breathe in" : "吸气"
            let breathInUtterance = AVSpeechUtterance(string: breathInPrompt)
            breathInUtterance.voice = AVSpeechSynthesisVoice(language: lang ? "en-US" : "zh-CN")
            breathInUtterance.volume = 1.0
            synthesizer.speak(breathInUtterance)
            // 2.5秒后呼气
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                guard let self = self else { return }
                let breathOutPrompt = lang ? "Breathe out" : "呼气"
                let breathOutUtterance = AVSpeechUtterance(string: breathOutPrompt)
                breathOutUtterance.voice = AVSpeechSynthesisVoice(language: lang ? "en-US" : "zh-CN")
                breathOutUtterance.volume = 1.0
                self.synthesizer.speak(breathOutUtterance)
                self.breathingCount += 1
            }
        } else {
            // 深呼吸完成，恢复计时
            isBreathing = false
            breathingCount = 0
            lastTickDate = Date()
            // 恢复倒计时
            startTicking()
            isRunning = true
            // 自动播报新一轮开始语音
            if selectedMode == .repeatCount || selectedMode == .endTime || selectedMode == .totalDuration {
                speakStartTime()
            }
        }
    }
    
    func pauseTimer() {
        isRunning = false
        isPaused = true
        timer?.cancel()
        timer = nil
        lastTickDate = nil
        
        // 只在本次会话未播放过暂停提示时才播放
        if !hasPausedThisSession {
            // 播放暂停提示音
            let lang = LanguageManager.shared.isEnglish
            let pauseSound = lang ? "Timer paused" : "计时器已暂停"
            let utterance = AVSpeechUtterance(string: pauseSound)
            utterance.voice = AVSpeechSynthesisVoice(language: lang ? "en-US" : "zh-CN")
            utterance.pitchMultiplier = 1.0
            utterance.volume = 1.0
            synthesizer.speak(utterance)
            
            // 标记已播放暂停提示
            hasPausedThisSession = true
        }
    }
    
    func resumeTimer() {
        guard isPaused else { return }
        isPaused = false
        isRunning = true
        lastTickDate = Date()
        startTicking()
        
        // 只在本次会话未播放过恢复提示时才播放
        if !hasResumedThisSession {
            // 播放继续提示音
            let lang = LanguageManager.shared.isEnglish
            let resumeSound = lang ? "Timer resumed" : "计时继续"
            let utterance = AVSpeechUtterance(string: resumeSound)
            utterance.voice = AVSpeechSynthesisVoice(language: lang ? "en-US" : "zh-CN")
            utterance.pitchMultiplier = 1.0
            utterance.volume = 1.0
            synthesizer.speak(utterance)
            
            // 标记已播放恢复提示
            hasResumedThisSession = true
        }
    }
    
    func stopTimer() {
        isRunning = false
        isPaused = false
        timer?.cancel()
        timer = nil
        lastTickDate = nil
        
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
        
        let startUtterance = AVSpeechUtterance(string: startMessage)
        startUtterance.voice = AVSpeechSynthesisVoice(language: LanguageManager.shared.isEnglish ? "en-US" : "zh-CN")
        synthesizer.speak(startUtterance)
    }
    
    private func updateProgress() {
        // 更新进度条
        _ = 1.0 - (timeRemaining / TimeInterval(selectedInterval * 60))
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
        // 未开始倒计时时，已完成方块数为0
        if !isRunning {
            completedBlocks = 0
        }
    }
    
    private func updateCompletedBlocks() {
        switch selectedMode {
        case .repeatCount:
            completedBlocks = currentRepeatCount
        case .endTime:
            let now = Date()
            let startToNow = now.timeIntervalSince(startTime ?? now)
            let cycleDuration = TimeInterval(selectedInterval * 60)
            completedBlocks = min(Int(startToNow / cycleDuration), totalBlocks)
        case .totalDuration:
            completedBlocks = min(currentCycle - 1, totalBlocks)
        }
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
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: lang ? "en-US" : "zh-CN")
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }
    
    private func announceTotalFocusTime() {
        let lang = LanguageManager.shared.isEnglish
        let totalFocus = Int(focusActiveSeconds)
        let hours = totalFocus / 3600
        let mins = (totalFocus % 3600) / 60
        let msg = lang ? "Focus complete! Total: \(hours) hours \(mins) minutes." : "专注完成！总计：\(hours)小时\(mins)分钟。"
        let utterance = AVSpeechUtterance(string: msg)
        utterance.voice = AVSpeechSynthesisVoice(language: lang ? "en-US" : "zh-CN")
        synthesizer.speak(utterance)
    }
    
    // 添加回被删除的resetTimer方法，保持之前的功能
    func resetTimer() {
        stopTimer()
        
        isRunning = false
        isPaused = false
        startTime = nil
        lastTickDate = nil
        focusActiveSeconds = 0
        remainingTime = 0
        currentCycle = 1
        totalCycles = 1
        completedBlocks = 0
        
        updateProgress()
        
        lastReminderTime = nil
        isBreathing = false
        breathingCount = 0
        setupCurrentCycleTime() // u4fddu8bc1u91cdu7f6eu540eu5012u8ba1u65f6u4e3au4e0bu4e00u4e2au5468u671fu7684u95f4u9694
        
        // u91cdu7f6eu6682u505c/u6062u590du63d0u793au72b6u6001uff0cu4e3au4e0bu4e00u6b21u8ba1u65f6u505au51c6u5907
        hasPausedThisSession = false
        hasResumedThisSession = false
    }
}

// 修改AVSpeechSynthesizerDelegate扩展
extension TimerManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if isBreathing {
            continueBreathing()
            return
        }
        if isRunning && !isPaused {
            lastTickDate = Date()
            startTicking()
        }
    }
} 

