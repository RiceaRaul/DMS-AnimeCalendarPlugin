import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import "../services" as Services

Item {
    id: root

    property string searchText: ""
    readonly property var typeLabels: ["Sub", "Dub", "Raw"]
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

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            DankTextField {
                Layout.fillWidth: true
                placeholderText: "Search anime..."
                leftIconName: "search"
                showClearButton: true
                onTextChanged: root.searchText = text
            }

            DankDropdown {
                dropdownWidth: Theme.iconSizeLarge * 3
                options: root.typeLabels
                currentValue: {
                    const type = Services.AnimeScheduleService.timetableType;
                    return type.charAt(0).toUpperCase() + type.slice(1);
                }
                onValueChanged: value => Services.AnimeScheduleService.setTimetableType(value.toLowerCase())
            }

            DankActionButton {
                iconName: "refresh"
                tooltipText: "Refresh anime list"
                enabled: !root.isLoading
                onClicked: Services.AnimeScheduleService.forceRefresh()
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
                    size: Theme.iconSizeLarge
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
                    size: Theme.iconSizeLarge
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
            DankListView {
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
            }

            // Results count
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: Theme.spacingS
                visible: filteredList.length > 0 && searchText.length > 0
                width: countText.width + Theme.spacingM
                height: countText.height + Theme.spacingXS
                radius: Theme.cornerRadius / 2
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
