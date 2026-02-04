import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import QtQuick.Layouts
import "./components" as AnimeCalendarComponents
import "./services" as Services

PluginComponent {
    id: root

    property string displayText: pluginData.displayText || "Hello"

    property int todayCount: Services.AnimeScheduleService.todayCount
    property bool isLoading: Services.AnimeScheduleService.isLoading

    // Initialize service with API token from settings
    Component.onCompleted: {
        updateApiToken();
        loadWatchlist();
    }

    // Watch for pluginData changes to update token
    onPluginDataChanged: {
        updateApiToken();
    }

    function updateApiToken() {
        const token = pluginData.apiToken || "";
        if (token !== Services.AnimeScheduleService.apiToken) {
            Services.AnimeScheduleService.setApiToken(token);
        }

        // Update refresh interval from settings
        const refreshInterval = (pluginData.refreshInterval || 15) * 60 * 1000;
        if (refreshInterval !== Services.AnimeScheduleService.updateInterval) {
            Services.AnimeScheduleService.updateInterval = refreshInterval;
        }
    }

    function loadWatchlist() {
        var saved = pluginData.watchlist || [];
        Services.AnimeScheduleService.setWatchlist(saved);
    }

    function saveWatchlist() {
        pluginData.watchlist = Services.AnimeScheduleService.watchlist;
    }

    Connections {
        target: Services.AnimeScheduleService
        function onWatchlistModified() {
            root.saveWatchlist();
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            DankIcon {
                name: "calendar_month"
                size: Theme.iconSize
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.todayCount > 0 ? root.todayCount + " today" : root.displayText
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: "calendar_month"
                size: Theme.iconSize
                color: Theme.primary
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.todayCount > 0 ? root.todayCount.toString() : ""
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.todayCount > 0
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popoutColumn

            headerText: "Anime Calendar"
            detailsText: root.todayCount + " airing today"
            showCloseButton: true

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - popoutColumn.headerHeight - popoutColumn.detailsHeight - Theme.spacingXL

                Column {
                    anchors.fill: parent
                    spacing: 0

                    //Tab Bar
                    Row {
                        width: parent.width
                        height: 40
                        spacing: 0

                        Repeater {
                            id: tabRepeater
                            model: ["Season", "Search", "Today"]

                            Rectangle{
                                width: parent.width / 3
                                height: parent.height
                                color: tabBar.currentIndex === index ? Theme.surfaceContainerHigh : "transparent"

                                StyledText {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: tabBar.currentIndex === index ? Font.Bold : Font.Normal
                                    color: tabBar.currentIndex === index ? Theme.primary : Theme.surfaceVariantText
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: tabBar.currentIndex = index
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 2
                                    color: Theme.primary
                                    visible: tabBar.currentIndex === index
                                }
                            }
                        }
                    }

                    //Tab Content
                    StackLayout {
                        id: tabBar
                        width: parent.width
                        height: parent.height - 40
                        currentIndex: 0

                        AnimeCalendarComponents.SeasonTab{

                        }
                        Rectangle {
                            color: "green"
                        }

                        // Tab 3: Today
                        AnimeCalendarComponents.TodayTab {
                        }
                    }
                }
            }
        }
    }

    popoutWidth: 400
    popoutHeight: 500
}
