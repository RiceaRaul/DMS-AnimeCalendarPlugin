import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "animeCalendar"

    StyledText {
        width: parent.width
        text: "Anime Calendar"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Track and get notified about anime episode releases"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    StyledText {
        width: parent.width
        text: "API Configuration"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StringSetting {
        settingKey: "apiToken"
        label: "API Token"
        description: "Get your token from animeschedule.net"
        placeholder: "Enter API token"
        defaultValue: ""
    }
    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    // Display Settings
    StyledText {
        width: parent.width
        text: "Display Settings"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }
    SelectionSetting {
        settingKey: "barIndicatorMode"
        label: "Bar Indicator"
        description: "How to display the widget in the bar"
        options: [
            {
                label: "Icon Only",
                value: "icon_only"
            },
            {
                label: "Icon + Count",
                value: "icon_count"
            },
            {
                label: "Icon + Countdown",
                value: "icon_time"
            }
        ]
        defaultValue: "icon_count"
    }
  
    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    // Notifications
    StyledText {
        width: parent.width
        text: "Notifications"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "enableInstantNotifications"
        label: "Instant Notifications"
        description: "Notify when episodes from your watchlist air"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "enableDailyDigest"
        label: "Daily Digest"
        description: "Morning summary of today's episodes"
        defaultValue: true
    }

    StringSetting {
        settingKey: "digestTime"
        label: "Digest Time"
        description: "Time for daily digest (HH:MM format)"
        placeholder: "08:00"
        defaultValue: "08:00"
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    // Data Settings
    StyledText {
        width: parent.width
        text: "Data"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SliderSetting {
        settingKey: "refreshInterval"
        label: "Refresh Interval"
        description: "How often to check for new episodes"
        defaultValue: 15
        minimum: 5
        maximum: 60
        unit: "min"
    }

    SliderSetting {
        settingKey: "cacheDuration"
        label: "Cache Duration"
        description: "How long to keep cached data"
        defaultValue: 30
        minimum: 10
        maximum: 120
        unit: "min"
    }
}