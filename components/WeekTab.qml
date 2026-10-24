import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets
import "../services" as Services

Item {
    id: root

    property string searchText: ""
    property int weekOffset: 0
    property bool scrolledToToday: false
    readonly property var typeValues: ["sub", "dub", "raw", "all"]
    readonly property var typeLabels: [I18n.trFor("animeCalendar", "Sub"), I18n.trFor("animeCalendar", "Dub"), I18n.trFor("animeCalendar", "Raw"), I18n.trFor("animeCalendar", "All")]
    readonly property string airType: Services.AnimeScheduleService.timetableType
    readonly property bool hasToken: Services.AnimeScheduleService.apiToken !== ""

    readonly property date viewStart: Services.AnimeScheduleService.viewWeekStart(weekOffset)
    readonly property var viewWeeks: Services.AnimeScheduleService.weeksCovering(viewStart)
    readonly property var weekStates: viewWeeks.map(week => Services.AnimeScheduleService.weeks[Services.AnimeScheduleService.weekKey(week, airType)] || {})
    readonly property bool weekLoading: weekStates.some(state => state.loading)
    readonly property string weekError: weekStates.map(state => state.error || "").find(error => error !== "") || ""

    readonly property var rows: {
        const query = searchText.toLowerCase();
        const entries = Services.AnimeScheduleService.viewEntries(viewStart, airType).filter(anime => {
            if (!query)
                return true;
            return [anime.title, anime.english, anime.romaji, anime.route].some(name => (name || "").toLowerCase().includes(query));
        });
        let previousDay = "";
        return entries.map(anime => {
            const date = Services.AnimeScheduleService.parseDate(anime.episodeDate);
            const day = date.toDateString();
            const row = { anime: anime, date: date, firstOfDay: day !== previousDay };
            previousDay = day;
            return row;
        });
    }

    onWeekOffsetChanged: {
        scrolledToToday = false;
        loadTimer.restart();
    }
    onAirTypeChanged: loadTimer.restart()
    onRowsChanged: scrollToToday()
    Component.onCompleted: loadView(false)

    function loadView(force) {
        for (const week of viewWeeks) {
            if (!force)
                Services.AnimeScheduleService.ensureWeek(week, airType);
            else if (!Services.AnimeScheduleService.weeks[Services.AnimeScheduleService.weekKey(week, airType)]?.loading)
                Services.AnimeScheduleService.loadWeek(week, airType, null);
        }
    }

    function scrollToToday() {
        if (scrolledToToday || !rows.length)
            return;
        scrolledToToday = true;
        if (weekOffset !== 0) {
            listView.positionViewAtBeginning();
            return;
        }
        const today = new Date().toDateString();
        const index = rows.findIndex(row => row.date.toDateString() === today);
        Qt.callLater(() => listView.positionViewAtIndex(Math.max(0, index), ListView.Beginning));
    }

    function rangeText() {
        const end = Services.AnimeScheduleService.addDays(viewStart, 6);
        return I18n.trFor("animeCalendar", "%1 – %2").arg(viewStart.toLocaleDateString(Qt.locale(), "MMM d")).arg(end.toLocaleDateString(Qt.locale(), "MMM d"));
    }

    // Arrow clicks settle before any request goes out
    Timer {
        id: loadTimer
        interval: 350
        onTriggered: root.loadView(false)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXS

            DActionButton {
                iconName: "chevron_left"
                tooltipText: I18n.trFor("animeCalendar", "Previous week")
                onClicked: root.weekOffset--
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.weekOffset === 0 ? I18n.trFor("animeCalendar", "This week") : root.rangeText()
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            DActionButton {
                visible: root.weekOffset !== 0
                iconName: "today"
                tooltipText: I18n.trFor("animeCalendar", "Back to this week")
                onClicked: root.weekOffset = 0
            }

            DActionButton {
                iconName: "chevron_right"
                tooltipText: I18n.trFor("animeCalendar", "Next week")
                onClicked: root.weekOffset++
            }
        }

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
                currentValue: root.typeLabels[Math.max(0, root.typeValues.indexOf(root.airType))]
                onValueChanged: value => Services.AnimeScheduleService.setTimetableType(root.typeValues[root.typeLabels.indexOf(value)])
            }

            DActionButton {
                iconName: "refresh"
                tooltipText: I18n.trFor("animeCalendar", "Refresh anime list")
                enabled: !Services.AnimeScheduleService.isLoading && !root.weekLoading
                onClicked: {
                    Services.AnimeScheduleService.forceRefresh();
                    root.loadView(true);
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            LoadingState {
                anchors.centerIn: parent
                visible: root.hasToken && root.weekLoading && root.rows.length === 0
            }

            SetupState {
                anchors.centerIn: parent
                width: parent.width - Theme.spacingXL * 2
                visible: !root.hasToken
            }

            EmptyState {
                anchors.centerIn: parent
                iconName: root.searchText ? "search_off" : "event_busy"
                message: root.searchText ? I18n.trFor("animeCalendar", "No results") : I18n.trFor("animeCalendar", "Nothing airs this week")
                visible: root.hasToken && !root.weekLoading && root.rows.length === 0 && root.weekError === ""
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - Theme.spacingXL * 2
                spacing: Theme.spacingM
                visible: root.hasToken && !root.weekLoading && root.rows.length === 0 && root.weekError !== ""

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
                    width: parent.width
                    text: root.weekError
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                DButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.trFor("animeCalendar", "Retry")
                    iconName: "refresh"
                    onClicked: root.loadView(true)
                }
            }

            DListView {
                id: listView
                anchors.fill: parent
                visible: root.hasToken && root.rows.length > 0
                clip: true
                spacing: Theme.spacingXS
                model: root.rows

                delegate: Column {
                    id: rowItem
                    required property var modelData
                    readonly property var anime: modelData.anime
                    readonly property bool today: Services.AnimeScheduleService.isToday(modelData.date)

                    width: listView.width
                    spacing: Theme.spacingXS

                    StyledText {
                        visible: rowItem.modelData.firstOfDay
                        topPadding: Theme.spacingS
                        leftPadding: Theme.spacingS
                        text: {
                            const day = rowItem.modelData.date.toLocaleDateString(Qt.locale(), "dddd, MMM d");
                            return rowItem.today ? I18n.trFor("animeCalendar", "Today · %1").arg(day) : day;
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: rowItem.today ? Theme.primary : Theme.surfaceVariantText
                    }

                    AnimeListItem {
                        width: parent.width
                        anime: rowItem.anime
                        title: Services.AnimeScheduleService.displayTitle(null, rowItem.anime)
                        episodeNumber: {
                            const label = Services.AnimeScheduleService.episodeLabel(Number(rowItem.anime.episodeNumber) || 0, Number(rowItem.anime.episodes) || 0);
                            if (root.airType !== "all")
                                return label;
                            return [label, Services.AnimeScheduleService.airTypeLabel(rowItem.anime.airType)].filter(part => part !== "").join(" · ");
                        }
                        airTime: Services.AnimeScheduleService.formatTime(rowItem.modelData.date)
                        timeUntil: Services.AnimeScheduleService.getTimeUntil(rowItem.modelData.date)
                        aired: Services.AnimeScheduleService.hasAired(rowItem.modelData.date)
                        delayed: Services.AnimeScheduleService.isDelayed(rowItem.anime)
                        imageUrl: Services.AnimeScheduleService.getImageUrl(rowItem.anime.imageVersionRoute)
                        isInWatchlist: Services.AnimeScheduleService.isInWatchlist(rowItem.anime)
                        onWatchlistToggled: anime => Services.AnimeScheduleService.toggleWatchlist(anime)
                    }
                }
            }
        }
    }
}
