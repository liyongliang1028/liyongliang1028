# VoicePomodoro 后台模式配置指南

为了使番茄钟应用能够在后台正常运行和进行语音提示，需要在项目的 `Info.plist` 文件中添加以下配置：

## 1. 添加后台模式支持

打开 Xcode 项目，然后在 `Info.plist` 文件中添加或修改以下内容：

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>processing</string>
</array>
```

这将允许应用程序在后台执行音频播放和处理任务。

## 2. 添加后台任务调度器标识符

还需要添加以下内容，以允许应用程序在后台执行定期任务：

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.elvali.VoicePomodoro.refresh</string>
</array>
```

## 3. 在 Xcode 中配置

如果你使用 Xcode 的图形界面，可以按照以下步骤添加上述配置：

1. 打开项目设置
2. 选择 "Signing & Capabilities" 选项卡
3. 点击 "+ Capability" 按钮
4. 添加 "Background Modes"
5. 勾选 "Audio, AirPlay, and Picture in Picture" 和 "Background processing"

## 4. 通知权限

应用已经配置为自动请求通知权限，但如果需要手动配置，请确保在 `Info.plist` 中添加：

```xml
<key>NSUserNotificationUsageDescription</key>
<string>我们需要发送通知来通知您番茄钟的状态和完成情况。</string>
```

## 重要提示

- 确保这些更改在提交到 App Store 之前已正确配置
- 后台模式可能会增加应用的电池消耗，请在测试时注意观察
- 在某些情况下，系统可能会限制后台活动，特别是在低电量模式下 