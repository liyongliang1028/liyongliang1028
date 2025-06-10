import SwiftUI

struct TimerSettingsView: View {
    @ObservedObject var timerManager: TimerManager
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // 使用主题背景色
            ThemeManager.shared.currentTheme(for: colorScheme).background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
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
                Text(languageManager.localized("timer_settings"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ThemeManager.shared.currentTheme(for: colorScheme).text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                
                // Settings Groups
                VStack(spacing: 32) {
                    // Timer Mode Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text(languageManager.localized("timer_mode"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ThemeManager.shared.currentTheme(for: colorScheme).text)
                        
                        Picker("", selection: $timerManager.selectedMode) {
                            ForEach(TimerMode.allCases, id: \.self) { mode in
                                Text(mode.localizedTitle)
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Mode-specific Settings
                    Group {
                        switch timerManager.selectedMode {
                        case .repeatCount:
                            VStack(alignment: .leading, spacing: 12) {
                                Text(languageManager.localized("interval_duration"))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(ThemeManager.shared.currentTheme(for: colorScheme).text)
                                
                                Picker("", selection: $timerManager.selectedInterval) {
                                    ForEach(timerManager.availableIntervals, id: \.self) { interval in
                                        Text("\(interval) \(languageManager.localized("minutes"))").tag(interval)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accentColor(ThemeManager.shared.currentTheme(for: colorScheme).primary)
                                
                                Text(languageManager.localized("repeat_count"))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(ThemeManager.shared.currentTheme(for: colorScheme).text)
                                    .padding(.top, 8)
                                
                                Picker("", selection: $timerManager.repeatCount) {
                                    ForEach(1...10, id: \.self) { count in
                                        Text("\(count) \(languageManager.localized("times"))").tag(count)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accentColor(ThemeManager.shared.currentTheme(for: colorScheme).primary)
                            }
                        case .endTime:
                            VStack(alignment: .leading, spacing: 12) {
                                Text(languageManager.localized("end_time"))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(ThemeManager.shared.currentTheme(for: colorScheme).text)
                                
                                DatePicker("", selection: $timerManager.endTime, displayedComponents: [.hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .accentColor(ThemeManager.shared.currentTheme(for: colorScheme).primary)
                            }
                        case .totalDuration:
                            VStack(alignment: .leading, spacing: 12) {
                                Text(languageManager.localized("total_duration"))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(ThemeManager.shared.currentTheme(for: colorScheme).text)
                                
                                Picker("", selection: $timerManager.totalDuration) {
                                    ForEach([15, 25, 30, 45, 60, 90, 120], id: \.self) { minutes in
                                        Text("\(minutes) \(languageManager.localized("minutes"))").tag(TimeInterval(minutes * 60))
                                    }
                                }
                                .pickerStyle(.menu)
                                .accentColor(ThemeManager.shared.currentTheme(for: colorScheme).primary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                Spacer()
                
                // 添加主题模式切换
                VStack(alignment: .leading, spacing: 12) {
                    Text(languageManager.isEnglish ? "Theme" : "主题")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ThemeManager.shared.currentTheme(for: colorScheme).text)
                    
                    HStack {
                        Image(systemName: colorScheme == .dark ? "moon.fill" : "sun.max.fill")
                            .foregroundColor(ThemeManager.shared.currentTheme(for: colorScheme).primary)
                        
                        Text(colorScheme.localizedName)
                            .foregroundColor(ThemeManager.shared.currentTheme(for: colorScheme).text)
                        
                        Spacer()
                        
                        Text(languageManager.isEnglish ? "(System Default)" : "(系统默认)")
                            .font(.system(size: 14))
                            .foregroundColor(ThemeManager.shared.currentTheme(for: colorScheme).secondaryText)
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
    TimerSettingsView(timerManager: TimerManager())
} 