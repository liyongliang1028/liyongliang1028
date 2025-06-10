//
//  VoicePomodoroApp.swift
//  VoicePomodoro
//
//  Created by Elva Li on 2025/5/14.
//

import SwiftUI
import BackgroundTasks
import UserNotifications

@main
struct VoicePomodoroApp: App {
    @StateObject private var timerManager = TimerManager()
    
    init() {
        // 注册后台任务
        registerBackgroundTasks()
        // 请求通知权限
        requestNotificationPermission()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timerManager)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // 应用进入后台时处理
                    scheduleBackgroundTasks()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // 应用返回前台时处理
                    cancelBackgroundTasks()
                    // 更新UI
                    timerManager.updateTimerOnForeground()
                }
        }
    }
    
    // 注册后台任务
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.elvali.VoicePomodoro.refresh", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    // 处理应用刷新任务
    private func handleAppRefresh(task: BGAppRefreshTask) {
        // 创建任务取消时的处理
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // 执行后台任务
        timerManager.performBackgroundUpdate()
        
        // 完成任务
        task.setTaskCompleted(success: true)
        
        // 重新安排下一次后台任务
        scheduleBackgroundTasks()
    }
    
    // 安排后台任务
    private func scheduleBackgroundTasks() {
        // 仅在计时器运行时才安排后台任务
        guard timerManager.isRunning && !timerManager.isPaused else { return }
        
        let request = BGAppRefreshTaskRequest(identifier: "com.elvali.VoicePomodoro.refresh")
        // 安排15分钟后执行
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("🔄 后台任务已安排")
        } catch {
            print("❌ 无法安排后台任务: \(error.localizedDescription)")
        }
    }
    
    // 取消后台任务
    private func cancelBackgroundTasks() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.elvali.VoicePomodoro.refresh")
    }
    
    // 请求通知权限
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ 通知权限已获取")
            } else if let error = error {
                print("❌ 通知权限请求失败: \(error.localizedDescription)")
            }
        }
    }
}
