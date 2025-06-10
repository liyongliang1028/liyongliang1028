import SwiftUI

// 定义应用的主题管理器
class ThemeManager {
    static let shared = ThemeManager()
    
    // 色彩方案
    struct ThemeColors {
        // 主题颜色
        let primary: Color // 番茄红色，用于突出显示和主按钮
        let background: Color // 背景色
        let secondaryBackground: Color // 二级背景色，用于卡片等元素
        let text: Color // 主文字颜色
        let secondaryText: Color // 次要文字颜色
        let border: Color // 边框颜色
        let separator: Color // 分隔线颜色
        
        // 语义颜色
        let success: Color // 成功状态颜色
        let warning: Color // 警告状态颜色
        let error: Color // 错误状态颜色
    }
    
    // 浅色模式颜色
    var lightTheme: ThemeColors {
        ThemeColors(
            primary: Color(hex: "E93F33"), // 番茄红色
            background: Color(hex: "F2F2F7"), // 浅灰色背景
            secondaryBackground: Color.white, // 白色卡片
            text: Color.black, // 黑色文字
            secondaryText: Color.gray, // 灰色文字
            border: Color.gray.opacity(0.2), // 浅灰色边框
            separator: Color.gray.opacity(0.3), // 分隔线
            success: Color.green,
            warning: Color.orange,
            error: Color.red
        )
    }
    
    // 深色模式颜色
    var darkTheme: ThemeColors {
        ThemeColors(
            primary: Color(hex: "FF6B6B"), // 更亮的番茄红色
            background: Color.black, // 黑色背景
            secondaryBackground: Color(hex: "1C1C1E"), // 深灰色卡片
            text: Color.white, // 白色文字
            secondaryText: Color.gray, // 灰色文字
            border: Color.gray.opacity(0.3), // 深灰色边框
            separator: Color.gray.opacity(0.4), // 分隔线
            success: Color.green,
            warning: Color.orange,
            error: Color.red
        )
    }
    
    // 根据系统颜色方案获取当前主题
    func currentTheme(for colorScheme: ColorScheme) -> ThemeColors {
        colorScheme == .dark ? darkTheme : lightTheme
    }
}

// 扩展View添加主题访问便捷方法
extension View {
    func withTheme(_ colorScheme: ColorScheme) -> some View {
        let theme = ThemeManager.shared.currentTheme(for: colorScheme)
        return self
            .foregroundColor(theme.text)
            .background(theme.background.ignoresSafeArea())
    }
}

// 添加ColorScheme值的存储用于用户手动选择主题
extension ColorScheme {
    var name: String {
        self == .dark ? "Dark Mode" : "Light Mode"
    }
    
    var localizedName: String {
        self == .dark ? "深色模式" : "浅色模式"
    }
} 