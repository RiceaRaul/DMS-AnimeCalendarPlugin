pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Settings (set by Widget)
    property bool enableInstantNotifications: true
    property bool enableDailyDigest: true
    property string digestTime: "08:00"
    property string notificationIcon: "x-office-calendar"

    // State tracking
    property string lastDigestDate: ""
    property int lastDigestTimestamp: 0
    property var notifiedAnime: ({})

    // Reference to anime service
    readonly property var animeService: AnimeScheduleService

    signal notificationSent(string title, string body)

    function configure(settings) {
        if (settings.enableInstantNotifications !== undefined)
            root.enableInstantNotifications = settings.enableInstantNotifications;
        if (settings.enableDailyDigest !== undefined)
            root.enableDailyDigest = settings.enableDailyDigest;
        if (settings.digestTime !== undefined)
            root.digestTime = settings.digestTime;
        if (settings.notificationIcon !== undefined)
            root.notificationIcon = settings.notificationIcon;

        // Schedule instant notifications if enabled
        if (root.enableInstantNotifications) {
            scheduleNextNotification();
        }
    }

    function sendNotification(title, body) {
        notificationProcess.command = ["notify-send", "-a", "Anime Calendar", "-i", notificationIcon, title, body];
        notificationProcess.running = true;
        notificationSent(title, body);
    }

    // Digest notification logic
    function checkDigestTime() {
        var now = new Date();
        var timestamp = now.getTime();

        // Prevent triggering within 60 seconds of last trigger
        if (timestamp - lastDigestTimestamp < 60000) return;

        var currentTime = ("0" + now.getHours()).slice(-2) + ":" + ("0" + now.getMinutes()).slice(-2);
        var currentDate = now.toDateString();

        if (currentTime === digestTime && lastDigestDate !== currentDate) {
            lastDigestDate = currentDate;
            lastDigestTimestamp = timestamp;
            sendDailyDigest();
        }
    }

    function sendDailyDigest() {
        var count = animeService.watchlistTodayCount;
        if (count === 0) {
            sendNotification("Anime Calendar", "No watchlist anime airing today");
        } else {
            var list = animeService.watchlistTodayAnime;
            var titles = [];
            for (var i = 0; i < Math.min(list.length, 3); i++) {
                titles.push(list[i].title || list[i].route);
            }
            var msg = count + " anime today: " + titles.join(", ");
            if (count > 3) msg += "...";
            sendNotification("Anime Calendar - Daily Digest", msg);
        }
    }

    // Instant notification logic
    function scheduleNextNotification() {
        if (!enableInstantNotifications) {
            instantNotificationTimer.running = false;
            return;
        }

        var list = animeService.watchlistTodayAnime;
        if (!list || list.length === 0) {
            instantNotificationTimer.running = false;
            return;
        }

        var now = new Date();
        var nextTime = -1;

        for (var i = 0; i < list.length; i++) {
            var anime = list[i];
            var airDate = animeService.parseDate(anime.episodeDate);
            if (!airDate) continue;

            var key = anime.route + "_" + anime.episodeNumber;
            if (notifiedAnime[key]) continue;

            var diff = airDate.getTime() - now.getTime();
            if (diff > 0 && (nextTime === -1 || diff < nextTime)) {
                nextTime = diff;
            }
        }

        if (nextTime > 0) {
            instantNotificationTimer.interval = nextTime + 1000; // Add 1 sec buffer
            instantNotificationTimer.running = true;
        } else {
            instantNotificationTimer.running = false;
        }
    }

    function triggerInstantNotification() {
        var list = animeService.watchlistTodayAnime;
        if (!list) return;

        var now = new Date();
        for (var i = 0; i < list.length; i++) {
            var anime = list[i];
            var airDate = animeService.parseDate(anime.episodeDate);
            if (!airDate) continue;

            var diff = Math.abs(airDate.getTime() - now.getTime());
            var key = anime.route + "_" + anime.episodeNumber;

            // Notify if within 2 minutes of air time and not notified
            if (diff <= 120000 && !notifiedAnime[key]) {
                sendNotification(
                    "Anime Airing Now!",
                    (anime.title || anime.route) + " - Episode " + (anime.episodeNumber || "?")
                );
                notifiedAnime[key] = true;
            }
        }
    }

    // Timer for instant notifications
    Timer {
        id: instantNotificationTimer
        running: false
        repeat: false
        onTriggered: {
            root.triggerInstantNotification();
            root.scheduleNextNotification();
        }
    }

    // Timer for daily digest - check every minute
    Timer {
        id: digestTimer
        interval: 60000
        running: root.enableDailyDigest
        repeat: true
        onTriggered: root.checkDigestTime()
    }

    // Re-schedule when timetable updates
    Connections {
        target: AnimeScheduleService
        function onTimetableUpdated() {
            if (root.enableInstantNotifications) {
                root.scheduleNextNotification();
            }
        }
    }

    Process {
        id: notificationProcess
        running: false
    }
}
