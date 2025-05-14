//
//  VoicePomodoroApp.swift
//  VoicePomodoro
//
//  Created by Elva Li on 2025/5/14.
//

import SwiftUI

@main
struct VoicePomodoroApp: App {
    @StateObject private var timerManager = TimerManager()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timerManager)
        }
    }
}
