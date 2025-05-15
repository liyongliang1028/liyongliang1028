import AVFoundation
import SwiftUI

class TimerManager: ObservableObject {
    // Timer properties
    @Published var remainingTime: TimeInterval = 25 * 60
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var selectedInterval: Int = 25
    @Published var selectedMode: TimerMode = .repeatCount
    @Published var repeatCount: Int = 4
    @Published var currentRepeatCount: Int = 0
    @Published var endTime: Date = Date().addingTimeInterval(25 * 60)
    @Published var totalDuration: TimeInterval = 3600
    
    // Breathing properties
    @Published var isBreathing = false
    @Published var enableBreathingPrompt = true  // 深呼吸开关
    @Published var breathingPhase: BreathingPhase = .notStarted
    private var breathingCount = 0
    private let totalBreathingCount = 5
    
    // Progress properties
    @Published var totalBlocks: Int = 4
    @Published var completedBlocks: Int = 0
    @Published var currentCycle: Int = 1
    @Published var totalCycles: Int = 4
    
    private var timer: DispatchSourceTimer?
    private let synthesizer = AVSpeechSynthesizer()
    private var lastTickDate: Date?
    
    enum BreathingPhase {
        case notStarted
        case inhale
        case holdInhale
        case exhale
        case holdExhale
    }
    
    // 计时器相关方法
    func startTimer() {
        if !isRunning {
            isRunning = true
            isPaused = false
            startTicking()
        }
    }
    
    func pauseTimer() {
        isRunning = false
        isPaused = true
        timer?.cancel()
        timer = nil
    }
    
    func resetTimer() {
        timer?.cancel()
        timer = nil
        isRunning = false
        isPaused = false
        setupInitialTime()
    }
    
    private func setupInitialTime() {
        remainingTime = TimeInterval(selectedInterval * 60)
    }
    
    private func startTicking() {
        timer?.cancel()
        timer = DispatchSource.makeTimerSource(queue: .main)
        timer?.schedule(deadline: .now(), repeating: .seconds(1))
        
        timer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            if self.remainingTime > 0 {
                self.remainingTime -= 1
            } else {
                self.handleIntervalCompleted()
            }
        }
        
        timer?.resume()
    }
    
    private func handleIntervalCompleted() {
        timer?.cancel()
        timer = nil
        isRunning = false
        isPaused = true  // 确保计时器暂停
        
        // 先播放本轮结束提示
        speakCycleEndPrompt()
        
        // 检查是否是最后一轮
        if isLastCycle() {
            completedBlocks = totalBlocks
            speakEndTime()
            stopTimer()
            return
        }
        
        // 如果启用了深呼吸提醒，延迟2秒后开始深呼吸
        if enableBreathingPrompt {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.startBreathing()
            }
        } else {
            handleNextCycle()
        }
    }
    
    private func isLastCycle() -> Bool {
        switch selectedMode {
        case .repeatCount:
            return currentRepeatCount >= repeatCount - 1
        case .endTime:
            return Date() >= endTime
        case .totalDuration:
            let completedTime = TimeInterval(currentCycle * selectedInterval * 60)
            return completedTime >= totalDuration
        }
    }
    
    private func speakCycleEndPrompt() {
        let lang = LanguageManager.shared.isEnglish
        let interval = selectedInterval
        let message = lang ? 
            "\(interval) minutes completed. Take a break." :
            "\(interval)分钟完成了，休息一下。"
        
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: lang ? "en-US" : "zh-CN")
        utterance.rate = 0.5
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }
    
    private func handleNextCycle() {
        currentCycle += 1
        currentRepeatCount += 1
        updateCompletedBlocks()
        setupCurrentCycleTime()
        
        // 播放新周期开始提示
        let lang = LanguageManager.shared.isEnglish
        let startMessage = lang ?
            "Starting next \(selectedInterval) minutes focus time" :
            "开始下一个\(selectedInterval)分钟专注时间"
        
        speakMessage(startMessage)
        
        // 延迟2秒后开始计时，给用户准备时间
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            self.isRunning = true
            self.isPaused = false  // 确保计时器未暂停
            self.startTicking()
        }
    }
    
    private func startBreathing() {
        isBreathing = true
        breathingCount = 0
        breathingPhase = .notStarted
        objectWillChange.send()
        
        // 播放开始深呼吸提示
        let lang = LanguageManager.shared.isEnglish
        let breathingStartPrompt = lang ? "Let's start deep breathing" : "让我们开始深呼吸"
        let breathingStartUtterance = AVSpeechUtterance(string: breathingStartPrompt)
        breathingStartUtterance.voice = AVSpeechSynthesisVoice(language: lang ? "en-US" : "zh-CN")
        breathingStartUtterance.volume = 1.0
        synthesizer.speak(breathingStartUtterance)
        
        // 2秒后开始第一次呼吸
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.startBreathingCycle()
        }
    }
    
    private func startBreathingCycle() {
        guard breathingCount < totalBreathingCount else {
            completeBreathing()
            return
        }
        
        // 开始吸气
        breathingPhase = .inhale
        objectWillChange.send()
        
        let lang = LanguageManager.shared.isEnglish
        let breathInPrompt = lang ? "Breathe in" : "吸气"
        let breathInUtterance = AVSpeechUtterance(string: breathInPrompt)
        breathInUtterance.voice = AVSpeechSynthesisVoice(language: lang ? "en-US" : "zh-CN")
        breathInUtterance.volume = 1.0
        synthesizer.speak(breathInUtterance)
        
        // 4秒后开始屏气
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self = self else { return }
            self.breathingPhase = .holdInhale
            self.objectWillChange.send()
            
            // 4秒后开始呼气
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                guard let self = self else { return }
                self.breathingPhase = .exhale
                self.objectWillChange.send()
                
                let breathOutPrompt = lang ? "Breathe out" : "呼气"
                let breathOutUtterance = AVSpeechUtterance(string: breathOutPrompt)
                breathOutUtterance.voice = AVSpeechSynthesisVoice(language: lang ? "en-US" : "zh-CN")
                breathOutUtterance.volume = 1.0
                self.synthesizer.speak(breathOutUtterance)
                
                // 6秒后开始屏气
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                    guard let self = self else { return }
                    self.breathingPhase = .holdExhale
                    self.objectWillChange.send()
                    
                    // 2秒后开始下一轮
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        guard let self = self else { return }
                        self.breathingCount += 1
                        self.startBreathingCycle()
                    }
                }
            }
        }
    }
    
    func completeBreathing() {
        isBreathing = false
        breathingPhase = .notStarted
        breathingCount = 0
        objectWillChange.send()
        
        // 播放完成提示
        let lang = LanguageManager.shared.isEnglish
        let completionMessage = lang ?
            "Deep breathing completed. Let's continue focusing." :
            "深呼吸完成了，让我们继续专注。"
        speakMessage(completionMessage)
        
        // 2秒后开始下一个周期
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            self.handleNextCycle()
        }
    }
    
    private func setupCurrentCycleTime() {
        remainingTime = TimeInterval(selectedInterval * 60)
    }
    
    private func updateCompletedBlocks() {
        let progress = Float(currentCycle) / Float(totalCycles)
        completedBlocks = Int(progress * Float(totalBlocks))
    }
    
    private func stopTimer() {
        timer?.cancel()
        timer = nil
        isRunning = false
        isPaused = false
    }
    
    private func speakEndTime() {
        let lang = LanguageManager.shared.isEnglish
        let message = lang ? 
            "All cycles completed. Great work!" :
            "所有周期已完成，干得好！"
        speakMessage(message)
    }
    
    private func speakMessage(_ message: String) {
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: LanguageManager.shared.isEnglish ? "en-US" : "zh-CN")
        utterance.rate = 0.5
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }
    
    func skipBreathing() {
        let lang = LanguageManager.shared.isEnglish
        let skipMessage = lang ? "Skipping breathing exercise" : "跳过深呼吸练习"
        speakMessage(skipMessage)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            self.isBreathing = false
            self.breathingPhase = .notStarted
            self.breathingCount = 0
            self.objectWillChange.send()
            self.handleNextCycle()
        }
    }
} 