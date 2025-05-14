import Foundation

class LocalizedStrings {
    static let shared = LocalizedStrings()
    
    private let strings: [String: [String: String]] = [
        // Timer View
        "title": [
            "en": "Focus",
            "zh": "专注"
        ],
        "subtitle": [
            "en": "Voice Timer",
            "zh": "语音计时器"
        ],
        "start": [
            "en": "Start",
            "zh": "开始"
        ],
        "stop": [
            "en": "Stop",
            "zh": "停止"
        ],
        "resume": [
            "en": "Resume",
            "zh": "继续"
        ],
        
        // Timer Mode类型
        "repeat_count": [
            "en": "Repeat Count",
            "zh": "重复次数"
        ],
        "end_time": [
            "en": "End Time",
            "zh": "结束时间"
        ],
        "total_duration": [
            "en": "Total Duration",
            "zh": "总时长"
        ],
        
        // Settings View
        "settings_title": [
            "en": "Timer Settings",
            "zh": "计时器设置"
        ],
        "interval_duration": [
            "en": "Interval Duration",
            "zh": "间隔时长"
        ],
        "minutes": [
            "en": "min",
            "zh": "分钟"
        ],
        "timer_mode": [
            "en": "Timer Mode",
            "zh": "计时模式"
        ],
        "times": [
            "en": "times",
            "zh": "次"
        ],
        
        // Voice Settings
        "voice_settings": [
            "en": "Voice Settings",
            "zh": "语音设置"
        ],
        "reminder_type": [
            "en": "Reminder Type",
            "zh": "提醒类型"
        ],
        "both_time_and_countdown": [
            "en": "Current Time + Countdown",
            "zh": "当前时间 + 倒计时"
        ],
        "countdown": [
            "en": "Countdown Only",
            "zh": "仅倒计时"
        ],
        "countdown_only": [
            "en": "Countdown Only",
            "zh": "仅倒计时"
        ],
        "breathing_prompts": [
            "en": "Breathing Prompts",
            "zh": "呼吸提示"
        ],
        "breathing_reminder": [
            "en": "Remind deep breathing 5x each interval",
            "zh": "每次间隔 提醒深呼吸5次"
        ],
        "remind_breathing": [
            "en": "Remind deep breathing",
            "zh": "提醒深呼吸"
        ],
        "test_voice": [
            "en": "Test Voice",
            "zh": "测试语音"
        ],
        "preview": [
            "en": "Preview",
            "zh": "预览"
        ],
        
        // Break View
        "great_job": [
            "en": "Great job! 🎉",
            "zh": "太棒了！🎉"
        ],
        "mindful_break": [
            "en": "Time for a mindful break",
            "zh": "是时候放松一下了"
        ],
        "start_breathing": [
            "en": "Start Breathing",
            "zh": "开始呼吸"
        ],
        "relax_tip": [
            "en": "Take a moment to relax and reset",
            "zh": "花点时间放松和调整"
        ],
        
        // Breathing Instructions
        "breathe_in": [
            "en": "Breathe In",
            "zh": "吸气"
        ],
        "hold": [
            "en": "Hold",
            "zh": "保持"
        ],
        "breathe_out": [
            "en": "Breathe Out",
            "zh": "呼气"
        ],
        "rest": [
            "en": "Rest",
            "zh": "休息"
        ],
        "breathe_in_instruction": [
            "en": "Breathe in slowly through your nose",
            "zh": "通过鼻子慢慢吸气"
        ],
        "hold_instruction": [
            "en": "Hold your breath",
            "zh": "保持呼吸"
        ],
        "breathe_out_instruction": [
            "en": "Breathe out slowly through your mouth",
            "zh": "通过嘴巴慢慢呼气"
        ],
        "rest_instruction": [
            "en": "Take a moment to rest",
            "zh": "稍作休息"
        ],
        
        "paused": [
            "en": "Paused",
            "zh": "已暂停"
        ]
    ]
    
    func string(for key: String, language: String) -> String {
        return strings[key]?[language] ?? key
    }
} 