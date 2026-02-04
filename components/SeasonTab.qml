import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import "../services" as Services

Item {
    id: root
    anchors.fill: parent

    property string searchText: ""
    property string filterType: "all"
    property bool isLoading: Services.AnimeScheduleService.isLoading
    property var animeList: Services.AnimeScheduleService.timetable

    // Filtered list based on search and filter
    property var filteredList: {
        let list = animeList || [];

        // Filter by search text
        if (searchText.length > 0) {
            const searchLower = searchText.toLowerCase();
            list = list.filter(anime => {
                const title = (anime.title || anime.route || "").toLowerCase();
                return title.includes(searchLower);
            });
        }

        return list;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingM

        // 1. Search, Filter Row, and Refresh Button
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            spacing: Theme.spacingS

            TextField {
                id: searchField
                Layout.fillWidth: true
                Layout.preferredHeight: 44

                placeholderText: "Search anime..."
                verticalAlignment: TextInput.AlignVCenter
                leftPadding: Theme.spacingL

                color: Theme.surfaceText
                placeholderTextColor: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeMedium

                onTextChanged: root.searchText = text

                background: Rectangle {
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh
                    border.color: searchField.activeFocus ? Theme.primary : Theme.outline
                    border.width: 1
                }
            }

            ComboBox {
                id: typeFilter
                Layout.preferredWidth: 100
                Layout.preferredHeight: 44

                model: ["All", "SUB", "DUB", "RAW"]

                contentItem: StyledText {
                    text: typeFilter.displayText
                    color: Theme.surfaceText
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }

                background: Rectangle {
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh
                    border.color: Theme.outline
                    border.width: 1
                }

                onCurrentTextChanged: {
                    root.filterType = currentText.toLowerCase();
                }
            }

            // Refresh Button
            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: Theme.cornerRadius
                color: refreshMouseArea.containsMouse ? Theme.primaryContainer : Theme.surfaceContainerHigh
                border.color: Theme.outline
                border.width: 1

                DankIcon {
                    anchors.centerIn: parent
                    name: "refresh"
                    size: 20
                    color: refreshMouseArea.containsMouse ? Theme.onPrimaryContainer : Theme.surfaceText

                    RotationAnimation on rotation {
                        running: root.isLoading
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                    }
                }

                MouseArea {
                    id: refreshMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.isLoading) {
                            Services.AnimeScheduleService.forceRefresh();
                        }
                    }
                }

                ToolTip.visible: refreshMouseArea.containsMouse
                ToolTip.text: "Refresh anime list"
                ToolTip.delay: 500
            }
        }

        // 2. Content Area
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Loading State
            LoadingState {
                anchors.centerIn: parent
                visible: root.isLoading && filteredList.length === 0
            }

            // Empty State
            EmptyState {
                anchors.centerIn: parent
                visible: !root.isLoading && filteredList.length === 0 && Services.AnimeScheduleService.apiToken !== ""
            }

            // No Token State
            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingM
                visible: Services.AnimeScheduleService.apiToken === ""

                DankIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "key"
                    size: 48
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "API Token Required"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Configure your token in plugin settings"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }

            // Error State
            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingM
                visible: Services.AnimeScheduleService.hasError && !root.isLoading

                DankIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "error"
                    size: 48
                    color: Theme.error
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Error loading data"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Services.AnimeScheduleService.errorMessage
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    width: Math.min(implicitWidth, parent.parent.width - Theme.spacingXL * 2)
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: retryText.width + Theme.spacingL * 2
                    height: retryText.height + Theme.spacingM
                    radius: Theme.cornerRadius
                    color: retryArea.containsMouse ? Theme.primaryContainer : Theme.surfaceContainerHigh
                    border.color: Theme.primary
                    border.width: 1

                    StyledText {
                        id: retryText
                        anchors.centerIn: parent
                        text: "Retry"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primary
                    }

                    MouseArea {
                        id: retryArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.AnimeScheduleService.forceRefresh()
                    }
                }
            }

            // Anime List
            ListView {
                id: animeListView
                anchors.fill: parent
                visible: filteredList.length > 0
                clip: true
                spacing: Theme.spacingXS

                model: filteredList

                delegate: AnimeListItem {
                    width: animeListView.width
                    anime: modelData
                    title: modelData.title || modelData.route || "Unknown"
                    episodeNumber: modelData.episodeNumber ? "Episode " + modelData.episodeNumber : ""
                    airTime: {
                        const date = Services.AnimeScheduleService.parseDate(modelData.episodeDate);
                        if (!date) return "";
                        return Services.AnimeScheduleService.formatDate(date) + " at " + Services.AnimeScheduleService.formatTime(date);
                    }
                    timeUntil: {
                        const date = Services.AnimeScheduleService.parseDate(modelData.episodeDate);
                        return Services.AnimeScheduleService.getTimeUntil(date);
                    }
                    imageUrl: {
                        if (modelData.imageVersionRoute) {
                            return Services.AnimeScheduleService.getImageUrl(modelData.imageVersionRoute);
                        }
                        return "";
                    }
                    isInWatchlist: Services.AnimeScheduleService.isInWatchlist(modelData)
                    onWatchlistToggled: function(anime) {
                        Services.AnimeScheduleService.toggleWatchlist(anime);
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                }
            }

            // Results count
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: Theme.spacingS
                visible: filteredList.length > 0 && searchText.length > 0
                width: countText.width + Theme.spacingM
                height: countText.height + Theme.spacingXS
                radius: Theme.cornerRadiusSmall
                color: Theme.surfaceContainerHighest
                opacity: 0.9

                StyledText {
                    id: countText
                    anchors.centerIn: parent
                    text: filteredList.length + " results"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }
    }
}
