import SwiftUI
import AVFoundation
import Foundation // 确保可以访问DesignSystem

// 从ContentView导入DesignSystem
extension DesignSystem { }

struct PostTimerBreakView: View {
    @Binding var timerManager: TimerManager
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var breathingCount = 0
    @State private var isBreathing = false
    @State private var showConfetti = false
    @State private var breathingPhase: BreathingPhase = .rest
    private let synthesizer = AVSpeechSynthesizer()
    
    enum BreathingPhase {
        case inhale, hold, exhale, rest
        
        var duration: TimeInterval {
            switch self {
            case .inhale: return 4
            case .hold: return 4
            case .exhale: return 6
            case .rest: return 2
            }
        }
        
        var color: Color {
            switch self {
            case .inhale: return DesignSystem.tomatoRed
            case .hold: return .purple
            case .exhale: return .green
            case .rest: return .gray
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "FCFBFA")
                .ignoresSafeArea()
            
            // Main Content
            VStack(spacing: 40) {
                // Header
                VStack(spacing: 20) {
                    Text(languageManager.localized("great_job"))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(DesignSystem.tomatoRed)
                    
                    Text(languageManager.localized("mindful_break"))
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("🧘‍♀️")
                        .font(.system(size: 80))
                        .padding(.top, 10)
                }
                .padding(.top, 40)
                
                // Breathing Circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                        .frame(width: 200, height: 200)
                    
                    Circle()
                        .trim(from: 0, to: breathingProgress)
                        .stroke(breathingPhase.color, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: breathingPhase.duration), value: breathingPhase)
                    
                    VStack(spacing: 8) {
                        if isBreathing {
                            Text("\(breathingCount)/5")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(breathingPhase.color)
                            
                            Text(phaseText)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.vertical, 20)
                
                // Action Button
                Button(action: {
                    if isBreathing {
                        stopBreathingExercise()
                    } else {
                        startBreathingExercise()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: isBreathing ? "stop.fill" : "play.fill")
                            .font(.system(size: 20, weight: .semibold))
                        
                        Text(isBreathing ? 
                            languageManager.localized("stop") :
                            languageManager.localized("start_breathing"))
                            .font(.system(size: 20, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 240, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(isBreathing ? Color.red : DesignSystem.tomatoRed)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
                
                // Tips
                if !isBreathing {
                    Text(languageManager.localized("relax_tip"))
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    private var breathingProgress: CGFloat {
        switch breathingPhase {
        case .inhale: return 0.25
        case .hold: return 0.5
        case .exhale: return 0.75
        case .rest: return 1.0
        }
    }
    
    private var phaseText: String {
        switch breathingPhase {
        case .inhale:
            return languageManager.localized("breathe_in")
        case .hold:
            return languageManager.localized("hold")
        case .exhale:
            return languageManager.localized("breathe_out")
        case .rest:
            return languageManager.localized("rest")
        }
    }
    
    private func startBreathingExercise() {
        isBreathing = true
        breathingCount = 0
        breathingPhase = .rest
        guideBreathing()
    }
    
    private func stopBreathingExercise() {
        isBreathing = false
        breathingCount = 0
        breathingPhase = .rest
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    private func guideBreathing() {
        let breathingInstructions = [
            languageManager.localized("breathe_in_instruction"),
            languageManager.localized("hold_instruction"),
            languageManager.localized("breathe_out_instruction"),
            languageManager.localized("rest_instruction")
        ]
        
        var currentInstruction = 0
        var currentBreath = 0
        
        func speakNextInstruction() {
            guard isBreathing, currentBreath < 5 else {
                isBreathing = false
                return
            }
            
            let utterance = AVSpeechUtterance(string: breathingInstructions[currentInstruction])
            utterance.voice = AVSpeechSynthesisVoice(language: languageManager.isEnglish ? "en-US" : "zh-CN")
            utterance.rate = 0.4
            utterance.pitchMultiplier = 1.0
            utterance.volume = 0.8
            
            synthesizer.speak(utterance)
            
            // Update breathing phase
            withAnimation {
                switch currentInstruction {
                case 0: breathingPhase = .inhale
                case 1: breathingPhase = .hold
                case 2: breathingPhase = .exhale
                case 3: breathingPhase = .rest
                default: break
                }
            }
            
            // Schedule next instruction
            DispatchQueue.main.asyncAfter(deadline: .now() + breathingPhase.duration) {
                currentInstruction = (currentInstruction + 1) % 4
                if currentInstruction == 0 {
                    currentBreath += 1
                    breathingCount = currentBreath
                }
                speakNextInstruction()
            }
        }
        
        speakNextInstruction()
    }
}

#Preview {
    PostTimerBreakView(timerManager: .constant(TimerManager()))
} 