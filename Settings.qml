import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.DCommon.Widgets
import Quickshell.Io
import "./services" as Services

PluginSettings {
    id: root
    pluginId: "animeCalendar"

    StyledText {
        width: parent.width
        text: I18n.trFor("animeCalendar", "Anime Calendar")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: I18n.trFor("animeCalendar", "Track and get notified about anime episode releases")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Rectangle {
        width: parent.width
        height: Theme.outlineWidth
        color: Theme.outline
        opacity: 0.3
    }

    StyledText {
        width: parent.width
        text: I18n.trFor("animeCalendar", "API Configuration")
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StringSetting {
        settingKey: "apiTokenPath"
        label: I18n.trFor("animeCalendar", "API Token File Path")
        description: I18n.trFor("animeCalendar", "Path to a file containing the API token (takes precedence over the inline token below). Useful for declarative configs like NixOS.")
        placeholder: "/run/secrets/animeschedule_token"
        defaultValue: ""
    }

    StringSetting {
        settingKey: "apiToken"
        label: I18n.trFor("animeCalendar", "API Token")
        description: I18n.trFor("animeCalendar", "Get your token from animeschedule.net. Ignored if a token file path is set.")
        placeholder: I18n.trFor("animeCalendar", "Enter API token")
        defaultValue: ""
    }
    Rectangle {
        width: parent.width
        height: Theme.outlineWidth
        color: Theme.outline
        opacity: 0.3
    }

    // Display Settings
    StyledText {
        width: parent.width
        text: I18n.trFor("animeCalendar", "Display Settings")
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }
    SelectionSetting {
        settingKey: "barIndicatorMode"
        label: I18n.trFor("animeCalendar", "Bar Indicator")
        description: I18n.trFor("animeCalendar", "How to display the widget in the bar")
        options: [
            {
                label: I18n.trFor("animeCalendar", "Icon Only"),
                value: "icon_only"
            },
            {
                label: I18n.trFor("animeCalendar", "Icon + Count"),
                value: "icon_count"
            },
            {
                label: I18n.trFor("animeCalendar", "Icon + Countdown"),
                value: "icon_time"
            }
        ]
        defaultValue: "icon_count"
    }
  
    Rectangle {
        width: parent.width
        height: Theme.outlineWidth
        color: Theme.outline
        opacity: 0.3
    }

    // Notifications
    StyledText {
        width: parent.width
        text: I18n.trFor("animeCalendar", "Notifications")
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "enableInstantNotifications"
        label: I18n.trFor("animeCalendar", "Instant Notifications")
        description: I18n.trFor("animeCalendar", "Notify when episodes from your watchlist air")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "enableDailyDigest"
        label: I18n.trFor("animeCalendar", "Daily Digest")
        description: I18n.trFor("animeCalendar", "Morning summary of today's episodes")
        defaultValue: true
    }

    StringSetting {
        settingKey: "digestTime"
        label: I18n.trFor("animeCalendar", "Digest Time")
        description: I18n.trFor("animeCalendar", "Time for daily digest (HH:MM format)")
        placeholder: "08:00"
        defaultValue: "08:00"
    }

    StringSetting {
        settingKey: "notificationIcon"
        label: I18n.trFor("animeCalendar", "Notification Icon")
        description: I18n.trFor("animeCalendar", "Icon name or path (e.g., x-office-calendar, video-x-generic, /path/to/icon.png)")
        placeholder: "x-office-calendar"
        defaultValue: "x-office-calendar"
    }

    Rectangle {
        width: parent.width
        height: Theme.outlineWidth
        color: Theme.outline
        opacity: 0.3
    }

    // Data Settings
    StyledText {
        width: parent.width
        text: I18n.trFor("animeCalendar", "Data")
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SliderSetting {
        settingKey: "refreshInterval"
        label: I18n.trFor("animeCalendar", "Refresh Interval")
        description: I18n.trFor("animeCalendar", "How often to check for new episodes")
        defaultValue: 15
        minimum: 5
        maximum: 60
        unit: "min"
    }

    Rectangle {
        width: parent.width
        height: Theme.outlineWidth
        color: Theme.outline
        opacity: 0.3
    }

    // Test Notifications
    StyledText {
        width: parent.width
        text: I18n.trFor("animeCalendar", "Test")
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    DButton {
        text: I18n.trFor("animeCalendar", "Test Notification")
        iconName: "notifications"
        onClicked: Services.NotificationService.sendNotification(I18n.trFor("animeCalendar", "Anime Calendar Test"), I18n.trFor("animeCalendar", "Notifications are working!"))
    }
}
