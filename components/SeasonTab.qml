import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets
import "../services" as Services

Item {
    id: root

    property string searchText: ""
    readonly property var typeValues: ["sub", "dub", "raw"]
    readonly property var typeLabels: [I18n.trFor("animeCalendar", "Sub"), I18n.trFor("animeCalendar", "Dub"), I18n.trFor("animeCalendar", "Raw")]
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

            DTextField {
                Layout.fillWidth: true
                placeholderText: I18n.trFor("animeCalendar", "Search anime...")
                leftIconName: "search"
                showClearButton: true
                onTextChanged: root.searchText = text
            }

            DDropdown {
                dropdownWidth: Theme.iconSizeLarge * 3
                options: root.typeLabels
                currentValue: root.typeLabels[Math.max(0, root.typeValues.indexOf(Services.AnimeScheduleService.timetableType))]
                onValueChanged: value => Services.AnimeScheduleService.setTimetableType(root.typeValues[root.typeLabels.indexOf(value)])
            }

            DActionButton {
                iconName: "refresh"
                tooltipText: I18n.trFor("animeCalendar", "Refresh anime list")
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

                DIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "key"
                    size: Theme.iconSizeLarge
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.trFor("animeCalendar", "API Token Required")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.trFor("animeCalendar", "Configure your token in plugin settings")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }

            // Error State
            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingM
                visible: Services.AnimeScheduleService.hasError && !root.isLoading

                DIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "error"
                    size: Theme.iconSizeLarge
                    color: Theme.error
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.trFor("animeCalendar", "Error loading data")
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
                        text: I18n.trFor("animeCalendar", "Retry")
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
            DListView {
                id: animeListView
                anchors.fill: parent
                visible: filteredList.length > 0
                clip: true
                spacing: Theme.spacingXS

                model: filteredList

                delegate: AnimeListItem {
                    width: animeListView.width
                    anime: modelData
                    title: modelData.title || modelData.route || I18n.trFor("animeCalendar", "Unknown")
                    episodeNumber: modelData.episodeNumber ? I18n.trFor("animeCalendar", "Episode %1").arg(modelData.episodeNumber) : ""
                    airTime: {
                        const date = Services.AnimeScheduleService.parseDate(modelData.episodeDate);
                        if (!date) return "";
                        return Services.AnimeScheduleService.I18n.trFor("animeCalendar", "%1 at %2").arg(Services.AnimeScheduleService.formatDate(date)).arg(Services.AnimeScheduleService.formatTime(date));
                    }
                    timeUntil: {
                        const date = Services.AnimeScheduleService.parseDate(modelData.episodeDate);
                        return Services.AnimeScheduleService.getTimeUntil(date);
                    }
                    aired: Services.AnimeScheduleService.hasAired(Services.AnimeScheduleService.parseDate(modelData.episodeDate))
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
                radius: Theme.cornerRadiusS
                color: Theme.surfaceContainerHighest
                opacity: 0.9

                StyledText {
                    id: countText
                    anchors.centerIn: parent
                    text: I18n.trFor("animeCalendar", "%1 results").arg(filteredList.length)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }
    }
}
