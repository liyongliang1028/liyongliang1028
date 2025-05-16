import SwiftUI

// 设计系统 - 统一的UI样式
struct DesignSystem {
    static let cornerRadius: CGFloat = 12
    static let buttonCornerRadius: CGFloat = 20
    static let standardShadow = Shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    static let lightShadow = Shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    static let tomatoRed = Color(hex: "E93F33") // 番茄红色 🍅
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

extension View {
    func standardShadow() -> some View {
        self.shadow(
            color: DesignSystem.standardShadow.color,
            radius: DesignSystem.standardShadow.radius,
            x: DesignSystem.standardShadow.x,
            y: DesignSystem.standardShadow.y
        )
    }
    
    func lightShadow() -> some View {
        self.shadow(
            color: DesignSystem.lightShadow.color,
            radius: DesignSystem.lightShadow.radius,
            x: DesignSystem.lightShadow.x,
            y: DesignSystem.lightShadow.y
        )
    }
    
    func standardCornerRadius() -> some View {
        self.cornerRadius(DesignSystem.cornerRadius)
    }
    
    func buttonCornerRadius() -> some View {
        self.cornerRadius(DesignSystem.buttonCornerRadius)
    }
    
    func pressableButton() -> some View {
        self.buttonStyle(PressableButtonStyle())
    }
}

// 可按压按钮样式
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// 添加 ProgressBlocksView
struct ProgressBlocksView: View {
    let totalBlocks: Int
    let completedBlocks: Int
    let isDarkMode: Bool
    
    private let columns = [
        GridItem(.adaptive(minimum: 24, maximum: 32), spacing: 12)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<totalBlocks, id: \.self) { index in
                Rectangle()
                    .fill(index < completedBlocks ? 
                          (isDarkMode ? Color.white : Color.black) : 
                          Color.clear)
                    .frame(width: 24, height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(index < completedBlocks ? 
                                   (isDarkMode ? Color.white : Color.black) : 
                                   (isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.3)),
                                   lineWidth: 1.5)
                    )
                    .animation(.easeInOut(duration: 0.2), value: completedBlocks)
            }
        }
        .padding(.horizontal, 20)
    }
}

struct ContentView: View {
    @EnvironmentObject var timerManager: TimerManager
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var showingTimerSettings = false
    @State private var showingVoiceSettings = false
    @State private var showingIntervalPicker = false
    @State private var showingEndTimePicker = false
    @State private var showingDurationPicker = false
    @State private var showingRepeatPicker = false
    @State private var showMeditation = false
    
    // 预先格式化日期
    private var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timerManager.endTime)
    }
    
    // 语音提醒间隔视图 - 提取公共部分
    private func reminderIntervalView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(languageManager.isEnglish ? "Voice Reminder Interval (min)" : "语音提醒间隔 (分钟)")
                .font(.system(size: 17))
                .foregroundColor(.primary)
            
            Button(action: {
                showingIntervalPicker = true
            }) {
                HStack {
                    Text("\(timerManager.selectedInterval) \(languageManager.isEnglish ? "min" : "分钟")")
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .padding(.trailing, 16)
                }
                .background(Color(.systemBackground))
                .standardCornerRadius()
                .standardShadow()
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            .sheet(isPresented: $showingIntervalPicker) {
                VStack {
                    HStack {
                        Button("Cancel") {
                            showingIntervalPicker = false
                        }
                        .padding()
                        
                        Spacer()
                        
                        Text(languageManager.isEnglish ? "Voice Reminder Interval (min)" : "语音提醒间隔 (分钟)")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Done") {
                            showingIntervalPicker = false
                        }
                        .padding()
                        .foregroundColor(DesignSystem.tomatoRed)
                    }
                    
                    Picker("", selection: $timerManager.selectedInterval) {
                        ForEach(timerManager.availableIntervals, id: \.self) { interval in
                            Text("\(interval) \(languageManager.isEnglish ? "min" : "分钟")")
                                .tag(interval)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                .presentationDetents([.height(300)])
            }
        }
    }

    private func resetTimer() {
        timerManager.resetTimer()
    }

    var body: some View {
        ZStack {
            // 背景颜色 - 与图片匹配的浅灰色
            Color(hex: "F2F2F7")
                .ignoresSafeArea()
                .overlay(
                    Color.black.opacity(colorScheme == .dark ? 1 : 0)
                        .ignoresSafeArea()
                )
            
            ScrollView {
            VStack(spacing: 0) {
                    // 顶部区域: Logo 和语言切换
                HStack {
                        // App Logo
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 48)
                            .padding(.leading, 16)
                        
                    Spacer()
                        
                        // 语言切换控件 - 更贴近图片中的风格
                        HStack(spacing: 0) {
                            Button(action: {
                                if languageManager.isEnglish {
                                    languageManager.toggleLanguage()
                                }
                            }) {
                                Text("中文")
                                    .font(.system(size: 17))
                                    .foregroundColor(languageManager.isEnglish ? .primary : .white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(languageManager.isEnglish ? Color(.systemBackground) : Color.black)
                                    )
                            }
                            
                            Button(action: {
                                if !languageManager.isEnglish {
                                    languageManager.toggleLanguage()
                                }
                            }) {
                                Text("English")
                                    .font(.system(size: 17))
                                    .foregroundColor(languageManager.isEnglish ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                            .fill(languageManager.isEnglish ? Color.black : Color(.systemBackground))
                                    )
                            }
                        }
                        .background(Color(.systemGray5))
                        .buttonCornerRadius()
                        .lightShadow()
                        .padding(.trailing, 16)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                    
                    // 标题区域 - 不改变
                VStack(spacing: 8) {
                        Text(languageManager.isEnglish ? "VoicePomodoro" : "语音番茄时钟")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        
                        Text(languageManager.isEnglish ? "Audio Focus Timer for ADHD" : "为ADHD设计的语音专注计时器")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(DesignSystem.tomatoRed)
                }
                    .padding(.bottom, 32)
                    
                    // 大型倒计时显示
                    ZStack {
                        // 进度环背景
                        Circle()
                            .stroke(lineWidth: 15)
                            .opacity(0.2)
                            .foregroundColor(colorScheme == .dark ? Color.white : Color.gray)
                            .frame(width: 320, height: 320)
                            .standardShadow()
                        
                        // 实际进度
                        Circle()
                            .trim(from: 0.0, to: timerManager.progressPercentage)
                            .stroke(style: StrokeStyle(
                                lineWidth: 15,
                                lineCap: .round,
                                lineJoin: .round
                            ))
                            .foregroundColor(timerManager.isPaused ? DesignSystem.tomatoRed : DesignSystem.tomatoRed)
                            .rotationEffect(Angle(degrees: 270.0))
                            .frame(width: 320, height: 320)
                            .animation(.linear(duration: 0.2), value: timerManager.progressPercentage)
                            .shadow(color: DesignSystem.tomatoRed.opacity(0.5), radius: 5, x: 0, y: 0)
                            .opacity(timerManager.isPaused ? 0.7 : 1.0)
                        
                        // 内部圆形
                        Circle()
                            .fill(colorScheme == .dark ? Color.black.opacity(0.8) : Color.white.opacity(0.8))
                            .frame(width: 280, height: 280)
                            .standardShadow()
                        
                        // 冥想动画或倒计时数字
                        if timerManager.isBreathing {
                            VStack(spacing: 16) {
                                Image("BreathingImage")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 180, height: 180)
                                    .scaleEffect(showMeditation ? 1.1 : 0.9)
                                    .animation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: showMeditation)
                                Text(languageManager.isEnglish ? "Deep Breathing..." : "深呼吸中...")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(DesignSystem.tomatoRed)
                            }
                            .onAppear {
                                showMeditation = true
                            }
                            .onDisappear {
                                showMeditation = false
                            }
                            .allowsHitTesting(false)
                        } else {
                            VStack(spacing: 5) {
                                Text(timerManager.timeString)
                                    .font(.system(size: 80, weight: .regular, design: .monospaced))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                    .opacity(timerManager.isPaused ? 0.7 : 1.0)
                                
                                if timerManager.isPaused {
                                    Text(languageManager.isEnglish ? "Paused" : "已暂停")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(DesignSystem.tomatoRed)
                                } else if timerManager.isRunning {
                                    Text(languageManager.isEnglish ? "Focus Time" : "专注时间")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(DesignSystem.tomatoRed)
                                        .opacity(0.8)
                                }
                            }
                        }
                    }
                    .scaleEffect(timerManager.isRunning ? 1.0 : (timerManager.isPaused ? 0.98 : 0.95))
                    .animation(.spring(), value: timerManager.isRunning)
                    .animation(.spring(), value: timerManager.isPaused)
                    .onTapGesture {
                        if timerManager.isRunning {
                            timerManager.pauseTimer()
                        } else if timerManager.isPaused {
                            timerManager.startTimer()
                        } else {
                            timerManager.startTimer()
                        }
                    }
                    .padding(.bottom, 20)
                    
                    // 添加进度方块视图
                    ProgressBlocksView(
                        totalBlocks: timerManager.totalBlocks,
                        completedBlocks: timerManager.completedBlocks,
                        isDarkMode: colorScheme == .dark
                    )
                    .padding(.bottom, 20)
                    
                    // 分段控制器 - 使用iOS风格更新
                    SegmentedControlView(
                        selection: $timerManager.selectedMode,
                        options: TimerMode.allCases,
                        isDarkMode: colorScheme == .dark
                    )
                    .standardShadow()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    
                    // 设置项 - 根据模式显示不同选项
                    VStack(spacing: 20) {
                        switch timerManager.selectedMode {
                        case .repeatCount:
                            // 语音提醒间隔
                            reminderIntervalView()
                            
                            // 重复次数
                            VStack(alignment: .leading, spacing: 8) {
                                Text(languageManager.isEnglish ? "Repeat Count" : "重复次数")
                                    .font(.system(size: 17))
                                    .foregroundColor(.primary)
                                
                                Button(action: {
                                    showingRepeatPicker = true
                                }) {
                                    HStack {
                                        Text("\(timerManager.repeatCount)")
                                            .font(.system(size: 17))
                                            .foregroundColor(.primary)
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 16)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                            .padding(.trailing, 16)
                                    }
                                    .background(Color(.systemBackground))
                                    .standardCornerRadius()
                                    .standardShadow()
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .sheet(isPresented: $showingRepeatPicker) {
                                    VStack {
                                        HStack {
                                            Button("Cancel") {
                                                showingRepeatPicker = false
                                            }
                                            .padding()
                                            
                                            Spacer()
                                            
                                            Text(languageManager.isEnglish ? "Repeat Count" : "重复次数")
                                                .font(.headline)
                                            
                                            Spacer()
                                            
                                            Button("Done") {
                                                showingRepeatPicker = false
                                            }
                                            .padding()
                                            .foregroundColor(DesignSystem.tomatoRed)
                                        }
                                        
                                        Picker("", selection: $timerManager.repeatCount) {
                                            ForEach(1...10, id: \.self) { count in
                                                Text("\(count)")
                                                    .tag(count)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                    }
                                    .presentationDetents([.height(300)])
                                }
                            }
                            
                        case .endTime:
                            // 语音提醒间隔 - 复用同样的视图
                            reminderIntervalView()
                            
                            // 结束时间
                            VStack(alignment: .leading, spacing: 8) {
                                Text(languageManager.isEnglish ? "End Time" : "结束时间")
                                    .font(.system(size: 17))
                                    .foregroundColor(.primary)
                                
                                Button(action: {
                                    showingEndTimePicker = true
                                }) {
                                    HStack {
                                        Text(formattedEndTime)
                                            .font(.system(size: 17))
                                            .foregroundColor(.primary)
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 16)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                            .padding(.trailing, 16)
                                    }
                                    .background(Color(.systemBackground))
                                    .standardCornerRadius()
                                    .standardShadow()
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .sheet(isPresented: $showingEndTimePicker) {
                                    VStack {
                                        HStack {
                                            Button("Cancel") {
                                                showingEndTimePicker = false
                                            }
                                            .padding()
                                            
                                            Spacer()
                                            
                                            Text(languageManager.isEnglish ? "End Time" : "结束时间")
                                                .font(.headline)
                                            
                                            Spacer()
                                            
                                            Button("Done") {
                                                showingEndTimePicker = false
                                            }
                                            .padding()
                                            .foregroundColor(DesignSystem.tomatoRed)
                                        }
                                        
                                        DatePicker("", selection: $timerManager.endTime, displayedComponents: [.hourAndMinute])
                                            .datePickerStyle(.wheel)
                                            .labelsHidden()
                                    }
                                    .presentationDetents([.height(300)])
                                }
                            }
                            
                        case .totalDuration:
                            // 语音提醒间隔 - 复用同样的视图
                            reminderIntervalView()
                            
                            // 专注时长
                            VStack(alignment: .leading, spacing: 8) {
                                Text(languageManager.isEnglish ? "Focus Duration (hours)" : "专注时长 (小时)")
                                    .font(.system(size: 17))
                                    .foregroundColor(.primary)
                                
                                Button(action: {
                                    showingDurationPicker = true
                                }) {
                                    HStack {
                                        Text("\(Int(timerManager.totalDuration/3600)) \(languageManager.isEnglish ? "hours" : "小时")")
                                            .font(.system(size: 17))
                                            .foregroundColor(.primary)
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 16)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                            .padding(.trailing, 16)
                                    }
                                    .background(Color(.systemBackground))
                                    .standardCornerRadius()
                                    .standardShadow()
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .sheet(isPresented: $showingDurationPicker) {
                                    VStack {
                                        HStack {
                                            Button("Cancel") {
                                                showingDurationPicker = false
                                            }
                                            .padding()
                                            
                                            Spacer()
                                            
                                            Text(languageManager.isEnglish ? "Focus Duration (hours)" : "专注时长 (小时)")
                                                .font(.headline)
                                            
                                            Spacer()
                                            
                                            Button("Done") {
                                                showingDurationPicker = false
                                            }
                                            .padding()
                                            .foregroundColor(DesignSystem.tomatoRed)
                                        }
                                        
                                        Picker("", selection: $timerManager.totalDuration) {
                                            ForEach([1, 2, 3, 4, 5, 6, 7, 8], id: \.self) { hours in
                                                Text("\(hours) \(languageManager.isEnglish ? "hours" : "小时")")
                                                    .tag(TimeInterval(hours * 3600))
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                    }
                                    .presentationDetents([.height(300)])
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    
                    Divider()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    
                    // 语音提醒方式 - 使用音频图标
                    HStack {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 17))
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        
                        Text(languageManager.isEnglish ? "Voice Reminder Mode" : "语音提醒方式")
                            .font(.system(size: 17))
                        
                        Spacer()
                        
                        Text(timerManager.reminderType.localizedTitle)
                            .font(.system(size: 15))
                            .foregroundColor(DesignSystem.tomatoRed)
                        
                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundColor(DesignSystem.tomatoRed)
                            .font(.system(size: 17))
                            .padding(.leading, 4)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(Color(.systemBackground).opacity(0.5))
                    .standardCornerRadius()
                    .standardShadow()
                    .padding(.horizontal, 20)
                    .onTapGesture {
                        // 切换提醒方式
                        timerManager.reminderType = timerManager.reminderType == .countdown ? .bothTimeAndCountdown : .countdown
                    }
                    .padding(.bottom, 16)
                    
                    // 呼吸提示开关
                    HStack {
                        // 用户图标
                        Image(systemName: "figure.mind.and.body")
                            .font(.system(size: 17))
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        
                        Text(languageManager.isEnglish ? "Remind deep breathing 5x each interval" : "每次间隔 提醒深呼吸5次")
                            .font(.system(size: 17))
                        
                        Spacer()
                        
                        Toggle("", isOn: $timerManager.enableBreathingPrompt)
                            .toggleStyle(SwitchToggleStyle(tint: DesignSystem.tomatoRed))
                            .labelsHidden()
                            .scaleEffect(0.85)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(Color(.systemBackground).opacity(0.5))
                    .standardCornerRadius()
                    .standardShadow()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                    
                    Spacer(minLength: 20)
                    
                    // 底部按钮区域
                    HStack(spacing: 16) {
                        // 开始/暂停按钮
                        Button(action: {
                            if timerManager.isRunning {
                                timerManager.pauseTimer()
                            } else {
                                timerManager.startTimer()
                            }
                        }) {
                            Text(timerManager.isRunning 
                                ? languageManager.localized("stop") 
                                : (timerManager.isPaused ? languageManager.localized("resume") : languageManager.localized("start")))
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(
                                    Capsule()
                                        .fill(timerManager.isPaused ? DesignSystem.tomatoRed : Color.black)
                                )
                                .standardShadow()
                        }
                        .pressableButton()
                        
                        // 重置按钮
                        Button(action: {
                            resetTimer()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                                .frame(width: 56, height: 56)
                                .background(
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        .background(Circle().fill(Color(.systemBackground)))
                                )
                                .standardShadow()
                        }
                        .pressableButton()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .padding(.bottom, 16)
            }
            .sheet(isPresented: $showingTimerSettings) {
                TimerSettingsView(timerManager: timerManager)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
    }
    
    @Environment(\.colorScheme) var colorScheme
}

// 分段控制器 - 更像iOS原生风格
struct SegmentedControlView: View {
    @Binding var selection: TimerMode
    let options: [TimerMode]
    let isDarkMode: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button(action: {
                    withAnimation {
                        self.selection = option
                    }
                }) {
                    Text(option.localizedTitle)
                        .font(.system(size: 17))
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(selection == option ? 
                                        (isDarkMode ? .black : .white) : 
                                        (isDarkMode ? .white : .black))
                        .background(
                            selection == option ?
                                (isDarkMode ? Color.white : Color.black) :
                                (isDarkMode ? Color.clear : Color.clear)
                        )
                }
                .background(isDarkMode ? Color.black.opacity(0.1) : Color(.systemGray5))
                .cornerRadius(selection == option ? DesignSystem.cornerRadius : 0)
            }
        }
        .background(isDarkMode ? Color.black.opacity(0.1) : Color(.systemGray5))
        .cornerRadius(DesignSystem.cornerRadius)
    }
}

// Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView().environmentObject(TimerManager())
}
