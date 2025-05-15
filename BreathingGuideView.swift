import SwiftUI
import AVFoundation

struct BreathingGuideView: View {
    @ObservedObject var timerManager: TimerManager
    @ObservedObject private var languageManager = LanguageManager.shared
    
    private var phaseText: String {
        switch timerManager.breathingPhase {
        case .notStarted:
            return languageManager.isEnglish ? "Let's start deep breathing" : "让我们开始深呼吸"
        case .inhale:
            return languageManager.isEnglish ? "Inhale" : "吸气"
        case .holdInhale:
            return languageManager.isEnglish ? "Hold" : "屏住"
        case .exhale:
            return languageManager.isEnglish ? "Exhale" : "呼气"
        case .holdExhale:
            return languageManager.isEnglish ? "Hold" : "屏住"
        }
    }
    
    private var scale: CGFloat {
        switch timerManager.breathingPhase {
        case .notStarted:
            return 1.0
        case .inhale:
            return 1.5
        case .holdInhale:
            return 1.5
        case .exhale:
            return 1.0
        case .holdExhale:
            return 1.0
        }
    }
    
    var body: some View {
        VStack {
            Text(phaseText)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.white)
                .padding(.bottom, 20)
            
            Text("🫁")
                .font(.system(size: 120))
                .scaleEffect(scale)
                .animation(.easeInOut(duration: 3), value: scale)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                        .scaleEffect(scale)
                )
            
            if timerManager.breathingPhase != .notStarted {
                Text(languageManager.isEnglish ? 
                     "Round \(timerManager.breathingCount + 1)/5" :
                     "第 \(timerManager.breathingCount + 1)/5 次")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .padding(.top, 20)
            }
            
            Button(action: {
                timerManager.skipBreathing()
            }) {
                Text(languageManager.isEnglish ? "Skip" : "跳过")
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.5))
                    .cornerRadius(10)
            }
            .padding(.top, 40)
        }
        .frame(width: 300, height: 400)
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.5)
            .edgesIgnoringSafeArea(.all)
        
        BreathingGuideView(timerManager: TimerManager())
    }
} 