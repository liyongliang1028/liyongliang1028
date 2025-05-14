import SwiftUI
import AVFoundation
import Foundation // 确保可以访问DesignSystem

// 从ContentView导入DesignSystem
extension DesignSystem { }

struct VoiceSettingsView: View {
    @Binding var timerManager: TimerManager
    @ObservedObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        ZStack {
            Color(hex: "FCFBFA")
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Language Toggle
                HStack {
                    Spacer()
                    Button(action: {
                        languageManager.toggleLanguage()
                    }) {
                        Text(languageManager.isEnglish ? "中文" : "English")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(.systemGray6))
                            )
                    }
                    .padding()
                }
                
                // Title
                Text(languageManager.localized("voice_settings"))
                    .font(.system(size: 24, weight: .bold))
                    .padding(.top)
                
                // Reminder Type Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text(languageManager.localized("reminder_type"))
                        .font(.system(size: 16, weight: .medium))
                    
                    Picker("", selection: $timerManager.reminderType) {
                        ForEach(ReminderType.allCases, id: \.self) { type in
                            Text(type.localizedTitle)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                
                // Breathing Prompt Toggle
                VStack(alignment: .leading, spacing: 8) {
                    Text(languageManager.localized("breathing_prompts"))
                        .font(.system(size: 16, weight: .medium))
                    
                    Toggle(isOn: $timerManager.enableBreathingPrompt) {
                        Text(languageManager.localized("remind_breathing"))
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: DesignSystem.tomatoRed))
                }
                .padding(.horizontal)
                
                // Preview Section
                VStack(alignment: .leading, spacing: 8) {
                    Text(languageManager.localized("preview"))
                        .font(.system(size: 16, weight: .medium))
                    
                    Button(action: {
                        timerManager.announceTime(isStart: true)
                    }) {
                        Text(languageManager.localized("test_voice"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(DesignSystem.tomatoRed)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
    }
}

#Preview {
    VoiceSettingsView(timerManager: .constant(TimerManager()))
} 