import SwiftUI
import AVFoundation
import Foundation // 确保可以访问DesignSystem

// 从ContentView导入DesignSystem
extension DesignSystem { }

struct VoiceSettingsView: View {
    @Binding var timerManager: TimerManager
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // 使用主题背景色
            ThemeManager.shared.currentTheme(for: colorScheme).background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {  // 设置为0，手动控制间距
                // Language Toggle
                HStack {
                    Spacer()
                    Button(action: {
                        languageManager.toggleLanguage()
                    }) {
                        Text(languageManager.isEnglish ? "中文" : "English")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ThemeManager.shared.currentTheme(for: colorScheme).secondaryText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(ThemeManager.shared.currentTheme(for: colorScheme).secondaryBackground)
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Title
                Text(languageManager.localized("voice_settings"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ThemeManager.shared.currentTheme(for: colorScheme).text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                
                // Settings Groups
                VStack(spacing: 32) {  // 设置组之间的间距
                    // Reminder Type Selection
                    VStack(alignment: .leading, spacing: 12) {  // 组内元素间距
                        Text(languageManager.localized("reminder_type"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ThemeManager.shared.currentTheme(for: colorScheme).text)
                        
                        Picker("", selection: $timerManager.reminderType) {
                            ForEach(ReminderType.allCases, id: \.self) { type in
                                Text(type.localizedTitle)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accentColor(ThemeManager.shared.currentTheme(for: colorScheme).primary)
                    }
                    
                    // Breathing Prompt Toggle
                    VStack(alignment: .leading, spacing: 12) {
                        Text(languageManager.localized("breathing_prompts"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ThemeManager.shared.currentTheme(for: colorScheme).text)
                        
                        Toggle(isOn: $timerManager.enableBreathingPrompt) {
                            Text(languageManager.localized("remind_breathing"))
                                .font(.system(size: 14))
                                .foregroundColor(ThemeManager.shared.currentTheme(for: colorScheme).secondaryText)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: ThemeManager.shared.currentTheme(for: colorScheme).primary))
                    }
                    
                    // Preview Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text(languageManager.localized("preview"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ThemeManager.shared.currentTheme(for: colorScheme).text)
                        
                        Button(action: {
                            timerManager.announceTime(isStart: true)
                        }) {
                            Text(languageManager.localized("test_voice"))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(ThemeManager.shared.currentTheme(for: colorScheme).primary)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                Spacer()
                
                // 添加主题说明
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: colorScheme == .dark ? "moon.fill" : "sun.max.fill")
                            .foregroundColor(ThemeManager.shared.currentTheme(for: colorScheme).primary)
                        
                        Text(languageManager.isEnglish ? "App is using system theme" : "应用使用系统主题")
                            .font(.system(size: 14))
                            .foregroundColor(ThemeManager.shared.currentTheme(for: colorScheme).secondaryText)
                        
                        Spacer()
                        
                        Text(colorScheme.localizedName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ThemeManager.shared.currentTheme(for: colorScheme).primary)
                    }
                    .padding()
                    .background(ThemeManager.shared.currentTheme(for: colorScheme).secondaryBackground)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }
}

#Preview {
    VoiceSettingsView(timerManager: .constant(TimerManager()))
} 