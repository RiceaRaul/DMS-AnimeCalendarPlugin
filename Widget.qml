import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins
import QtQuick.Layouts
import Quickshell
import "./components" as AnimeCalendarComponents
import "./services" as Services

PluginComponent {
    id: root

    readonly property int todayCount: Services.AnimeScheduleService.watchlistTodayCount
    readonly property string barMode: pluginData.barIndicatorMode ?? "icon_count"
    readonly property bool needsSetup: Services.AnimeScheduleService.apiToken === ""
    readonly property string pillIcon: needsSetup ? "key_off" : "calendar_month"

    // Ticks the countdown; stopped while the bar is hidden or the countdown isn't shown
    SystemClock {
        id: clock
        enabled: root.surfaceLive && root.barMode === "icon_time"
        precision: SystemClock.Minutes
    }

    readonly property string nextAiringTime: {
        const now = clock.date.getTime();
        const list = Services.AnimeScheduleService.watchlistTodayAnime;
        for (let i = 0; i < list.length; i++) {
            const airDate = Services.AnimeScheduleService.parseDate(list[i].episodeDate);
            if (airDate && airDate.getTime() > now)
                return Services.AnimeScheduleService.getTimeUntil(airDate);
        }
        return "";
    }

    readonly property string pillText: {
        const countText = todayCount > 0 ? I18n.trFor("animeCalendar", "%1 today").arg(todayCount) : "";
        if (needsSetup || barMode === "icon_only")
            return "";
        if (barMode === "icon_time")
            return nextAiringTime || countText;
        return countText;
    }


    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.pillIcon
                size: root.iconSize
                color: Theme.widgetIconColor
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                text: root.pillText
                font.pixelSize: root.textSize
                color: Theme.widgetTextColor
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXXS

            DIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: root.pillIcon
                size: root.iconSize
                color: Theme.widgetIconColor
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
                text: {
                    if (root.needsSetup || root.barMode === "icon_only")
                        return "";
                    if (root.barMode === "icon_time")
                        return root.nextAiringTime;
                    return root.todayCount > 0 ? root.todayCount.toString() : "";
                }
                font.pixelSize: root.textSize
                color: Theme.widgetTextColor
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popoutColumn

            headerText: I18n.trFor("animeCalendar", "Anime Calendar")
            detailsText: root.needsSetup ? "" : root.todayCount > 0 ? I18n.trFor("animeCalendar", "%1 from watchlist airing today").arg(root.todayCount) : I18n.trFor("animeCalendar", "No watchlist anime today")
            showCloseButton: true

            Component.onCompleted: Services.AnimeScheduleService.refreshIfStale()
            onVisibleChanged: {
                if (visible)
                    Services.AnimeScheduleService.refreshIfStale();
            }

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - popoutColumn.headerHeight - popoutColumn.detailsHeight - Theme.spacingXL

                DTabBar {
                    id: tabBar
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    tabHeight: Theme.buttonHeightS
                    model: [
                        { text: I18n.trFor("animeCalendar", "Season"), icon: "calendar_month" },
                        { text: I18n.trFor("animeCalendar", "Today"), icon: "today" }
                    ]
                    onTabClicked: index => tabBar.currentIndex = index
                }

                StackLayout {
                    anchors.top: tabBar.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: updatedRow.visible ? updatedRow.top : parent.bottom
                    currentIndex: tabBar.currentIndex

                    AnimeCalendarComponents.SeasonTab {}

                    AnimeCalendarComponents.TodayTab {}
                }

                Row {
                    id: updatedRow
                    readonly property bool offline: Services.AnimeScheduleService.isOffline
                    readonly property string time: {
                        const date = new Date(Services.AnimeScheduleService.lastUpdated);
                        const clock = Services.AnimeScheduleService.formatTime(date);
                        if (Services.AnimeScheduleService.isToday(date))
                            return clock;
                        return I18n.trFor("animeCalendar", "%1 at %2").arg(Services.AnimeScheduleService.formatDate(date)).arg(clock);
                    }

                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingXS
                    visible: !root.needsSetup && Services.AnimeScheduleService.lastUpdated > 0

                    DIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: updatedRow.offline
                        name: "cloud_off"
                        size: Theme.iconSizeSmall
                        color: Theme.error
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: updatedRow.offline ? I18n.trFor("animeCalendar", "Offline — showing data from %1").arg(updatedRow.time) : I18n.trFor("animeCalendar", "Updated %1").arg(updatedRow.time)
                        font.pixelSize: Theme.fontSizeSmall
                        color: updatedRow.offline ? Theme.error : Theme.surfaceVariantText
                    }
                }
            }
        }
    }

    popoutWidth: Theme.listItemHeight * 7
    popoutHeight: Theme.listItemHeight * 9
}
