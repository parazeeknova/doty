// layoutmode — global tiling/floating toggle as a native Hyprland plugin.
//
// Why a plugin instead of a script: everything runs in-process, in one go.
// No hyprctl round-trips, no focus dances, no animation freeze hacks — the
// tape is snapshotted and rebuilt directly, then recalculated once, so
// windows glide to their new arrangement instead of flickering through it.
//
// State:
//   - mode (tiling/floating) persists in ~/.cache/hypr_layout_mode
//   - tiling tape snapshot + floating geometry live in memory (per session)

// NOTE: every std header used anywhere (here or inside Hyprland headers)
// must be parsed BEFORE `#define private public` below, otherwise the
// macro rewrite corrupts their access specifiers and compilation fails.
#include <algorithm>
#include <any>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <cstdlib>
#include <deque>
#include <expected>
#include <format>
#include <fstream>
#include <functional>
#include <future>
#include <list>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <set>
#include <shared_mutex>
#include <sstream>
#include <string>
#include <thread>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

// access compositor internals like hymission does; scoped so libstdc++
// headers (parsed later) are unaffected
#define private public
#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/SharedDefs.hpp>
#include <hyprland/src/desktop/DesktopTypes.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/state/GlobalWindowController.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/layout/space/Space.hpp>
#include <hyprland/src/layout/algorithm/Algorithm.hpp>
#include <hyprland/src/layout/algorithm/tiled/scrolling/ScrollingAlgorithm.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/helpers/Color.hpp>
#include <hyprland/src/helpers/memory/Memory.hpp>
#include <hyprland/src/config/ConfigValue.hpp>
#include <hyprland/src/config/ConfigManager.hpp>
#include <hyprland/src/debug/HyprCtl.hpp>
#include <hyprland/src/config/supplementary/executor/Executor.hpp>
#include <hyprland/src/devices/IPointer.hpp>
#include <hyprland/src/output/Monitor.hpp>
#undef private

#include <hyprutils/math/Box.hpp>

namespace {

HANDLE g_handle = nullptr;
SP<SHyprCtlCommand> g_hyprCmd;

bool g_floating = false;

struct SRowSnap {
    Desktop::View::CWindow* win = nullptr; // raw + liveness-checked, never dereferenced blindly
    float    rowSize = 1.F;
};

struct SColSnap {
    float             width = 0.6F;
    std::vector<SRowSnap> rows;
};

struct SWsSnap {
    PHLWORKSPACE          ws;
    std::vector<SColSnap> cols;
    double                offset = 0.0;
};

std::vector<SWsSnap> g_snap;
std::unordered_map<Desktop::View::CWindow*, CBox> g_floatGeoms;
std::unordered_map<std::string, CBox>            g_floatGeomsByClass;
std::vector<Desktop::View::CWindow*> g_nativeFloating; // floating before us: never touch
PHLWINDOW g_focusBefore;
PHLWINDOW g_lastFocusedWindow;

bool isNative(Desktop::View::CWindow* raw) {
    return std::find(g_nativeFloating.begin(), g_nativeFloating.end(), raw) != g_nativeFloating.end();
}

std::string homeDir() {
    const char* h = getenv("HOME");
    return h ? h : "/home/parazeeknova";
}

std::string statePath() {
    return homeDir() + "/.cache/hypr_layout_mode";
}

std::string geomsPath() {
    return homeDir() + "/.cache/hypr_float_geometries.json";
}

void saveGeometriesToDisk() {
    std::ofstream f(geomsPath(), std::ios::trunc);
    if (!f)
        return;
    f << "{\n";
    bool first = true;
    for (const auto& [cls, box] : g_floatGeomsByClass) {
        if (cls.empty() || box.width <= 10 || box.height <= 10)
            continue;
        if (!first)
            f << ",\n";
        first = false;
        f << "  \"" << cls << "\": {\"x\": " << static_cast<int>(box.x)
          << ", \"y\": " << static_cast<int>(box.y)
          << ", \"w\": " << static_cast<int>(box.width)
          << ", \"h\": " << static_cast<int>(box.height) << "}";
    }
    f << "\n}\n";
}

void loadGeometriesFromDisk() {
    std::ifstream f(geomsPath());
    if (!f)
        return;
    std::string line;
    while (std::getline(f, line)) {
        auto q1 = line.find('"');
        if (q1 == std::string::npos)
            continue;
        auto q2 = line.find('"', q1 + 1);
        if (q2 == std::string::npos)
            continue;
        std::string cls = line.substr(q1 + 1, q2 - q1 - 1);
        auto xPos = line.find("\"x\":");
        auto yPos = line.find("\"y\":");
        auto wPos = line.find("\"w\":");
        auto hPos = line.find("\"h\":");
        if (xPos != std::string::npos && yPos != std::string::npos &&
            wPos != std::string::npos && hPos != std::string::npos) {
            try {
                double x = std::stod(line.substr(xPos + 4));
                double y = std::stod(line.substr(yPos + 4));
                double w = std::stod(line.substr(wPos + 4));
                double h = std::stod(line.substr(hPos + 4));
                if (w > 10 && h > 10)
                    g_floatGeomsByClass[cls] = CBox{x, y, w, h};
            } catch (...) {
            }
        }
    }
}

CBox clampToMonitor(const CBox& box, const PHLWINDOW& w) {
    if (box.width <= 10 || box.height <= 10)
        return box;
    auto mon = w ? w->m_monitor.lock() : nullptr;
    if (!mon)
        mon = Desktop::focusState()->monitor();
    if (!mon)
        return box;

    CBox res = box;
    const double monX = mon->m_position.x;
    const double monY = mon->m_position.y;
    const double monW = mon->m_size.x;
    const double monH = mon->m_size.y;

    res.width  = std::clamp(res.width, 150.0, monW);
    res.height = std::clamp(res.height, 100.0, monH);

    if (res.x + res.width < monX + 40 || res.x > monX + monW - 40)
        res.x = monX + std::max(0.0, (monW - res.width) / 2.0);
    if (res.y + res.height < monY + 40 || res.y > monY + monH - 40)
        res.y = monY + std::max(0.0, (monH - res.height) / 2.0);

    return res;
}

void saveWindowGeom(const PHLWINDOW& w) {
    if (!w || !w->m_isMapped)
        return;
    const auto ws = w->m_workspace;
    if (!ws || ws->m_isSpecialWorkspace)
        return;
    if (Fullscreen::controller()->isFullscreen(w))
        return;
    const auto t = w->layoutTarget();
    if (!t || !t->floating())
        return;
    const std::string cls = w->m_class;
    if (cls.empty())
        return;
    const auto box = t->position();
    if (box.width <= 50 || box.height <= 50)
        return;

    const auto it = g_floatGeomsByClass.find(cls);
    if (it != g_floatGeomsByClass.end()) {
        const auto& old = it->second;
        if (std::abs(old.x - box.x) < 1 && std::abs(old.y - box.y) < 1 &&
            std::abs(old.width - box.width) < 1 && std::abs(old.height - box.height) < 1) {
            g_floatGeoms[w.get()] = box;
            return;
        }
    }

    g_floatGeoms[w.get()] = box;
    g_floatGeomsByClass[cls] = box;
    saveGeometriesToDisk();
}

void applyWindowGeom(const PHLWINDOW& w) {
    if (!w || !w->m_isMapped)
        return;
    const auto t = w->layoutTarget();
    if (!t || !t->floating())
        return;

    const auto git = g_floatGeoms.find(w.get());
    if (git != g_floatGeoms.end()) {
        t->setPositionGlobal(clampToMonitor(git->second, w));
        return;
    }

    const std::string cls = w->m_class;
    if (!cls.empty()) {
        const auto cit = g_floatGeomsByClass.find(cls);
        if (cit != g_floatGeomsByClass.end()) {
            const auto box = clampToMonitor(cit->second, w);
            t->setPositionGlobal(box);
            g_floatGeoms[w.get()] = box;
        }
    }
}

inline void asyncExec(const std::string& cmd) {
    if (Config::Supplementary::executor())
        Config::Supplementary::executor()->spawnRaw(cmd);
}

Layout::Tiled::CScrollingAlgorithm* scrollingFor(const PHLWORKSPACE& ws) {
    if (!ws || !ws->m_space)
        return nullptr;
    const auto algo = ws->m_space->algorithm();
    if (!algo || !algo->tiledAlgo())
        return nullptr;
    return dynamic_cast<Layout::Tiled::CScrollingAlgorithm*>(algo->tiledAlgo().get());
}

bool qualifies(const PHLWINDOW& w) {
    if (!w || !w->m_isMapped || w->m_isFloating)
        return false;
    const auto ws = w->m_workspace;
    if (!ws || ws->m_isSpecialWorkspace)
        return false;
    if (Fullscreen::controller()->isFullscreen(w))
        return false;
    if (!w->layoutTarget())
        return false;
    return true;
}

bool alive(Desktop::View::CWindow* raw) {
    if (!raw)
        return false;
    for (const auto& w : Desktop::windowState()->windows()) {
        if (w.get() == raw)
            return true;
    }
    return false;
}

PHLWINDOW findWin(Desktop::View::CWindow* raw) {
    for (const auto& w : Desktop::windowState()->windows()) {
        if (w.get() == raw)
            return w;
    }
    return nullptr;
}

// Glass-aware bar theme: translucent + blurred with glass, solid without.
// Called on every toggle and via `hyprctl layoutmode syncbars` (wired into
// theme_switcher's glass toggle) so bars follow glass changes live.
bool glassEnabled() {
    std::ifstream f(homeDir() + "/.cache/quickshell/glass_state");
    if (!f)
        return true;
    std::string s;
    f >> s;
    return s == "true";
}

// Non-aborting config writes: CConfigValue's ctor RASSERTs when the key
// doesn't exist (crashed the compositor at boot when hyprbars loads after
// us). getConfigValue() returns a safe optional-style reply instead.
template <typename T>
void setConfigValue(const std::string& name, const T& value) {
    if (!Config::mgr())
        return;
    const auto reply = Config::mgr()->getConfigValue(name);
    if (!reply.dataptr || !reply.type)
        return; // key not registered (plugin not loaded yet) — skip silently
    if (*reply.type != typeid(T))
        return;
    *rc<T*>(*reply.dataptr) = value;
}

void syncBarTheme() {
    const bool glass = glassEnabled();
    setConfigValue<Config::BOOL>("plugin:hyprbars:bar_blur", static_cast<Config::BOOL>(glass ? 1 : 0));
    setConfigValue<Config::INTEGER>("plugin:hyprbars:bar_color", static_cast<Config::INTEGER>(glass ? 0xA619120C : 0xFF19120C));
}

// Title bars live only in floating mode. Individual window floating and
// fullscreen states are handled per-window by hyprbars natively.
// In layoutmode, bars stay globally enabled in floating mode except when
// the hymission overview is open (overview hides them so tiles aren't cluttered).
bool overviewActive() {
    if (!g_pHyprCtl)
        return false;
    const std::string reply = g_pHyprCtl->getReply("hymission-overview-state");
    return reply.find("\"active\":true") != std::string::npos;
}

bool barsShouldBeOn() {
    return g_floating && !overviewActive();
}

void setBars(bool on) {
    setConfigValue<Config::BOOL>("plugin:hyprbars:enabled", static_cast<Config::BOOL>(on ? 1 : 0));
    syncBarTheme();
}

// recompute bars from the current context (mode + fullscreen + overview)
void refreshBars() {
    setBars(barsShouldBeOn());
}

void persistMode() {
    std::ofstream f(statePath(), std::ios::trunc);
    if (f)
        f << (g_floating ? "floating" : "tiling") << "\n";
}

// Snapshot the exact tape of every scrolling workspace with tiled windows,
// then float them all. Floating geometry from last time is re-applied.
void toFloating() {
    g_snap.clear();
    g_nativeFloating.clear();
    g_focusBefore = Desktop::focusState()->window();

    // remember natively-floating windows so the way back never tiles them
    for (const auto& w : Desktop::windowState()->windows()) {
        if (!w->m_isFloating || !w->m_isMapped)
            continue;
        const auto ws = w->m_workspace;
        if (!ws || ws->m_isSpecialWorkspace)
            continue;
        if (Fullscreen::controller()->isFullscreen(w))
            continue;
        g_nativeFloating.push_back(w.get());
    }

    // collect affected workspaces first (stable order by id for determinism)
    std::vector<PHLWORKSPACE> workspaces;
    for (const auto& w : Desktop::windowState()->windows()) {
        if (!qualifies(w))
            continue;
        const auto ws = w->m_workspace;
        if (std::find(workspaces.begin(), workspaces.end(), ws) == workspaces.end())
            workspaces.push_back(ws);
    }

    for (const auto& ws : workspaces) {
        auto* sc = scrollingFor(ws);
        if (!sc)
            continue;
        SWsSnap s;
        s.ws     = ws;
        s.offset = sc->m_scrollingData->controller->getOffset();
        for (const auto& col : sc->m_scrollingData->columns) {
            SColSnap c;
            c.width = col->getColumnWidth();
            for (size_t i = 0; i < col->targetDatas.size(); ++i) {
                const auto t = col->targetDatas[i]->target;
                if (!t)
                    continue;
                const auto w = t->window();
                if (!qualifies(w))
                    continue;
                c.rows.push_back({w.get(), col->getTargetSize(i)});
            }
            if (!c.rows.empty())
                s.cols.push_back(std::move(c));
        }
        if (!s.cols.empty())
            g_snap.push_back(std::move(s));
    }

    for (const auto& s : g_snap) {
        for (const auto& c : s.cols) {
            for (const auto& r : c.rows) {
                auto w = findWin(r.win);
                if (!w || !qualifies(w))
                    continue;
                g_layoutManager->changeFloatingMode(w->layoutTarget());
                applyWindowGeom(w);
            }
        }
    }

    if (g_focusBefore && alive(g_focusBefore.get()))
        Desktop::focusState()->fullWindowFocus(g_focusBefore, Desktop::FOCUS_REASON_OTHER);

    g_floating = true;
    persistMode();
    refreshBars();

    // Asynchronously switch Waybar variant, update mako dock, and notify user
    const std::string switchCmd = homeDir() + "/doty/modules/scripts/layout_mode_switch floating";
    asyncExec(switchCmd);
}

// Re-tile in snapshot order (each window lands next to its focused
// predecessor, reproducing the column order), then write exact column
// widths back directly. No focus dances beyond the predecessor chain,
// no structural tape surgery — only core-tested code paths.
void toTiling() {
    // bars off first so retiled windows never flash them
    setBars(false);

    for (const auto& w : Desktop::windowState()->windows()) {
        saveWindowGeom(w);
    }

    const auto focusWin = [](const PHLWINDOW& w) {
        if (w)
            Desktop::focusState()->fullWindowFocus(w, Desktop::FOCUS_REASON_OTHER);
    };

    // 1. retile snapshot windows in saved order, focusing each predecessor
    // so the layout inserts the next window right after it.
    PHLWINDOW lastRetiled;
    for (const auto& s : g_snap) {
        lastRetiled.reset();
        for (const auto& c : s.cols) {
            for (const auto& r : c.rows) {
                auto w = findWin(r.win);
                if (!w || !w->m_isFloating)
                    continue;
                saveWindowGeom(w);
                if (lastRetiled && alive(lastRetiled.get()))
                    focusWin(lastRetiled);
                g_layoutManager->changeFloatingMode(w->layoutTarget());
                lastRetiled = w;
            }
        }
    }
    // newcomers (opened while floating): tile after everything else.
    // Natively-floating windows (predating our float) are left alone.
    for (const auto& w : std::vector<PHLWINDOW>(Desktop::windowState()->windows().begin(), Desktop::windowState()->windows().end())) {
        if (!w->m_isFloating || !w->m_isMapped)
            continue;
        const auto ws = w->m_workspace;
        if (!ws || ws->m_isSpecialWorkspace)
            continue;
        if (Fullscreen::controller()->isFullscreen(w))
            continue;
        if (!w->layoutTarget())
            continue;
        if (isNative(w.get()))
            continue;
        saveWindowGeom(w);
        g_layoutManager->changeFloatingMode(w->layoutTarget());
        lastRetiled = w;
    }
    // drop geometry of windows that no longer exist
    for (auto it = g_floatGeoms.begin(); it != g_floatGeoms.end();) {
        if (!alive(it->first))
            it = g_floatGeoms.erase(it);
        else
            ++it;
    }

    // 2. write exact column widths back (unitless tape fractions — exact,
    // no gap math, no converge loop).
    for (const auto& s : g_snap) {
        if (!s.ws)
            continue;
        auto* sc = scrollingFor(s.ws);
        if (!sc)
            continue;
        for (const auto& c : s.cols) {
            if (c.rows.empty())
                continue;
            auto w = findWin(c.rows[0].win);
            if (!w)
                continue;
            const auto t = w->layoutTarget();
            if (!t)
                continue;
            const auto d = sc->dataFor(t);
            if (!d)
                continue;
            if (const auto col = d->column.lock())
                col->setColumnWidth(c.width);
        }
        // single recalculate: strip values above only take effect here,
        // windows glide to their restored widths in one animated pass
        sc->m_scrollingData->recalculate(false);
        s.ws->updateWindows();
        s.ws->updateWindowData();
    }

    Desktop::globalWindowController()->updateAllWindowsDecorations();

    if (g_focusBefore && alive(g_focusBefore.get()))
        Desktop::focusState()->fullWindowFocus(g_focusBefore, Desktop::FOCUS_REASON_OTHER);

    g_snap.clear();
    g_floating = false;
    persistMode();

    // Asynchronously switch Waybar variant, update mako dock, and notify user
    const std::string switchCmd = homeDir() + "/doty/modules/scripts/layout_mode_switch tiling";
    asyncExec(switchCmd);
}

void toggle() {
    try {
        if (g_floating)
            toTiling();
        else
            toFloating();
    } catch (const std::exception& e) {
        const std::string cmd = std::string("notify-send -u critical -a \"Layout\" \"Toggle failed\" \"") + e.what() + "\" 2>/dev/null";
        asyncExec(cmd);
    }
}

void onWindowOpen(PHLWINDOW w) {
    if (!w || !w->m_isMapped)
        return;
    const auto ws = w->m_workspace;
    if (!ws || ws->m_isSpecialWorkspace)
        return;
    if (Fullscreen::controller()->isFullscreen(w))
        return;
    if (!w->layoutTarget())
        return;

    if (g_floating) {
        try {
            if (!w->m_isFloating)
                g_layoutManager->changeFloatingMode(w->layoutTarget());
            applyWindowGeom(w);
        } catch (...) {
        }
    } else if (w->m_isFloating) {
        try {
            applyWindowGeom(w);
        } catch (...) {
        }
    }
}

int luaToggle(lua_State*) {
    toggle();
    return 0;
}

std::string hyprctlLayoutmode(eHyprCtlOutputFormat, std::string args) {
    // exact=false passes the remainder in various shapes ("toggle",
    // "layoutmode toggle", ...), so match leniently
    if (args.find("toggle") != std::string::npos)
        toggle();
    else if (args.find("syncbars") != std::string::npos)
        syncBarTheme();
    else if (args.find("syncoverview") != std::string::npos)
        refreshBars();
    if (g_floating)
        return "{\"text\":\"F\",\"class\":\"floating\",\"tooltip\":\"Floating layout — click to tile\"}\n";
    return "{\"text\":\"T\",\"class\":\"tiling\",\"tooltip\":\"Tiling layout — click to float\"}\n";
}

} // namespace

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    g_handle = handle;

    loadGeometriesFromDisk();

    std::ifstream f(statePath());
    if (f) {
        std::string mode;
        f >> mode;
        g_floating = (mode == "floating");
    }

    if (!HyprlandAPI::addLuaFunction(g_handle, "layoutmode", "toggle", luaToggle)) {
        HyprlandAPI::addNotification(g_handle, "[layoutmode] failed to register lua function", CHyprColor(1.F, 0.3F, 0.3F, 1.F), 5000);
        return {"layoutmode", "Global tiling/floating toggle", "parazeeknova",  "0.2.1"};
    }

    g_hyprCmd = HyprlandAPI::registerHyprCtlCommand(g_handle, SHyprCtlCommand{
                                                                  .name  = "layoutmode",
                                                                  .exact = false,
                                                                  .fn    = hyprctlLayoutmode,
                                                              });
    if (!g_hyprCmd)
        HyprlandAPI::addNotification(g_handle, "[layoutmode] failed to register hyprctl command", CHyprColor(1.F, 0.3F, 0.3F, 1.F), 5000);

    static const auto openListener = Event::bus()->m_events.window.open.listen([](PHLWINDOW w) { onWindowOpen(w); });
    (void)openListener;

    static const auto updateRulesListener = Event::bus()->m_events.window.updateRules.listen([](PHLWINDOW w) {
        if (!w || !w->m_isFloating || w->m_class.empty())
            return;
        if (g_floatGeoms.find(w.get()) == g_floatGeoms.end())
            applyWindowGeom(w);
    });
    (void)updateRulesListener;

    static const auto floatingListener = Event::bus()->m_events.window.floating.listen([](PHLWINDOW w) {
        if (w && w->m_isFloating)
            applyWindowGeom(w);
    });
    (void)floatingListener;

    static const auto closeListener = Event::bus()->m_events.window.close.listen([](PHLWINDOW w) {
        saveWindowGeom(w);
        refreshBars();
    });
    (void)closeListener;

    static const auto fsListener = Event::bus()->m_events.window.fullscreen.listen([]() { refreshBars(); });
    (void)fsListener;

    static const auto wsListener = Event::bus()->m_events.workspace.active.listen([]() { refreshBars(); });
    (void)wsListener;

    static const auto winActiveListener = Event::bus()->m_events.window.active.listen([](PHLWINDOW w, Desktop::eFocusReason) {
        if (g_lastFocusedWindow && alive(g_lastFocusedWindow.get()))
            saveWindowGeom(g_lastFocusedWindow);
        g_lastFocusedWindow = w;
        refreshBars();
    });
    (void)winActiveListener;

    static const auto mouseButtonListener = Event::bus()->m_events.input.mouse.button.listen([](const IPointer::SButtonEvent& e, Event::SCallbackInfo&) {
        if (e.state == 0) {
            const auto active = Desktop::focusState()->window();
            if (active)
                saveWindowGeom(active);
        }
    });
    (void)mouseButtonListener;

    // hyprbars may load after us; re-sync bars on every config reload
    static const auto cfgListener = Event::bus()->m_events.config.reloaded.listen([]() { refreshBars(); });
    (void)cfgListener;

    return {"layoutmode", "Global tiling/floating toggle", "parazeeknova",  "0.2.1"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    for (const auto& w : Desktop::windowState()->windows()) {
        saveWindowGeom(w);
    }
    if (g_hyprCmd) {
        HyprlandAPI::unregisterHyprCtlCommand(g_handle, g_hyprCmd);
        g_hyprCmd.reset();
    }
    g_handle = nullptr;
}
