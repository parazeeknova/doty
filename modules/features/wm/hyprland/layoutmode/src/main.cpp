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
#include <chrono>
#include <sys/wait.h>
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
std::vector<Desktop::View::CWindow*> g_nativeFloating; // floating before us: never touch
PHLWINDOW g_focusBefore;

bool isNative(Desktop::View::CWindow* raw) {
    return std::find(g_nativeFloating.begin(), g_nativeFloating.end(), raw) != g_nativeFloating.end();
}

std::string statePath() {
    const char* h = getenv("HOME");
    return std::string(h ? h : "/tmp") + "/.cache/hypr_layout_mode";
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

void notify(const std::string& summary, const std::string& body) {
    // default mako notifications (top-left, themed) instead of Hyprland's
    // native overlay: static strings only, no shell interpolation risk
    const std::string cmd = "notify-send -t 2000 -a \"Layout\" \"" + summary + "\" \"" + body + "\" 2>/dev/null";
    system(cmd.c_str());
}

void refreshWaybar() {
    // fire-and-forget; waybar's poll interval is the backstop
    system("/run/current-system/sw/bin/pkill -RTMIN+6 waybar 2>/dev/null");
}

std::string homeDir() {
    const char* h = getenv("HOME");
    return h ? h : "/tmp";
}

// Restart waybar on the variant matching the layout mode: top bar while
// floating, left bar while tiling. Respects the user's waybar on/off state;
// the variant choice is always recorded so restores pick the right one.
void switchWaybar(bool floating) {
    const std::string variant = floating ? "top" : "left";
    const std::string varFile = homeDir() + "/.cache/hypr_layout_waybar";
    {
        std::ofstream f(varFile, std::ios::trunc);
        if (f)
            f << variant << "\n";
    }
    // Always retire the old bar: every mode toggle flips the variant, so a
    // running bar is stale by definition (even a USR1-hidden one).
    // A fresh bar spawns only when waybar is enabled (hidden stays hidden).
    // Waybars ignore SIGTERM here (stuck exec children), so SIGKILL up
    // front. Absolute paths: the compositor's PATH can't be relied on.
    // Never spawn while any bar survives: stacking is worse than no bar.
    system("/run/current-system/sw/bin/pkill -KILL -x waybar 2>/dev/null; /run/current-system/sw/bin/pkill -KILL -x .waybar-wrapped 2>/dev/null");
    for (int i = 0; i < 20; ++i) {
        int rc = system("/run/current-system/sw/bin/pgrep -x waybar >/dev/null 2>&1 || /run/current-system/sw/bin/pgrep -x .waybar-wrapped >/dev/null 2>&1");
        if (rc == -1 || !WIFEXITED(rc) || WEXITSTATUS(rc) != 0)
            break;
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
    {
        int rc = system("/run/current-system/sw/bin/pgrep -x waybar >/dev/null 2>&1 || /run/current-system/sw/bin/pgrep -x .waybar-wrapped >/dev/null 2>&1");
        if (rc != -1 && WIFEXITED(rc) && WEXITSTATUS(rc) == 0)
            return; // survivors: don't stack, keep old bar over none
    }
    const std::string cfg   = floating ? "config-top.jsonc" : "config.jsonc";
    const std::string style = floating ? "style-top.css" : "style.css";
    const std::string cmd = "/run/current-system/sw/bin/uwsm app -- waybar -c " + homeDir() + "/.config/waybar/" + cfg + " -s " + homeDir()
            + "/.config/waybar/" + style + " >/dev/null 2>&1 &";
    system(cmd.c_str());
}

// Glass-aware bar theme: translucent + blurred with glass, solid without.
// Called on every toggle and via `hyprctl layoutmode syncbars` (wired into
// theme_switcher's glass toggle) so bars follow glass changes live.
bool glassEnabled() {
    const char* h = getenv("HOME");
    std::ifstream f(std::string(h ? h : "/tmp") + "/.cache/quickshell/glass_state");
    if (!f)
        return true;
    std::string s;
    f >> s;
    return s == "true";
}

void syncBarTheme() {
    const bool glass = glassEnabled();
    CConfigValue<Config::BOOL> blur("plugin:hyprbars:bar_blur");
    if (blur.good() && blur.ptr())
        *blur.ptr() = static_cast<Config::BOOL>(glass ? 1 : 0);
    CConfigValue<Config::INTEGER> color("plugin:hyprbars:bar_color");
    if (color.good() && color.ptr())
        *color.ptr() = static_cast<Config::INTEGER>(glass ? 0xA619120C : 0xFF19120C);
}

// Title bars live only in floating mode. hyprbars reads these values
// per-frame and repositions itself, so this applies instantly.
void setBars(bool on) {
    CConfigValue<Config::BOOL> h("plugin:hyprbars:enabled");
    if (h.good() && h.ptr())
        *h.ptr() = static_cast<Config::BOOL>(on ? 1 : 0);
    syncBarTheme();
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
                // re-apply remembered floating geometry, if we have it
                const auto git = g_floatGeoms.find(r.win);
                if (git != g_floatGeoms.end()) {
                    const auto t = w->layoutTarget();
                    if (t && t->floating())
                        t->setPositionGlobal(git->second);
                }
            }
        }
    }

    if (g_focusBefore && alive(g_focusBefore.get()))
        Desktop::focusState()->fullWindowFocus(g_focusBefore, Desktop::FOCUS_REASON_OTHER);

    g_floating = true;
    persistMode();
    setBars(true);
    switchWaybar(true);
    refreshWaybar();
    notify("Floating layout", "Tiling arrangement saved");
    // move mako notifications top-right, below the top waybar
    system("/run/current-system/sw/bin/env HOME=$HOME $HOME/doty/modules/scripts/mako_mode floating 2>/dev/null");
}

// Re-tile in snapshot order (each window lands next to its focused
// predecessor, reproducing the column order), then write exact column
// widths back directly. No focus dances beyond the predecessor chain,
// no structural tape surgery — only core-tested code paths.
void toTiling() {
    // bars off first so retiled windows never flash them
    setBars(false);
    const auto rememberGeom = [](const PHLWINDOW& w) {
        const auto t = w->layoutTarget();
        if (t && t->floating())
            g_floatGeoms[w.get()] = t->position();
    };
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
                rememberGeom(w);
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
        rememberGeom(w);
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
    switchWaybar(false);
    refreshWaybar();
    notify("Tiling layout", "Arrangement restored");
    // restore mako notifications to their original top-left dock
    system("/run/current-system/sw/bin/env HOME=$HOME $HOME/doty/modules/scripts/mako_mode tiling 2>/dev/null");
}

void toggle() {
    try {
        if (g_floating)
            toTiling();
        else
            toFloating();
    } catch (const std::exception& e) {
        const std::string cmd = std::string("notify-send -u critical -a \"Layout\" \"Toggle failed\" \"") + e.what() + "\" 2>/dev/null";
        system(cmd.c_str());
    }
}

// Float new windows while in floating mode (rules-processed leftovers only:
// scratchpads etc. are already floating and skipped by qualifies()).
void onWindowOpen(PHLWINDOW w) {
    if (!g_floating || !qualifies(w))
        return;
    try {
        g_layoutManager->changeFloatingMode(w->layoutTarget());
    } catch (...) {
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

    std::ifstream f(statePath());
    if (f) {
        std::string mode;
        f >> mode;
        g_floating = (mode == "floating");
    }
    setBars(g_floating);
    switchWaybar(g_floating);

    if (!HyprlandAPI::addLuaFunction(g_handle, "layoutmode", "toggle", luaToggle)) {
        HyprlandAPI::addNotification(g_handle, "[layoutmode] failed to register lua function", CHyprColor(1.F, 0.3F, 0.3F, 1.F), 5000);
        return {"layoutmode", "Global tiling/floating toggle", "parazeeknova",  "0.2.0"};
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

    return {"layoutmode", "Global tiling/floating toggle", "parazeeknova",  "0.2.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    if (g_hyprCmd) {
        HyprlandAPI::unregisterHyprCtlCommand(g_handle, g_hyprCmd);
        g_hyprCmd.reset();
    }
}
