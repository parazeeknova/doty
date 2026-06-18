import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property string homeDir: Quickshell.env("HOME")
    property var apps: []
    property var mostUsed: []
    property var webHistory: []
    property var fileHistory: []
    property var filteredApps: []
    property var activeWindows: []
    property int selectedActiveWindowIndex: -1
    property var appDisplayList: []
    property var webSearchDisplayList: []
    property var fileSearchDisplayList: []
    property var gitRepos: []
    property var gitRepoSearchResults: []
    property var bookmarks: []
    property var bookmarkDisplayList: []
    property bool isWebSearchMode: root.activeTab === 1 || searchQuery.trim().startsWith("!")
    property bool isFileSearchMode: root.activeTab === 2 || searchQuery.trim().startsWith("@")
    property bool isGitRepoMode: root.activeTab === 3 || searchQuery.trim().startsWith("#")
    property bool isBookmarkMode: root.activeTab === 4 || searchQuery.trim().startsWith("~")
    property string searchQuery: ""
    property int selectedIndex: 0
    property int activeTab: 0
    property string fileSearchQuery: ""
    property string rawSearchQuery: ""
    readonly property string fontName: "FiraCode Nerd Font"

    signal requestClose()
    signal resetSearchInput(string text)

    function filterApps() {
        if (searchQuery.trim() === "") {
            filteredApps = apps;
        } else {
            var temp = [];
            var query = searchQuery.toLowerCase();
            for (var i = 0; i < apps.length; i++) {
                var app = apps[i];
                if (app.name.toLowerCase().indexOf(query) !== -1 || app.exec.toLowerCase().indexOf(query) !== -1)
                    temp.push(app);

            }
            filteredApps = temp;
        }
        rebuildDisplayList();
    }

    function parseWebSearch(query) {
        var q = query.trim();
        if (!q.startsWith("!"))
            return null;

        var firstSpace = q.indexOf(" ");
        var trigger = "";
        var searchText = "";
        if (firstSpace === -1) {
            // No space yet, e.g. "!yt" or "!hello"
            trigger = q.toLowerCase();
            searchText = "";
        } else {
            trigger = q.substring(0, firstSpace).toLowerCase();
            searchText = q.substring(firstSpace + 1).trim();
        }
        var engineName = "duckduckgo";
        var searchUrl = "https://duckduckgo.com/?q=";
        if (trigger === "!yt" || trigger === "!youtube") {
            engineName = "youtube";
            searchUrl = "https://www.youtube.com/results?search_query=";
        } else if (trigger === "!g" || trigger === "!google") {
            engineName = "google";
            searchUrl = "https://www.google.com/search?q=";
        } else if (trigger === "!gh" || trigger === "!github") {
            engineName = "github";
            searchUrl = "https://github.com/search?q=";
        } else if (trigger === "!w" || trigger === "!wiki" || trigger === "!wikipedia") {
            engineName = "wikipedia";
            searchUrl = "https://en.wikipedia.org/wiki/Special:Search?search=";
        } else {
            // Not a registered engine, treat the whole string after "!" as query, or if it has trigger, check
            engineName = "duckduckgo";
            searchUrl = "https://duckduckgo.com/?q=";
            if (firstSpace === -1)
                searchText = q.substring(1);
            else
                searchText = q.substring(1); // e.g. "!hello world" -> query is "hello world"
        }
        return {
            "engine": engineName,
            "url": searchUrl + encodeURIComponent(searchText),
            "query": searchText
        };
    }

    function getTriggerForEngine(engine) {
        if (engine === "youtube")
            return "!yt";

        if (engine === "google")
            return "!g";

        if (engine === "github")
            return "!gh";

        if (engine === "wikipedia")
            return "!w";

        return "!";
    }

    function getReconstructedQuery(item) {
        if (!item || item.type !== "web_search")
            return "";

        if (item.is_history) {
            var trigger = root.getTriggerForEngine(item.engine);
            if (trigger === "!")
                return "!" + item.query;
            else
                return trigger + " " + item.query;
        } else {
            return root.searchQuery;
        }
    }

    function launchWebSearch(query) {
        if (!query)
            return ;

        var q = query.trim();
        if (q === "!" || q === "!yt" || q === "!youtube" || q === "!g" || q === "!google" || q === "!gh" || q === "!github" || q === "!w" || q === "!wiki" || q === "!wikipedia")
            return ;

        var searchQuery = q.startsWith("!") ? q : "!" + q;
        Quickshell.execDetached([root.homeDir + "/.config/quickshell/apps_popup/get_apps_list", "--web-search", searchQuery]);
        root.requestClose();
    }

    function launchFile(path) {
        if (!path)
            return ;

        Quickshell.execDetached([root.homeDir + "/.config/quickshell/apps_popup/get_apps_list", "--open-file", path]);
        root.requestClose();
    }

    function launchGitRepo(url) {
        if (!url)
            return ;

        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({workspace=1})"]);
        Quickshell.execDetached(["xdg-open", url]);
        root.requestClose();
    }

    function launchBookmark(url) {
        if (!url)
            return ;

        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({workspace=1})"]);
        Quickshell.execDetached(["xdg-open", url]);
        root.requestClose();
    }

    function saveBookmark(url) {
        if (!url)
            return ;

        var originalUrl = url;
        if (root.rawSearchQuery.trim().startsWith("~")) {
            var inputUrl = root.rawSearchQuery.trim().substring(1).trim();
            if (inputUrl.toLowerCase() === url.toLowerCase())
                originalUrl = inputUrl;

        }
        addBookmarkProc.running = false;
        addBookmarkProc.command = [root.homeDir + "/.config/quickshell/apps_popup/get_apps_list", "--add-bookmark", originalUrl];
        addBookmarkProc.running = true;
    }

    function deleteBookmark(url) {
        if (!url)
            return ;

        deleteBookmarkProc.running = false;
        deleteBookmarkProc.command = [root.homeDir + "/.config/quickshell/apps_popup/get_apps_list", "--delete-bookmark", url];
        deleteBookmarkProc.running = true;
    }

    function getActiveDisplayList() {
        if (root.isBookmarkMode)
            return root.bookmarkDisplayList;
        else if (root.isGitRepoMode)
            return root.gitRepoSearchResults;
        else if (root.isFileSearchMode)
            return root.fileSearchDisplayList;
        else if (root.isWebSearchMode)
            return root.webSearchDisplayList;
        else
            return root.appDisplayList;
    }

    function rebuildDisplayList() {
        var list = [];
        var query = root.searchQuery.trim();
        if (root.activeTab === 4 || query.startsWith("~")) {
            var bookmarkQuery = query.startsWith("~") ? query.substring(1).trim() : query;
            var matching = [];
            for (var idx = 0; idx < root.bookmarks.length; idx++) {
                var bm = root.bookmarks[idx];
                if (bookmarkQuery === "" || bm.url.toLowerCase().indexOf(bookmarkQuery) !== -1 || bm.name.toLowerCase().indexOf(bookmarkQuery) !== -1)
                    matching.push(bm);

            }
            if (matching.length > 0) {
                list.push({
                    "type": "header",
                    "name": "saved bookmarks"
                });
                for (var i = 0; i < matching.length; i++) {
                    list.push({
                        "type": "bookmark",
                        "data": matching[i]
                    });
                }
            }
            if (bookmarkQuery !== "") {
                var alreadyBookmarked = false;
                for (var i = 0; i < root.bookmarks.length; i++) {
                    var normUrl = bookmarkQuery.toLowerCase();
                    if (!normUrl.includes("://"))
                        normUrl = "https://" + normUrl;

                    if (root.bookmarks[i].url.toLowerCase() === normUrl) {
                        alreadyBookmarked = true;
                        break;
                    }
                }
                if (!alreadyBookmarked)
                    list.unshift({
                    "type": "add_bookmark",
                    "url": bookmarkQuery
                });

            } else if (matching.length === 0) {
                list.push({
                    "type": "header",
                    "name": "type a URL to bookmark..."
                });
            }
            root.bookmarkDisplayList = list;
        } else if (root.activeTab === 1 || query.startsWith("!")) {
            if (query === "" || query === "!") {
                if (root.webHistory.length > 0) {
                    for (var i = 0; i < root.webHistory.length; i++) {
                        var item = root.webHistory[i];
                        list.push({
                            "type": "web_search",
                            "engine": item.engine,
                            "url": item.url,
                            "query": item.query,
                            "is_history": true
                        });
                    }
                } else {
                    list.push({
                        "type": "web_search",
                        "engine": "duckduckgo",
                        "url": "",
                        "query": "",
                        "is_history": false
                    });
                }
            } else {
                var webSearch = null;
                if (query.startsWith("!"))
                    webSearch = root.parseWebSearch(root.searchQuery);
                else if (root.activeTab === 1 && query !== "")
                    webSearch = {
                    "engine": "duckduckgo",
                    "url": "https://duckduckgo.com/?q=" + encodeURIComponent(query),
                    "query": query
                };
                if (webSearch) {
                    list.push({
                        "type": "web_search",
                        "engine": webSearch.engine,
                        "url": webSearch.url,
                        "query": webSearch.query,
                        "is_history": false
                    });
                } else {
                    var triggerName = query.toLowerCase();
                    var engine = "duckduckgo";
                    if (triggerName === "!yt" || triggerName === "!youtube")
                        engine = "youtube";
                    else if (triggerName === "!g" || triggerName === "!google")
                        engine = "google";
                    else if (triggerName === "!gh" || triggerName === "!github")
                        engine = "github";
                    else if (triggerName === "!w" || triggerName === "!wiki" || triggerName === "!wikipedia")
                        engine = "wikipedia";
                    list.push({
                        "type": "web_search",
                        "engine": engine,
                        "url": "",
                        "query": "",
                        "is_history": false
                    });
                }
            }
            root.webSearchDisplayList = list;
        } else if (root.activeTab === 2 || query.startsWith("@")) {
            var fileQuery = query.startsWith("@") ? query.substring(1).trim() : query;
            if (fileQuery === "") {
                if (root.fileHistory.length > 0) {
                    list.push({
                        "type": "header",
                        "name": "recent files"
                    });
                    for (var i = 0; i < root.fileHistory.length; i++) {
                        var item = root.fileHistory[i];
                        list.push({
                            "type": "file",
                            "data": item
                        });
                    }
                } else {
                    list.push({
                        "type": "header",
                        "name": "type to search files..."
                    });
                }
                root.fileSearchDisplayList = list;
            } else {
                fileSearchDebounce.restart();
            }
        } else if (query.startsWith("#")) {
            var gitQuery = query.substring(1).trim();
            if (gitQuery === "") {
                if (root.gitRepos.length > 0) {
                    list.push({
                        "type": "header",
                        "name": "your repos"
                    });
                    for (var i = 0; i < root.gitRepos.length; i++) {
                        var repo = root.gitRepos[i];
                        list.push({
                            "type": "git_repo",
                            "data": repo
                        });
                    }
                } else {
                    list.push({
                        "type": "header",
                        "name": "type to search repos..."
                    });
                }
                root.gitRepoSearchResults = list;
            } else {
                gitRepoSearchDebounce.restart();
            }
        } else {
            if (root.searchQuery.trim() === "") {
                if (root.mostUsed.length > 0) {
                    list.push({
                        "type": "header",
                        "name": "most used"
                    });
                    for (var i = 0; i < root.mostUsed.length; i++) {
                        list.push({
                            "type": "app",
                            "data": root.mostUsed[i]
                        });
                    }
                    list.push({
                        "type": "separator"
                    });
                }
                for (var j = 0; j < filteredApps.length; j++) {
                    list.push({
                        "type": "app",
                        "data": filteredApps[j]
                    });
                }
            } else {
                for (var k = 0; k < filteredApps.length; k++) {
                    list.push({
                        "type": "app",
                        "data": filteredApps[k]
                    });
                }
            }
            root.appDisplayList = list;
        }
        selectFirstApp();
    }

    function selectFirstApp() {
        var list = root.getActiveDisplayList();
        for (var i = 0; i < list.length; i++) {
            if (list[i].type === "app" || list[i].type === "web_search" || list[i].type === "file" || list[i].type === "git_repo" || list[i].type === "bookmark" || list[i].type === "add_bookmark") {
                root.selectedIndex = i;
                break;
            }
        }
    }

    function selectNext() {
        var list = root.getActiveDisplayList();
        var idx = root.selectedIndex;
        while (idx < list.length - 1) {
            idx++;
            if (list[idx].type === "app" || list[idx].type === "web_search" || list[idx].type === "file" || list[idx].type === "git_repo" || list[idx].type === "bookmark" || list[idx].type === "add_bookmark") {
                root.selectedIndex = idx;
                break;
            }
        }
    }

    function selectPrev() {
        var list = root.getActiveDisplayList();
        var idx = root.selectedIndex;
        while (idx > 0) {
            idx--;
            if (list[idx].type === "app" || list[idx].type === "web_search" || list[idx].type === "file" || list[idx].type === "git_repo" || list[idx].type === "bookmark" || list[idx].type === "add_bookmark") {
                root.selectedIndex = idx;
                break;
            }
        }
    }

    function launchApp(appName, execCmd) {
        Quickshell.execDetached([root.homeDir + "/.config/quickshell/apps_popup/get_apps_list", "--launch", appName]);
        Quickshell.execDetached(["sh", "-c", execCmd + " &"]);
        root.requestClose();
    }

    function focusWorkspaceAndClose(wsId) {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({workspace=" + wsId + "})"]);
        root.requestClose();
    }

    function normalizeAddress(address) {
        if (!address)
            return "";

        var addressString = String(address).toLowerCase();
        if (!addressString.startsWith("0x"))
            addressString = "0x" + addressString;

        return addressString;
    }

    function getToplevelForAddress(address) {
        const values = ToplevelManager.toplevels.values;
        const targetAddr = root.normalizeAddress(address);
        for (var i = 0; i < values.length; i++) {
            const tl = values[i];
            if (tl.HyprlandToplevel) {
                var tlAddr = tl.HyprlandToplevel.address;
                var tlAddrStr = "";
                if (typeof tlAddr === "number") {
                    tlAddrStr = "0x" + tlAddr.toString(16);
                } else {
                    tlAddrStr = String(tlAddr).toLowerCase();
                    if (!tlAddrStr.startsWith("0x"))
                        tlAddrStr = "0x" + tlAddrStr;

                }
                if (tlAddrStr === targetAddr)
                    return tl;

            }
        }
        return null;
    }

    function iconExists(iconName) {
        if (!iconName)
            return false;

        var path = Quickshell.iconPath(iconName, true);
        return path && path.length > 0 && !String(path).includes("image-missing");
    }

    function iconFromString(value) {
        if (!value)
            return "";

        var name = String(value);
        var entry = DesktopEntries.byId(name);
        if (entry && entry.icon && root.iconExists(entry.icon))
            return entry.icon;

        var substitutions = {
            "code": "visual-studio-code",
            "code-url-handler": "visual-studio-code",
            "code-insiders": "visual-studio-code-insiders",
            "codium": "vscodium",
            "footclient": "foot",
            "ghostty": "com.mitchellh.ghostty",
            "google-chrome": "google-chrome",
            "kitty": "kitty",
            "org.wezfurlong.wezterm": "org.wezfurlong.wezterm",
            "steam": "steam",
            "thunar": "org.xfce.thunar",
            "vesktop": "vesktop",
            "wezterm": "org.wezfurlong.wezterm",
            "zen": "zen-browser"
        };
        var lower = name.toLowerCase();
        if (substitutions[name] && root.iconExists(substitutions[name]))
            return substitutions[name];

        if (substitutions[lower] && root.iconExists(substitutions[lower]))
            return substitutions[lower];

        if (root.iconExists(name))
            return name;

        if (root.iconExists(lower))
            return lower;

        var lastDomainPart = name.split(".").pop();
        if (root.iconExists(lastDomainPart))
            return lastDomainPart;

        if (root.iconExists(lastDomainPart.toLowerCase()))
            return lastDomainPart.toLowerCase();

        var kebab = lower.replace(/\s+/g, "-").replace(/_/g, "-");
        if (root.iconExists(kebab))
            return kebab;

        var heuristicEntry = DesktopEntries.heuristicLookup(name);
        if (heuristicEntry && heuristicEntry.icon && root.iconExists(heuristicEntry.icon))
            return heuristicEntry.icon;

        return "";
    }

    function getWindowIconPath(win) {
        var candidates = [win ? win.class : "", win ? win.initialClass : "", win ? win.initialTitle : "", win ? win.title : ""];
        for (var i = 0; i < candidates.length; i++) {
            var iconName = root.iconFromString(candidates[i]);
            if (iconName) {
                if (iconName.startsWith("/"))
                    return "file://" + iconName;

                return "image://icon/" + iconName;
            }
        }
        return "image://icon/application-x-executable";
    }

    Component.onCompleted: {
        getAppsProc.running = true;
        getRecentsProc.running = true;
        gitRepoListProc.running = true;
    }

    Theme {
        id: theme
    }

    IpcHandler {
        function close() {
            root.requestClose();
        }

        target: "apps_popup"
    }

    Process {
        id: getAppsProc

        command: [root.homeDir + "/.config/quickshell/apps_popup/get_apps_list"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.mostUsed = data.most_used || [];
                    root.apps = data.all_apps || [];
                    root.webHistory = data.web_history || [];
                    root.fileHistory = data.file_history || [];
                    root.bookmarks = data.bookmarks || [];
                    root.filterApps();
                } catch (e) {
                    console.log("Failed to parse apps: " + e);
                }
            }
        }

    }

    Process {
        id: addBookmarkProc

        command: [root.homeDir + "/.config/quickshell/apps_popup/get_apps_list", "--add-bookmark", ""]
        running: false
        onRunningChanged: {
            if (!running) {
                getAppsProc.running = false;
                getAppsProc.running = true;
                root.searchQuery = "~";
                root.resetSearchInput("~");
            }
        }
    }

    Process {
        id: deleteBookmarkProc

        command: [root.homeDir + "/.config/quickshell/apps_popup/get_apps_list", "--delete-bookmark", ""]
        running: false
        onRunningChanged: {
            if (!running) {
                getAppsProc.running = false;
                getAppsProc.running = true;
            }
        }
    }

    Process {
        id: clearBookmarksProc

        command: [root.homeDir + "/.config/quickshell/apps_popup/get_apps_list", "--clear-bookmarks"]
        running: false
        onRunningChanged: {
            if (!running) {
                root.bookmarks = [];
                rebuildDisplayList();
            }
        }
    }

    Process {
        id: clearHistoryProc

        command: [root.homeDir + "/.config/quickshell/apps_popup/get_apps_list", "--clear-history"]
        running: false
        onRunningChanged: {
            if (!running)
                root.webHistory = [];

        }
    }

    Process {
        id: clearFileHistoryProc

        command: [root.homeDir + "/.config/quickshell/apps_popup/get_apps_list", "--clear-file-history"]
        running: false
        onRunningChanged: {
            if (!running) {
                root.fileHistory = [];
                rebuildDisplayList();
            }
        }
    }

    Process {
        id: fileSearchProc

        command: [root.homeDir + "/.config/quickshell/apps_popup/get_apps_list", "--search-files", ""]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var results = JSON.parse(this.text);
                    var list = [];
                    for (var i = 0; i < results.length; i++) {
                        list.push({
                            "type": "file",
                            "data": results[i]
                        });
                    }
                    root.fileSearchDisplayList = list;
                    root.selectedIndex = 0;
                } catch (e) {
                    console.log("Failed to parse file search: " + e);
                }
            }
        }

    }

    Process {
        id: getRecentsProc

        command: [root.homeDir + "/.config/quickshell/recents_popup/get_recents_list"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.activeWindows = data.clients || [];
                } catch (e) {
                    console.log("Failed to parse recents in apps_popup: " + e);
                }
            }
        }

    }

    Timer {
        id: searchDebounce

        interval: 150
        repeat: false
        onTriggered: root.filterApps()
    }

    Timer {
        id: fileSearchDebounce

        interval: 200
        repeat: false
        onTriggered: {
            var query = root.searchQuery.trim();
            var fileQuery = query.startsWith("@") ? query.substring(1).trim() : query;
            if (fileQuery !== "") {
                fileSearchProc.command = [root.homeDir + "/.config/quickshell/apps_popup/get_apps_list", "--search-files", fileQuery];
                fileSearchProc.running = true;
            }
        }
    }

    Timer {
        id: gitRepoSearchDebounce

        interval: 400
        repeat: false
        onTriggered: {
            var query = root.searchQuery.trim();
            var gitQuery = query.startsWith("#") ? query.substring(1).trim() : query;
            if (gitQuery !== "") {
                gitRepoSearchProc.running = false;
                gitRepoSearchProc.command = [root.homeDir + "/.config/quickshell/apps_popup/get_github_repos", "--search-repos", gitQuery];
                gitRepoSearchProc.running = true;
            } else {
                root.gitRepoSearchResults = [];
            }
        }
    }

    Process {
        id: gitRepoListProc

        command: [root.homeDir + "/.config/quickshell/apps_popup/get_github_repos", "--list-repos"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.gitRepos = JSON.parse(this.text) || [];
                } catch (e) {
                    console.log("Failed to parse git repos: " + e);
                }
            }
        }

    }

    Process {
        id: gitRepoRefreshProc

        command: [root.homeDir + "/.config/quickshell/apps_popup/get_github_repos", "--refresh-repos"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.gitRepos = JSON.parse(this.text) || [];
                } catch (e) {
                    console.log("Failed to parse git repos: " + e);
                }
            }
        }

    }

    Process {
        id: gitRepoSearchProc

        command: [root.homeDir + "/.config/quickshell/apps_popup/get_github_repos", "--search-repos", ""]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var results = JSON.parse(this.text) || [];
                    var list = [];
                    for (var i = 0; i < results.length; i++) {
                        list.push({
                            "type": "git_repo",
                            "data": results[i]
                        });
                    }
                    root.gitRepoSearchResults = list;
                    root.selectedIndex = 0;
                } catch (e) {
                    console.log("Failed to parse git repo search: " + e);
                }
            }
        }

    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win

                required property var modelData
                property bool isClosing: false
                property real animOpacity: 0
                property real animOffsetY: -20

                function closePopup() {
                    if (isClosing)
                        return ;

                    isClosing = true;
                    exitAnim.start();
                }

                screen: modelData
                WlrLayershell.namespace: "quickshell"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                color: "transparent"
                implicitWidth: 240
                implicitHeight: {
                    var spacingAndStatic = activeWindowsArea.visible ? 94 : 52;
                    var contentH = 0;
                    if (root.isBookmarkMode)
                        contentH = bookmarkList ? bookmarkList.contentHeight : 0;
                    else if (root.isGitRepoMode)
                        contentH = gitRepoList ? gitRepoList.contentHeight : 0;
                    else if (root.isFileSearchMode)
                        contentH = fileSearchList ? fileSearchList.contentHeight : 0;
                    else if (root.isWebSearchMode)
                        contentH = webSearchList ? webSearchList.contentHeight : 0;
                    else
                        contentH = appsList ? appsList.contentHeight : 0;
                    return Math.min(320, spacingAndStatic + Math.max(48, contentH) + bottomRow.implicitHeight);
                }
                Component.onCompleted: {
                    introAnim.start();
                    searchInput.forceActiveFocus();
                }

                Connections {
                    function onRequestClose() {
                        win.closePopup();
                    }

                    target: root
                }

                anchors {
                    top: true
                    left: true
                }

                margins {
                    top: 4
                    left: 32
                }

                ParallelAnimation {
                    id: introAnim

                    NumberAnimation {
                        target: win
                        property: "animOpacity"
                        from: 0
                        to: 1
                        duration: 150
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: win
                        property: "animOffsetY"
                        from: -20
                        to: 0
                        duration: 180
                        easing.type: Easing.OutExpo
                    }

                }

                ParallelAnimation {
                    id: exitAnim

                    onStopped: Qt.quit()

                    NumberAnimation {
                        target: win
                        property: "animOpacity"
                        from: 1
                        to: 0
                        duration: 120
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: win
                        property: "animOffsetY"
                        from: 0
                        to: -20
                        duration: 120
                        easing.type: Easing.OutCubic
                    }

                }

                HyprlandFocusGrab {
                    active: !win.isClosing
                    windows: [win]
                    onCleared: {
                        console.log("apps_popup: focus grab cleared, closing popup");
                        win.closePopup();
                    }
                }

                Rectangle {
                    id: mainContainer

                    anchors.fill: parent
                    opacity: win.animOpacity
                    y: win.animOffsetY
                    color: theme.popupBgColor
                    border.width: 1
                    border.color: theme.accent
                    radius: 0
                    focus: true
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            win.closePopup();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Tab) {
                            root.activeTab = (root.activeTab + 1) % 5;
                            if (root.activeTab === 1) {
                                root.searchQuery = "!";
                                searchInput.text = "!";
                            } else if (root.activeTab === 2) {
                                root.searchQuery = "@";
                                searchInput.text = "@";
                            } else if (root.activeTab === 3) {
                                root.searchQuery = "#";
                                searchInput.text = "#";
                            } else if (root.activeTab === 4) {
                                root.searchQuery = "~";
                                searchInput.text = "~";
                            } else {
                                root.searchQuery = "";
                                searchInput.text = "";
                            }
                            root.selectedIndex = 0;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Shift) {
                            if (root.activeWindows.length > 0) {
                                root.selectedActiveWindowIndex++;
                                if (root.selectedActiveWindowIndex >= root.activeWindows.length)
                                    root.selectedActiveWindowIndex = -1;

                                if (root.selectedActiveWindowIndex >= 0)
                                    activeWindowsList.positionViewAtIndex(root.selectedActiveWindowIndex, ListView.Contain);

                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            root.selectedActiveWindowIndex = -1;
                            root.selectPrev();
                            var activeList = root.isBookmarkMode ? bookmarkList : (root.isGitRepoMode ? gitRepoList : (root.isFileSearchMode ? fileSearchList : (root.isWebSearchMode ? webSearchList : appsList)));
                            activeList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            root.selectedActiveWindowIndex = -1;
                            root.selectNext();
                            var activeList = root.isBookmarkMode ? bookmarkList : (root.isGitRepoMode ? gitRepoList : (root.isFileSearchMode ? fileSearchList : (root.isWebSearchMode ? webSearchList : appsList)));
                            activeList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            event.accepted = true;
                        } else if (((event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) && (event.modifiers & Qt.ShiftModifier)) || (event.key === Qt.Key_Delete)) {
                            var list = root.getActiveDisplayList();
                            if (list.length > 0 && list[root.selectedIndex]) {
                                var selected = list[root.selectedIndex];
                                if (selected.type === "bookmark") {
                                    root.deleteBookmark(selected.data.url);
                                    event.accepted = true;
                                }
                            }
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.selectedActiveWindowIndex >= 0) {
                                root.focusWorkspaceAndClose(root.activeWindows[root.selectedActiveWindowIndex].workspace_id);
                            } else {
                                var currentText = searchInput.text.trim();
                                var list = root.getActiveDisplayList();
                                if (list.length > 0 && list[root.selectedIndex]) {
                                    var selected = list[root.selectedIndex];
                                    var isStaleBookmark = false;
                                    if (currentText.startsWith("~") && selected.type === "bookmark") {
                                        var urlToSave = currentText.substring(1).trim();
                                        var queryLower = urlToSave.toLowerCase();
                                        var bmUrl = (selected.data && selected.data.url) ? selected.data.url.toLowerCase() : "";
                                        var bmName = (selected.data && selected.data.name) ? selected.data.name.toLowerCase() : "";
                                        if (bmUrl.indexOf(queryLower) === -1 && bmName.indexOf(queryLower) === -1)
                                            isStaleBookmark = true;

                                    }
                                    var isStaleWebSearch = false;
                                    if (currentText.startsWith("!") && selected.type === "web_search") {
                                        var webQuery = currentText.substring(1).trim();
                                        var selQuery = selected.query || "";
                                        if (selQuery.toLowerCase() !== webQuery.toLowerCase())
                                            isStaleWebSearch = true;

                                    }
                                    if (currentText.startsWith("~") && (selected.type !== "bookmark" || isStaleBookmark) && selected.type !== "add_bookmark") {
                                        var urlToSave = currentText.substring(1).trim();
                                        if (urlToSave !== "")
                                            root.saveBookmark(urlToSave);

                                    } else if (currentText.startsWith("!") && (selected.type !== "web_search" || isStaleWebSearch)) {
                                        root.launchWebSearch(currentText);
                                    } else {
                                        if (selected.type === "app")
                                            root.launchApp(selected.data.name, selected.data.exec);
                                        else if (selected.type === "web_search")
                                            root.launchWebSearch(root.getReconstructedQuery(selected));
                                        else if (selected.type === "file")
                                            root.launchFile(selected.data.path);
                                        else if (selected.type === "git_repo")
                                            root.launchGitRepo(selected.data.html_url);
                                        else if (selected.type === "bookmark")
                                            root.launchBookmark(selected.data.url);
                                        else if (selected.type === "add_bookmark")
                                            root.saveBookmark(selected.url);
                                    }
                                } else {
                                    if (currentText.startsWith("~")) {
                                        var urlToSave = currentText.substring(1).trim();
                                        if (urlToSave !== "")
                                            root.saveBookmark(urlToSave);

                                    } else if (currentText.startsWith("!")) {
                                        root.launchWebSearch(currentText);
                                    }
                                }
                            }
                            event.accepted = true;
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        // Search Bar (Underline only)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 16
                            color: "transparent"

                            TextInput {
                                id: searchInput

                                anchors.fill: parent
                                anchors.bottomMargin: 2
                                verticalAlignment: TextInput.AlignVCenter
                                color: theme.accent
                                font.family: root.fontName
                                font.pointSize: 8
                                focus: true
                                Keys.forwardTo: [mainContainer]
                                onTextChanged: {
                                    root.rawSearchQuery = text;
                                    root.searchQuery = text.toLowerCase();
                                    searchDebounce.restart();
                                }

                                Connections {
                                    function onResetSearchInput(text) {
                                        searchInput.text = text;
                                    }

                                    target: root
                                }

                                Text {
                                    text: root.activeTab === 0 ? "search applications..." : (root.activeTab === 1 ? "search the web..." : (root.activeTab === 2 ? "search files..." : (root.activeTab === 3 ? "search github repos..." : "search bookmarks...")))
                                    color: theme.secondary
                                    font.family: root.fontName
                                    font.pointSize: 8
                                    visible: searchInput.text === ""
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                }

                            }

                            // Underline
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 1
                                color: searchInput.activeFocus ? theme.accent : theme.secondary

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                        easing.type: Easing.OutQuad
                                    }

                                }

                            }

                        }

                        // Active Windows Horizontal Row
                        Rectangle {
                            id: activeWindowsArea

                            Layout.fillWidth: true
                            height: 38
                            color: "transparent"
                            visible: root.activeWindows.length > 0 && root.searchQuery === ""

                            ListView {
                                id: activeWindowsList

                                anchors.fill: parent
                                orientation: ListView.Horizontal
                                spacing: 6
                                model: root.activeWindows
                                clip: true

                                delegate: Rectangle {
                                    width: 36
                                    height: 36
                                    color: "#161616"
                                    border.width: 1
                                    border.color: (root.selectedActiveWindowIndex === index || activeWinMouseArea.containsMouse) ? theme.accent : theme.bg_light
                                    radius: 0
                                    clip: true
                                    anchors.verticalCenter: parent.verticalCenter

                                    // Draw the window content live
                                    Loader {
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        active: true

                                        sourceComponent: ScreencopyView {
                                            captureSource: root.getToplevelForAddress(modelData.address)
                                            live: true
                                            width: 36
                                            height: 36
                                            constraintSize: Qt.size(width, height)
                                        }

                                    }

                                    // Workspace Badge on Top Right
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 1
                                        color: Qt.rgba(theme.bg.r, theme.bg.g, theme.bg.b, 0.75)
                                        width: workspaceText.implicitWidth + 3
                                        height: 8
                                        radius: 0

                                        Text {
                                            id: workspaceText

                                            anchors.centerIn: parent
                                            text: modelData.workspace_roman
                                            color: theme.accent
                                            font.family: root.fontName
                                            font.pointSize: 4.5
                                            font.bold: true
                                            renderType: Text.NativeRendering
                                        }

                                    }

                                    // App Icon Badge on Bottom Left
                                    Rectangle {
                                        width: 10
                                        height: 10
                                        color: theme.popupBgColor
                                        radius: 0
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.margins: 1

                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            fillMode: Image.PreserveAspectFit
                                            source: root.getWindowIconPath(modelData)
                                        }

                                    }

                                    MouseArea {
                                        id: activeWinMouseArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: {
                                            root.selectedActiveWindowIndex = index;
                                        }
                                        onClicked: {
                                            root.focusWorkspaceAndClose(modelData.workspace_id);
                                        }
                                    }

                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: 150
                                            easing.type: Easing.OutQuad
                                        }

                                    }

                                }

                            }

                        }

                        // Tab Switcher
                        RowLayout {
                            Layout.fillWidth: true
                            height: 14
                            spacing: 0

                            Rectangle {
                                Layout.fillWidth: true
                                height: 14
                                color: "transparent"

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Text {
                                        text: "apps"
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        font.bold: root.activeTab === 0
                                        color: root.activeTab === 0 ? theme.accent : theme.secondary
                                        renderType: Text.NativeRendering

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.activeTab = 0;
                                                root.searchQuery = "";
                                                searchInput.text = "";
                                                root.selectedIndex = 0;
                                            }
                                        }

                                    }

                                    Text {
                                        text: "|"
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        color: theme.secondary
                                        opacity: 0.5
                                        renderType: Text.NativeRendering
                                    }

                                    Text {
                                        text: "web"
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        font.bold: root.activeTab === 1
                                        color: root.activeTab === 1 ? theme.accent : theme.secondary
                                        renderType: Text.NativeRendering

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.activeTab = 1;
                                                root.searchQuery = "!";
                                                searchInput.text = "!";
                                                root.selectedIndex = 0;
                                            }
                                        }

                                    }

                                    Text {
                                        text: "|"
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        color: theme.secondary
                                        opacity: 0.5
                                        renderType: Text.NativeRendering
                                    }

                                    Text {
                                        text: "files"
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        font.bold: root.activeTab === 2
                                        color: root.activeTab === 2 ? theme.accent : theme.secondary
                                        renderType: Text.NativeRendering

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.activeTab = 2;
                                                root.searchQuery = "@";
                                                searchInput.text = "@";
                                                root.selectedIndex = 0;
                                            }
                                        }

                                    }

                                    Text {
                                        text: "|"
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        color: theme.secondary
                                        opacity: 0.5
                                        renderType: Text.NativeRendering
                                    }

                                    Text {
                                        text: "github"
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        font.bold: root.activeTab === 3
                                        color: root.activeTab === 3 ? theme.accent : theme.secondary
                                        renderType: Text.NativeRendering

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.activeTab = 3;
                                                root.searchQuery = "#";
                                                searchInput.text = "#";
                                                root.selectedIndex = 0;
                                            }
                                        }

                                    }

                                    Text {
                                        text: "|"
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        color: theme.secondary
                                        opacity: 0.5
                                        renderType: Text.NativeRendering
                                    }

                                    Text {
                                        text: "bmarks"
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        font.bold: root.activeTab === 4
                                        color: root.activeTab === 4 ? theme.accent : theme.secondary
                                        renderType: Text.NativeRendering

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.activeTab = 4;
                                                root.searchQuery = "~";
                                                searchInput.text = "~";
                                                root.selectedIndex = 0;
                                            }
                                        }

                                    }

                                }

                            }

                        }

                        // List view
                        // Shared list delegate
                        Component {
                            id: listDelegate

                            Rectangle {
                                width: listContainer.width
                                height: modelData.type === "app" ? 16 : (modelData.type === "header" ? 14 : (modelData.type === "separator" ? 5 : (modelData.type === "file" ? 16 : (modelData.type === "bookmark" ? 16 : (modelData.type === "add_bookmark" ? 16 : 16)))))
                                color: ((modelData.type === "app" || modelData.type === "web_search" || modelData.type === "file" || modelData.type === "git_repo" || modelData.type === "bookmark" || modelData.type === "add_bookmark") && root.selectedIndex === index) ? theme.bg_dark : "transparent"
                                radius: 0

                                // 1. Header Type
                                Item {
                                    visible: modelData.type === "header"
                                    anchors.fill: parent

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.name || ""
                                        color: theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        font.bold: true
                                        renderType: Text.NativeRendering
                                    }

                                }

                                // 2. Separator Type
                                Rectangle {
                                    visible: modelData.type === "separator"
                                    width: listContainer.width
                                    height: 1
                                    color: theme.accent
                                    opacity: 0.25
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                // 3. App Type
                                Row {
                                    visible: modelData.type === "app"
                                    width: listContainer.width - 8
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 4
                                    spacing: 6

                                    Text {
                                        text: (modelData.data && modelData.data.name) ? modelData.data.name.toLowerCase() : ""
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        elide: Text.ElideRight
                                        width: 110
                                        renderType: Text.NativeRendering

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                                easing.type: Easing.OutQuad
                                            }

                                        }

                                    }

                                    Text {
                                        text: (modelData.data && modelData.data.exec) ? modelData.data.exec.toLowerCase() : ""
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        opacity: root.selectedIndex === index ? 0.6 : 0.4
                                        elide: Text.ElideRight
                                        width: listContainer.width - 136
                                        renderType: Text.NativeRendering

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                                easing.type: Easing.OutQuad
                                            }

                                        }

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: 120
                                                easing.type: Easing.OutQuad
                                            }

                                        }

                                    }

                                }

                                // 4. Web Search Type
                                Row {
                                    visible: modelData.type === "web_search"
                                    width: listContainer.width - 8
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 4
                                    spacing: 6

                                    Text {
                                        text: "󰖟"
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7.5
                                        renderType: Text.NativeRendering

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                                easing.type: Easing.OutQuad
                                            }

                                        }

                                    }

                                    Text {
                                        text: (modelData.type === "web_search" && modelData.engine) ? (modelData.query ? ("search '" + modelData.query.toLowerCase() + "' on " + modelData.engine.toLowerCase()) : ("type to search on " + modelData.engine.toLowerCase() + "...")) : ""
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        elide: Text.ElideRight
                                        width: listContainer.width - 32
                                        renderType: Text.NativeRendering

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                                easing.type: Easing.OutQuad
                                            }

                                        }

                                    }

                                }

                                // 5. File Type
                                Row {
                                    visible: modelData.type === "file"
                                    width: listContainer.width - 8
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 4
                                    spacing: 6

                                    Text {
                                        text: "󰉋"
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7.5
                                        renderType: Text.NativeRendering

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                                easing.type: Easing.OutQuad
                                            }

                                        }

                                    }

                                    Text {
                                        text: {
                                            if (!modelData.data)
                                                return "";

                                            var name = modelData.data.name || "";
                                            var path = modelData.data.path || "";
                                            var dir = path.substring(0, path.lastIndexOf("/"));
                                            return name + "  " + dir;
                                        }
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        opacity: root.selectedIndex === index ? 0.8 : 0.5
                                        elide: Text.ElideRight
                                        width: listContainer.width - 24
                                        renderType: Text.NativeRendering

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                                easing.type: Easing.OutQuad
                                            }

                                        }

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: 120
                                                easing.type: Easing.OutQuad
                                            }

                                        }

                                    }

                                }

                                // 6. Git Repo Type
                                Row {
                                    visible: modelData.type === "git_repo"
                                    width: listContainer.width - 8
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 4
                                    spacing: 6

                                    Text {
                                        text: "󰊤"
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7.5
                                        renderType: Text.NativeRendering

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                                easing.type: Easing.OutQuad
                                            }

                                        }

                                    }

                                    Text {
                                        text: {
                                            if (!modelData.data)
                                                return "";

                                            var name = modelData.data.name || "";
                                            var owner = modelData.data.owner_login || "";
                                            var stars = modelData.data.stars || 0;
                                            var lang = modelData.data.language || "";
                                            var info = owner + "/" + name;
                                            if (stars > 0)
                                                info += "  ★ " + stars;

                                            if (lang)
                                                info += "  " + lang;

                                            return info;
                                        }
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        opacity: root.selectedIndex === index ? 0.8 : 0.5
                                        elide: Text.ElideRight
                                        width: listContainer.width - 24
                                        renderType: Text.NativeRendering

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                                easing.type: Easing.OutQuad
                                            }

                                        }

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: 120
                                                easing.type: Easing.OutQuad
                                            }

                                        }

                                    }

                                }

                                // 7. Bookmark Type
                                Row {
                                    visible: modelData.type === "bookmark"
                                    width: listContainer.width - 8
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 4
                                    spacing: 6

                                    Text {
                                        text: "󰓆"
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7.5
                                        renderType: Text.NativeRendering

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                                easing.type: Easing.OutQuad
                                            }

                                        }

                                    }

                                    Text {
                                        text: {
                                            if (!modelData.data)
                                                return "";

                                            var name = modelData.data.name || "";
                                            var url = modelData.data.url || "";
                                            return name + "  " + url;
                                        }
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        opacity: root.selectedIndex === index ? 0.8 : 0.5
                                        elide: Text.ElideRight
                                        width: listContainer.width - 40
                                        renderType: Text.NativeRendering

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                                easing.type: Easing.OutQuad
                                            }

                                        }

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: 120
                                                easing.type: Easing.OutQuad
                                            }

                                        }

                                    }

                                }

                                // Small delete indicator or button on the right
                                Text {
                                    text: ""
                                    color: theme.secondary
                                    font.family: root.fontName
                                    font.pointSize: 7
                                    opacity: root.selectedIndex === index ? 0.8 : 0
                                    visible: modelData.type === "bookmark" && root.selectedIndex === index
                                    renderType: Text.NativeRendering
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.rightMargin: 8

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.deleteBookmark(modelData.data.url);
                                        }
                                    }

                                }

                                // 8. Add Bookmark Type
                                Row {
                                    visible: modelData.type === "add_bookmark"
                                    width: listContainer.width - 8
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 4
                                    spacing: 6

                                    Text {
                                        text: "󰐕"
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7.5
                                        renderType: Text.NativeRendering

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                                easing.type: Easing.OutQuad
                                            }

                                        }

                                    }

                                    Text {
                                        text: "save bookmark '" + (modelData.url || "") + "'"
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        opacity: root.selectedIndex === index ? 0.8 : 0.5
                                        elide: Text.ElideRight
                                        width: listContainer.width - 24
                                        renderType: Text.NativeRendering

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                                easing.type: Easing.OutQuad
                                            }

                                        }

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: 120
                                                easing.type: Easing.OutQuad
                                            }

                                        }

                                    }

                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: modelData.type === "app" || modelData.type === "web_search" || modelData.type === "file" || modelData.type === "git_repo" || modelData.type === "bookmark" || modelData.type === "add_bookmark"
                                    hoverEnabled: true
                                    onEntered: {
                                        root.selectedIndex = index;
                                        root.selectedActiveWindowIndex = -1;
                                    }
                                    onClicked: {
                                        if (modelData.type === "app")
                                            root.launchApp(modelData.data.name, modelData.data.exec);
                                        else if (modelData.type === "web_search")
                                            root.launchWebSearch(root.getReconstructedQuery(modelData));
                                        else if (modelData.type === "file")
                                            root.launchFile(modelData.data.path);
                                        else if (modelData.type === "git_repo")
                                            root.launchGitRepo(modelData.data.html_url);
                                        else if (modelData.type === "bookmark")
                                            root.launchBookmark(modelData.data.url);
                                        else if (modelData.type === "add_bookmark")
                                            root.saveBookmark(modelData.url);
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                        easing.type: Easing.OutQuad
                                    }

                                }

                            }

                        }

                        // Container for the lists
                        Item {
                            id: listContainer

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            ListView {
                                id: appsList

                                anchors.fill: parent
                                model: root.appDisplayList
                                spacing: 2
                                clip: true
                                delegate: listDelegate
                                opacity: (root.isWebSearchMode || root.isFileSearchMode || root.isGitRepoMode || root.isBookmarkMode) ? 0 : 1
                                visible: opacity > 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }

                                }

                                transform: Translate {
                                    y: (root.isWebSearchMode || root.isFileSearchMode || root.isGitRepoMode || root.isBookmarkMode) ? -10 : 0

                                    Behavior on y {
                                        NumberAnimation {
                                            duration: 180
                                            easing.type: Easing.OutCubic
                                        }

                                    }

                                }

                            }

                            ListView {
                                id: webSearchList

                                anchors.fill: parent
                                model: root.webSearchDisplayList
                                spacing: 2
                                clip: true
                                delegate: listDelegate
                                opacity: root.isWebSearchMode ? 1 : 0
                                visible: opacity > 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }

                                }

                                transform: Translate {
                                    y: root.isWebSearchMode ? 0 : 10

                                    Behavior on y {
                                        NumberAnimation {
                                            duration: 180
                                            easing.type: Easing.OutCubic
                                        }

                                    }

                                }

                            }

                            ListView {
                                id: fileSearchList

                                anchors.fill: parent
                                model: root.fileSearchDisplayList
                                spacing: 2
                                clip: true
                                delegate: listDelegate
                                opacity: root.isFileSearchMode ? 1 : 0
                                visible: opacity > 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }

                                }

                                transform: Translate {
                                    y: root.isFileSearchMode ? 0 : 10

                                    Behavior on y {
                                        NumberAnimation {
                                            duration: 180
                                            easing.type: Easing.OutCubic
                                        }

                                    }

                                }

                            }

                            ListView {
                                id: gitRepoList

                                anchors.fill: parent
                                model: root.gitRepoSearchResults
                                spacing: 2
                                clip: true
                                delegate: listDelegate
                                opacity: root.isGitRepoMode ? 1 : 0
                                visible: opacity > 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }

                                }

                                transform: Translate {
                                    y: root.isGitRepoMode ? 0 : 10

                                    Behavior on y {
                                        NumberAnimation {
                                            duration: 180
                                            easing.type: Easing.OutCubic
                                        }

                                    }

                                }

                            }

                            ListView {
                                id: bookmarkList

                                anchors.fill: parent
                                model: root.bookmarkDisplayList
                                spacing: 2
                                clip: true
                                delegate: listDelegate
                                opacity: root.isBookmarkMode ? 1 : 0
                                visible: opacity > 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }

                                }

                                transform: Translate {
                                    y: root.isBookmarkMode ? 0 : 10

                                    Behavior on y {
                                        NumberAnimation {
                                            duration: 180
                                            easing.type: Easing.OutCubic
                                        }

                                    }

                                }

                            }

                            Behavior on implicitHeight {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        // Bottom Row
                        RowLayout {
                            id: bottomRow

                            Layout.fillWidth: true
                            Layout.bottomMargin: 2
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4

                            Text {
                                text: root.isBookmarkMode ? root.bookmarks.length + " bookmarks" : (root.isGitRepoMode ? root.gitRepos.length + " repos" : (root.isFileSearchMode ? root.fileHistory.length + " recent files" : (root.isWebSearchMode ? root.webHistory.length + " histories in websearch" : root.apps.length + " applications found")))
                                font.family: root.fontName
                                font.pointSize: 8
                                font.italic: true
                                color: theme.secondary
                                renderType: Text.NativeRendering
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: root.isBookmarkMode && root.bookmarks.length > 0
                                text: "clear"
                                font.family: root.fontName
                                font.pointSize: 8
                                font.italic: true
                                color: theme.secondary
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: clearBookmarksProc.running = true
                                }

                            }

                            Text {
                                visible: root.isWebSearchMode && root.webHistory.length > 0
                                text: "clear"
                                font.family: root.fontName
                                font.pointSize: 8
                                font.italic: true
                                color: theme.secondary
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: clearHistoryProc.running = true
                                }

                            }

                            Text {
                                visible: root.isFileSearchMode && root.fileHistory.length > 0
                                text: "clear"
                                font.family: root.fontName
                                font.pointSize: 8
                                font.italic: true
                                color: theme.secondary
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: clearFileHistoryProc.running = true
                                }

                            }

                            Text {
                                visible: root.isGitRepoMode
                                text: "refresh"
                                font.family: root.fontName
                                font.pointSize: 8
                                font.italic: true
                                color: theme.secondary
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: gitRepoRefreshProc.running = true
                                }

                            }

                        }

                    }

                }

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

    }

}
