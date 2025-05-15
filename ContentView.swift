import SwiftUI

struct ContentView: View {
    @EnvironmentObject var timerManager: TimerManager
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var showingTimerSettings = false
    @State private var showingVoiceSettings = false
    @State private var showingIntervalPicker = false
    @State private var showingEndTimePicker = false
    @State private var showingDurationPicker = false
    @State private var showingRepeatPicker = false
    @State private var showBreathingGuide = false
    @State private var isPressed = false
    @State private var animationScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // 主要计时器内容
            VStack(spacing: 0) {  // 设置为0，手动控制间距
                // 主标题
                Text("语音番茄时钟")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.top, 50)
                    .padding(.bottom, 40)
                
                // 顶部状态栏
                HStack {
                    Button(action: {
                        showingTimerSettings = true
                    }) {
                        Image(systemName: "timer")
                            .font(.system(size: 28))  // 调整到28号字体
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showingVoiceSettings = true
                    }) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 20))  // 保持右边的图标较小
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)  // 增加与计时器的间距
                
                Spacer()
                
                // 计时器圆圈和显示 - 作为独立板块
                ZStack {
                    // 背景板
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color(UIColor.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                        .frame(width: 360, height: 360)
                    
                    // 计时器内容
                    ZStack {
                        // 阴影层
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 320, height: 320)
                            .shadow(color: .black.opacity(isPressed ? 0.2 : 0.3), 
                                   radius: isPressed ? 5 : 15, 
                                   x: 0, 
                                   y: isPressed ? 2 : 8)
                            .scaleEffect(isPressed ? 0.8 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
                        
                        // 外圈进度 - 背景
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                            .frame(width: 320, height: 320)
                            .scaleEffect(isPressed ? 0.8 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
                        
                        // 外圈进度 - 前景
                        Circle()
                            .trim(from: 0, to: timerManager.progressPercentage)
                            .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round))
                            .foregroundColor(timerManager.isPaused ? Color.gray : Color.blue)
                            .frame(width: 320, height: 320)
                            .rotationEffect(.degrees(-90))
                            .scaleEffect(isPressed ? 0.8 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
                        
                        // 内圈底色
                        Circle()
                            .fill(Color(UIColor.systemBackground))
                            .frame(width: 280, height: 280)
                            .shadow(color: isPressed ? Color.black.opacity(0.3) : Color.clear, 
                                   radius: isPressed ? 10 : 0,
                                   x: 0, 
                                   y: isPressed ? 5 : 0)
                            .scaleEffect(isPressed ? 0.8 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
                        
                        // 内圈发光效果
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 280, height: 280)
                            .shadow(color: timerManager.isRunning ? Color.blue.opacity(0.5) : Color.clear, 
                                   radius: timerManager.isRunning ? 20 : 0)
                            .scaleEffect(isPressed ? 0.8 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
                        
                        // 时间显示
                        VStack {
                            Text(timerManager.timeString)
                                .font(.system(size: 64, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(timerManager.isPaused ? .gray : .primary)
                                .scaleEffect(isPressed ? 0.8 : 1.0)
                                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
                        }
                    }
                }
                .padding(.bottom, 40)  // 增加与底部按钮的间距
                
                Spacer()
                
                // 控制按钮
                HStack(spacing: 30) {  // 减小按钮间距
                    Button(action: {
                        if timerManager.isRunning {
                            timerManager.pauseTimer()
                        }
                    }) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 28))  // 稍微减小按钮大小
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)  // 减小按钮尺寸
                            .background(Color.blue)
                            .clipShape(Circle())
                            .opacity(timerManager.isRunning ? 1 : 0.5)
                    }
                    .disabled(!timerManager.isRunning)
                    
                    Button(action: {
                        timerManager.resetTimer()
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 28))  // 稍微减小按钮大小
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)  // 减小按钮尺寸
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 30)  // 减小底部间距
            }
            .blur(radius: timerManager.isBreathing ? 10 : 0)
            
            // 深呼吸引导视图
            if timerManager.isBreathing {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                
                VStack {
                    Text(languageManager.isEnglish ? "Deep Breathing" : "深呼吸")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 40)
                    
                    Spacer()
                    
                    BreathingGuideView(timerManager: timerManager)
                    
                    Spacer()
                    
                    Button(action: {
                        timerManager.completeBreathing()
                    }) {
                        Text(languageManager.isEnglish ? "Skip" : "跳过")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.gray.opacity(0.5))
                            .cornerRadius(10)
                    }
                    .padding(.bottom, 40)
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .onChange(of: timerManager.isBreathing) { newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                showBreathingGuide = newValue
            }
        }
        .sheet(isPresented: $showingTimerSettings) {
            TimerSettingsView()
        }
        .sheet(isPresented: $showingVoiceSettings) {
            VoiceSettingsView()
        }
    }
    
    // ... existing code ...
} 