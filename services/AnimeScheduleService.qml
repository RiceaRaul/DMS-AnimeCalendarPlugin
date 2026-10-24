pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    // API Configuration
    property string apiTokenPath: ""
    property string _tokenFromFile: ""
    property string _tokenFromSettings: ""
    readonly property string apiToken: apiTokenPath !== "" ? _tokenFromFile : _tokenFromSettings
    property string baseUrl: "https://animeschedule.net/api/v3"

    // State
    property bool isLoading: false
    property bool hasError: false
    property string errorMessage: ""
    property real lastFetchTime: 0
    property real lastUpdated: 0
    readonly property bool isOffline: hasError && timetable.length > 0
    readonly property int staleAfter: 15 * 60 * 1000
    property int minFetchInterval: 30000 // 30 seconds minimum between requests

    // This and next ISO week for timetableType; weeks holds every week loaded this session
    property var timetable: []
    property var nextTimetable: []
    property var weeks: ({})
    readonly property int maxWeeks: 8

    // Entries { route, title, english, romaji, native, image, episodes, finished }, persisted by Daemon.qml
    property var watchlist: []
    property var watchlistTodayAnime: []
    property int watchlistTodayCount: 0

    // Retry logic
    property int retryAttempts: 0
    property int maxRetryAttempts: 3
    property int retryDelay: 5000

    // Update interval (default 15 minutes)
    property int updateInterval: 900000

    // "sub", "dub", "raw" or "all"
    property string timetableType: "sub"

    readonly property var curlBaseCmd: ["curl", "-sS", "--fail", "--connect-timeout", "10", "--max-time", "30", "--compressed"]

    // Pending { url, callbacks }; one curl at a time
    property var _queue: []
    property var _active: null

    // fromCache: loaded from plugin state on start, not fetched
    signal timetableUpdated(bool fromCache)
    signal errorOccurred(string message)
    signal watchlistModified()

    function setApiToken(token) {
        root._tokenFromSettings = token || "";
        refreshIfStale();
    }

    function setApiTokenPath(path) {
        root.apiTokenPath = path || "";
        if (root.apiTokenPath) {
            tokenFileLoader.running = true;
        } else {
            root._tokenFromFile = "";
        }
    }

    function reloadApiTokenFile() {
        if (root.apiTokenPath) {
            tokenFileLoader.running = true;
        }
    }

    function refresh() {
        fetchTimetable(root.timetableType);
    }

    function setTimetableType(type) {
        if (!type || type === root.timetableType)
            return;
        root.timetableType = type;
        publishWeeks();
        forceRefresh();
    }

    function fetchTimetable(type) {
        if (!apiToken) {
            root.hasError = true;
            root.errorMessage = I18n.trFor("animeCalendar", "API token not configured");
            errorOccurred(root.errorMessage);
            return;
        }

        if (root.isLoading)
            return;

        const now = Date.now();
        if (now - root.lastFetchTime < root.minFetchInterval)
            return;

        root.lastFetchTime = now;
        root.isLoading = true;
        root.hasError = false;
        root.errorMessage = "";

        let pending = 2;
        let currentError = null;
        const finish = () => {
            pending--;
            if (pending > 0)
                return;
            root.isLoading = false;
            // The type changed while loading; that fetch was skipped
            if (type !== root.timetableType)
                Qt.callLater(root.forceRefresh);
            if (currentError) {
                root.handleFailure(currentError);
                return;
            }
            root.lastUpdated = Date.now();
            root.handleSuccess();
            root.timetableUpdated(false);
        };
        loadWeek(isoWeek(new Date()), type, error => {
            currentError = error;
            root.publishWeeks();
            finish();
        });
        loadWeek(isoWeek(addDays(new Date(), 7)), type, () => {
            root.publishWeeks();
            finish();
        });
    }

    function loadWeek(week, type, done) {
        const key = weekKey(week, type);
        storeWeek(key, { loading: true });
        request("/timetables/" + type, { year: week.year, week: week.week }, (error, data) => {
            if (!error && !Array.isArray(data))
                error = I18n.trFor("animeCalendar", "Invalid response format");
            if (error)
                storeWeek(key, { loading: false, error: error });
            else
                storeWeek(key, { loading: false, error: "", time: Date.now(), data: data });
            if (done)
                done(error);
        });
    }

    // For browsing other weeks; a loaded week is reused until the refresh interval passes
    function ensureWeek(week, type) {
        if (!root.apiToken)
            return;
        const entry = root.weeks[weekKey(week, type)];
        if (entry && (entry.loading || (entry.data && Date.now() - entry.time < root.updateInterval)))
            return;
        loadWeek(week, type, null);
    }

    function storeWeek(key, fields) {
        const next = Object.assign({}, root.weeks);
        next[key] = Object.assign({}, next[key], fields);
        const keys = Object.keys(next);
        if (keys.length > root.maxWeeks) {
            const keep = [currentWeekKey(), nextWeekKey(), key];
            const oldest = keys.filter(k => keep.indexOf(k) === -1 && !next[k].loading).sort((a, b) => (next[a].time || 0) - (next[b].time || 0))[0];
            if (oldest)
                delete next[oldest];
        }
        root.weeks = next;
    }

    function weekData(week, type) {
        return root.weeks[weekKey(week, type)]?.data || [];
    }

    function currentWeekKey() {
        return weekKey(isoWeek(new Date()), root.timetableType);
    }

    function nextWeekKey() {
        return weekKey(isoWeek(addDays(new Date(), 7)), root.timetableType);
    }

    function publishWeeks() {
        root.timetable = root.weeks[currentWeekKey()]?.data || [];
        root.nextTimetable = root.weeks[nextWeekKey()]?.data || [];
        updateWatchlistToday();
    }

    // callback(error, data): error is a translated message or null
    function request(path, query, callback) {
        if (!root.apiToken) {
            callback(I18n.trFor("animeCalendar", "API token not configured"), null);
            return;
        }
        let url = root.baseUrl + path;
        const params = Object.keys(query || {}).map(key => encodeURIComponent(key) + "=" + encodeURIComponent(query[key]));
        if (params.length)
            url += "?" + params.join("&");

        const pending = root._active?.url === url ? root._active : root._queue.find(item => item.url === url);
        if (pending) {
            pending.callbacks.push(callback);
            return;
        }
        root._queue.push({ url: url, callbacks: [callback] });
        root._runNext();
    }

    function _runNext() {
        if (root._active || !root._queue.length)
            return;
        root._active = Object.assign(root._queue.shift(), { exitCode: -1, exited: false, body: null });
        // "-H @-" reads the auth header from stdin so the token never shows up in ps or /proc
        requester.command = curlBaseCmd.concat(["-H", "@-", "-H", "Accept: application/json", root._active.url]);
        requester.stdinEnabled = true;
        requester.running = true;
    }

    // Process exit and stdout end arrive in either order; finish after both
    function _maybeFinish() {
        const job = root._active;
        if (!job || !job.exited || job.body === null)
            return;
        root._active = null;

        let error = null;
        let data = null;
        if (job.exitCode !== 0) {
            error = I18n.trFor("animeCalendar", "Request failed with exit code: %1").arg(job.exitCode);
        } else {
            try {
                data = JSON.parse(job.body);
            } catch (e) {
                error = I18n.trFor("animeCalendar", "Failed to parse response: %1").arg(e.message);
            }
        }
        for (const callback of job.callbacks)
            callback(error, data);
        root._runNext();
    }

    function refreshIfStale() {
        if (!root.apiToken)
            return;
        if (root.hasError || !root.timetable.length || Date.now() - root.lastUpdated > root.staleAfter)
            refresh();
    }

    // ISO week, Monday to Sunday, matching the API's year/week parameters
    function isoWeek(date) {
        const day = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        day.setUTCDate(day.getUTCDate() + 4 - (day.getUTCDay() || 7));
        const yearStart = Date.UTC(day.getUTCFullYear(), 0, 1);
        return { year: day.getUTCFullYear(), week: Math.ceil(((day.getTime() - yearStart) / 86400000 + 1) / 7) };
    }

    function weekKey(week, type) {
        return week.year + "-" + week.week + ":" + type;
    }

    function addDays(date, days) {
        const result = new Date(date.getTime());
        result.setDate(result.getDate() + days);
        return result;
    }

    // Cached { key: { time, data } } for this and next week
    function applyCachedWeeks(saved) {
        const keys = [currentWeekKey(), nextWeekKey()];
        const current = saved?.[keys[0]];
        if (!current || !Array.isArray(current.data) || current.time <= root.lastUpdated)
            return;
        for (const key of keys) {
            if (saved[key] && Array.isArray(saved[key].data) && !root.weeks[key]?.data)
                storeWeek(key, { time: saved[key].time, data: saved[key].data });
        }
        root.lastUpdated = current.time;
        publishWeeks();
        timetableUpdated(true);
    }

    function cachedWeeks() {
        const result = {};
        for (const key of [currentWeekKey(), nextWeekKey()]) {
            const entry = root.weeks[key];
            if (entry?.data)
                result[key] = { time: entry.time, data: entry.data };
        }
        return result;
    }

    // Day the shell's calendar starts its week on, as Date.getDay()
    function weekStartDay() {
        const setting = SettingsData.firstDayOfWeek;
        return (setting < 0 || setting >= 7 ? Qt.locale().firstDayOfWeek : setting) % 7;
    }

    function viewWeekStart(offset) {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        return addDays(today, -((today.getDay() - weekStartDay() + 7) % 7) + offset * 7);
    }

    // A shown week that doesn't start on Monday spans two API weeks
    function weeksCovering(start) {
        const first = isoWeek(start);
        const last = isoWeek(addDays(start, 6));
        return first.week === last.week && first.year === last.year ? [first] : [first, last];
    }

    function viewEntries(start, type) {
        const end = addDays(start, 7).getTime();
        let list = [];
        for (const week of weeksCovering(start))
            list = list.concat(weekData(week, type));
        return list.filter(anime => {
            const date = parseDate(anime.episodeDate);
            return date && date.getTime() >= start.getTime() && date.getTime() < end;
        }).sort((a, b) => parseDate(a.episodeDate) - parseDate(b.episodeDate));
    }

    // With airType "all" the same episode comes as sub, dub and raw; keep one, preferring sub
    function oneTypePerEpisode(list) {
        if (root.timetableType !== "all")
            return list;
        const rank = { sub: 0, dub: 1, raw: 2 };
        const best = {};
        for (const anime of list) {
            const key = anime.route + ":" + anime.episodeNumber;
            if (!best[key] || (rank[anime.airType] ?? 3) < (rank[best[key].airType] ?? 3))
                best[key] = anime;
        }
        return list.filter(anime => best[anime.route + ":" + anime.episodeNumber] === anime);
    }

    function isDelayed(anime) {
        if (!anime)
            return false;
        const until = parseDate(anime.delayedUntil);
        return anime.airingStatus === "delayed-air" || (!!until && until.getTime() > Date.now());
    }

    function episodeLabel(episode, total) {
        if (!(episode > 0))
            return "";
        if (total > 0)
            return I18n.trFor("animeCalendar", "Ep %1 / %2").arg(episode).arg(total);
        return I18n.trFor("animeCalendar", "Ep %1").arg(episode);
    }

    function airTypeLabel(type) {
        switch (type) {
        case "sub":
            return I18n.trFor("animeCalendar", "Sub");
        case "dub":
            return I18n.trFor("animeCalendar", "Dub");
        case "raw":
            return I18n.trFor("animeCalendar", "Raw");
        }
        return "";
    }

    function forceRefresh() {
        root.lastFetchTime = 0;
        refresh();
    }

    function handleSuccess() {
        root.retryAttempts = 0;
        root.hasError = false;
        root.errorMessage = "";
        if (updateTimer.interval !== root.updateInterval) {
            updateTimer.interval = root.updateInterval;
        }
    }

    function handleFailure(message) {
        root.retryAttempts++;
        root.hasError = true;
        root.errorMessage = message || I18n.trFor("animeCalendar", "Failed to fetch data");
        root.isLoading = false;

        if (root.retryAttempts < root.maxRetryAttempts) {
            retryTimer.start();
        } else {
            root.retryAttempts = 0;
            errorOccurred(root.errorMessage);
        }
    }

    function parseDate(dateString) {
        if (!dateString || dateString === "0001-01-01T00:00:00Z") {
            return null;
        }
        return new Date(dateString);
    }

    function formatTime(date) {
        if (!date) return "--:--";
        return date.toLocaleTimeString(Qt.locale(), "HH:mm");
    }

    function formatDate(date) {
        if (!date) return "--";
        return date.toLocaleDateString(Qt.locale(), "ddd, MMM d");
    }

    function isToday(date) {
        if (!date) return false;
        const today = new Date();
        return date.getFullYear() === today.getFullYear() &&
               date.getMonth() === today.getMonth() &&
               date.getDate() === today.getDate();
    }

    function hasAired(date) {
        return !!date && date.getTime() < Date.now();
    }

    function getTimeUntil(date) {
        if (!date) return "";
        const now = new Date();
        const diff = date.getTime() - now.getTime();

        if (diff < 0) return I18n.trFor("animeCalendar", "Aired");

        const hours = Math.floor(diff / (1000 * 60 * 60));
        const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));

        if (hours > 24) {
            const days = Math.floor(hours / 24);
            return I18n.trFor("animeCalendar", "%1d %2h").arg(days).arg(hours % 24);
        }
        if (hours > 0) {
            return I18n.trFor("animeCalendar", "%1h %2m").arg(hours).arg(minutes);
        }
        return I18n.trFor("animeCalendar", "%1m").arg(minutes);
    }

    function getImageUrl(route) {
        if (!route) return "";
        return "https://img.animeschedule.net/production/assets/public/img/" + route;
    }

    function isInWatchlist(anime) {
        if (!anime || !anime.route)
            return false;
        return root.watchlist.some(entry => entry.route === anime.route);
    }

    function watchlistEntry(anime) {
        return {
            route: anime.route,
            title: anime.title || "",
            english: anime.english || "",
            romaji: anime.romaji || "",
            native: anime.native || "",
            image: anime.imageVersionRoute || "",
            episodes: Number(anime.episodes) || 0,
            finished: false
        };
    }

    function toggleWatchlist(anime) {
        if (!anime || !anime.route)
            return;
        if (isInWatchlist(anime))
            root.watchlist = root.watchlist.filter(entry => entry.route !== anime.route);
        else
            root.watchlist = root.watchlist.concat([watchlistEntry(anime)]);
        updateWatchlistToday();
        watchlistModified();
    }

    // Versions before 2.1 stored bare route strings
    function setWatchlist(list) {
        const seen = {};
        const entries = [];
        for (const item of list || []) {
            const entry = typeof item === "string" ? { route: item } : item;
            if (!entry || typeof entry.route !== "string" || !entry.route || seen[entry.route])
                continue;
            seen[entry.route] = true;
            entries.push(entry);
        }
        root.watchlist = entries;
        updateWatchlistToday();
    }

    function detailsEntry(details) {
        const names = details.names || {};
        return {
            route: details.route,
            title: details.title || "",
            english: names.english || "",
            romaji: names.romaji || "",
            native: names.native || "",
            image: details.imageVersionRoute || "",
            episodes: Number(details.episodes) || 0,
            finished: details.status === "Finished",
            checked: Date.now()
        };
    }

    function updateWatchlistEntries(updates) {
        if (!updates.length)
            return;
        const byRoute = {};
        for (const update of updates)
            byRoute[update.route] = update;
        root.watchlist = root.watchlist.map(entry => byRoute[entry.route] ? Object.assign({}, entry, byRoute[entry.route]) : entry);
        watchlistModified();
    }

    function clearFinished() {
        const finished = root.watchlistRows.filter(row => row.state === "finished").map(row => row.entry.route);
        if (!finished.length)
            return;
        root.watchlist = root.watchlist.filter(entry => finished.indexOf(entry.route) === -1);
        updateWatchlistToday();
        watchlistModified();
    }

    function displayTitle(entry, anime) {
        return entry?.title || anime?.title || entry?.route || anime?.route || I18n.trFor("animeCalendar", "Unknown");
    }

    // One row per starred show; state is "upcoming", "finished" or "notAiring" (nothing scheduled this or next week)
    readonly property var watchlistRows: {
        const now = Date.now();
        const byRoute = {};
        for (const anime of oneTypePerEpisode(root.timetable.concat(root.nextTimetable)))
            (byRoute[anime.route] = byRoute[anime.route] || []).push(anime);
        const rank = { upcoming: 0, notAiring: 1, finished: 2 };
        const rows = root.watchlist.map(entry => {
            const list = (byRoute[entry.route] || []).slice().sort((a, b) => parseDate(a.episodeDate) - parseDate(b.episodeDate));
            const upcoming = list.find(anime => parseDate(anime.episodeDate)?.getTime() >= now);
            if (upcoming)
                return { entry: entry, anime: upcoming, state: "upcoming", date: parseDate(upcoming.episodeDate), episode: Number(upcoming.episodeNumber) || 0 };
            const latest = list[list.length - 1] || null;
            const total = Number(latest?.episodes) || entry.episodes || 0;
            const finished = entry.finished || (!!latest && total > 0 && Number(latest.episodeNumber) >= total);
            return { entry: entry, anime: latest, state: finished ? "finished" : "notAiring", date: null, episode: 0 };
        });
        return rows.sort((a, b) => {
            if (a.state !== b.state)
                return rank[a.state] - rank[b.state];
            if (a.date && b.date && a.date.getTime() !== b.date.getTime())
                return a.date.getTime() - b.date.getTime();
            return displayTitle(a.entry, a.anime).localeCompare(displayTitle(b.entry, b.anime));
        });
    }

    function updateWatchlistToday() {
        const result = oneTypePerEpisode(root.timetable).filter(anime => isToday(parseDate(anime.episodeDate)) && isInWatchlist(anime));
        result.sort((a, b) => parseDate(a.episodeDate) - parseDate(b.episodeDate));
        root.watchlistTodayAnime = result;
        root.watchlistTodayCount = result.length;
    }

    Process {
        id: requester
        stdinEnabled: true

        onStarted: {
            write("Authorization: Bearer " + root.apiToken + "\n");
            stdinEnabled = false;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root._active)
                    return;
                root._active.body = text;
                root._maybeFinish();
            }
        }

        onExited: exitCode => {
            if (!root._active)
                return;
            root._active.exitCode = exitCode;
            root._active.exited = true;
            root._maybeFinish();
        }
    }

    Timer {
        id: updateTimer
        interval: root.updateInterval
        running: root.apiToken !== ""
        repeat: true
        onTriggered: {
            root.refresh();
        }
    }

    Timer {
        id: retryTimer
        interval: root.retryDelay
        onTriggered: root.forceRefresh()
    }

    Process {
        id: tokenFileLoader
        running: false
        command: ["cat", root.apiTokenPath]

        stdout: StdioCollector {
            onStreamFinished: {
                const trimmed = (text || "").trim();
                if (trimmed !== root._tokenFromFile) {
                    root._tokenFromFile = trimmed;
                    root.refreshIfStale();
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.hasError = true;
                root.errorMessage = I18n.trFor("animeCalendar", "Failed to read API token file: %1").arg(root.apiTokenPath);
                root._tokenFromFile = "";
            }
        }
    }
}
