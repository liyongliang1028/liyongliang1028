import SwiftUI

struct TimerSettingsView: View {
    @ObservedObject var timerManager: TimerManager
    @ObservedObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        ZStack {
            Color(hex: "FCFBFA")
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
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(.systemGray6))
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Title
                Text(languageManager.localized("timer_settings"))
                    .font(.system(size: 24, weight: .bold))
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
                                Picker("", selection: $timerManager.selectedInterval) {
                                    ForEach(timerManager.availableIntervals, id: \.self) { interval in
                                        Text("\(interval) \(languageManager.localized("minutes"))").tag(interval)
                                    }
                                }
                                .pickerStyle(.menu)
                                
                                Text(languageManager.localized("repeat_count"))
                                    .font(.system(size: 16, weight: .medium))
                                    .padding(.top, 8)
                                Picker("", selection: $timerManager.repeatCount) {
                                    ForEach(1...10, id: \.self) { count in
                                        Text("\(count) \(languageManager.localized("times"))").tag(count)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        case .endTime:
                            VStack(alignment: .leading, spacing: 12) {
                                Text(languageManager.localized("end_time"))
                                    .font(.system(size: 16, weight: .medium))
                                DatePicker("", selection: $timerManager.endTime, displayedComponents: [.hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                            }
                        case .totalDuration:
                            VStack(alignment: .leading, spacing: 12) {
                                Text(languageManager.localized("total_duration"))
                                    .font(.system(size: 16, weight: .medium))
                                Picker("", selection: $timerManager.totalDuration) {
                                    ForEach([15, 25, 30, 45, 60, 90, 120], id: \.self) { minutes in
                                        Text("\(minutes) \(languageManager.localized("minutes"))").tag(TimeInterval(minutes * 60))
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                Spacer()
            }
        }
    }
}

#Preview {
    TimerSettingsView(timerManager: TimerManager())
} 