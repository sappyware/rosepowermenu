pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: cfg

    readonly property var defaults: ({
        theme: "catppuccin-mocha",
        font: {
            family: "IosevkaTerm Nerd Font Mono",
            fallback: ["Symbols Nerd Font Mono", "monospace"],
            size: 22, weight: "normal", italic: false
        },
        layout: {
            buttons: ["lock", "logout", "suspend", "reboot", "shutdown"]
        },
        // Focus animation
        //   style:  "slide" = one highlight glides between buttons
        //           "fade"  = old behaviour, each button fades in/out
        //   focus_ms: duration in ms (0 = instant)
        //   easing: Linear | OutCubic | InOutCubic | OutQuart | OutExpo |
        //           OutBack | OutElastic | OutBounce | InOutQuad | OutSine ...
        animation: {
            style: "slide",
            focusMs: 180,
            easing: "OutCubic",

            // Opening animation of the whole card
            //   open_style: "expand" (grows from the center to left and right)
            //               | "glide" (rise + fade + scale) | "pop" (scale + fade)
            //               | "fade" | "none"
            openStyle: "expand",
            openMs: 240,
            openEasing: "OutCubic",
            openOffset: 28,      // px the card rises during "glide"
            openScale: 0.94,     // start scale for "glide" / "pop" (1 = no scale)

            // "TV off": black bars close in from top and bottom, then a bright
            // line shrinks to a dot, THEN the command runs.
            tvOff: true,
            tvOffActions: ["suspend", "reboot", "shutdown"],
            tvOffMs: 380,        // bars closing
            tvLineMs: 220,       // line shrinking to a dot
            tvEasing: "InOutCubic",
            tvHoldMs: 2500,      // stay black this long after the command (reboot/shutdown)
            tvColor: "#000000",
            tvLineColor: "#ffffff"
        },
        // Overlay + card
        overlay: {
            dim: 0.55,          // 0.0 → 1.0 opacity of the black backdrop
            radius: 16,
            paddingX: 24,
            paddingY: 20,
            gap: 14
        },
        // Each pill
        button: {
            width: 100,
            height: 110,
            radius: 14,
            iconSize: 36,
            labelSize: 13,
            paddingY: 14,
            confirmDangerous: true
        },
        // Every action is a shell command — swap for your tools.
        actions: {
            lock:     "lock",
            logout:   "mmsg dispatch quit",
            suspend:  "systemctl suspend",
            reboot:   "systemctl reboot",
            shutdown: "systemctl poweroff"
        },
        labels: {
            lock: "Lock", logout: "Logout", suspend: "Sleep",
            reboot: "Reboot", shutdown: "Off"
        },
        icons: {
            lock:     "\uf023",
            logout:   "\uf2f5",
            suspend:  "\uf186",
            reboot:   "\uf01e",
            shutdown: "\uf011"
        },
        colors: {},
        // Per-button accent overrides, e.g.
        // [button_colors.reboot] fg = "#fab387"
        button_colors: {}
    })

    property var data: defaults
    property string configPath: ""
    property string lastError: ""

    // snake_case → camelCase for TOML keys
    function _toCamel(s) {
        return s.replace(/_([a-z])/g, function(_, c) { return c.toUpperCase(); });
    }
    function camelizeKeys(o) {
        if (Array.isArray(o)) return o.map(camelizeKeys);
        if (o !== null && typeof o === "object") {
            var r = {};
            for (var k in o) r[_toCamel(k)] = camelizeKeys(o[k]);
            return r;
        }
        return o;
    }
    function deepMerge(base, over) {
        var out = {};
        for (var k in base) out[k] = base[k];
        for (var k in over) {
            var b = out[k], o = over[k];
            if (b && typeof b === "object" && !Array.isArray(b) &&
                o && typeof o === "object" && !Array.isArray(o))
                out[k] = deepMerge(b, o);
            else
                out[k] = o;
        }
        return out;
    }
    function get(path, fallback) {
        var parts = path.split("."), v = data;
        for (var i = 0; i < parts.length; i++) {
            if (v === undefined || v === null) return fallback;
            v = v[parts[i]];
        }
        return v === undefined ? fallback : v;
    }

    // ---- animation helpers (used by PowerMenu / PowerButton) --------------
    readonly property var _easings: ({
        linear: Easing.Linear,
        inquad: Easing.InQuad, outquad: Easing.OutQuad, inoutquad: Easing.InOutQuad,
        incubic: Easing.InCubic, outcubic: Easing.OutCubic, inoutcubic: Easing.InOutCubic,
        inquart: Easing.InQuart, outquart: Easing.OutQuart, inoutquart: Easing.InOutQuart,
        outexpo: Easing.OutExpo, inoutexpo: Easing.InOutExpo,
        outsine: Easing.OutSine, inoutsine: Easing.InOutSine,
        outback: Easing.OutBack, inoutback: Easing.InOutBack,
        outelastic: Easing.OutElastic, outbounce: Easing.OutBounce
    })
    function anim(key, fallback) { return get("animation." + key, fallback); }
    function ease(name, fallback) {
        var e = _easings[String(name).toLowerCase()];
        return e === undefined ? fallback : e;
    }
    readonly property bool slide:
        String(get("animation.style", "slide")).toLowerCase() === "slide"
    readonly property int animMs:
        Math.max(0, Math.round(Number(get("animation.focusMs", 180)) || 0))
    readonly property int animEasing: {
        var e = _easings[String(get("animation.easing", "OutCubic")).toLowerCase()];
        return e === undefined ? Easing.OutCubic : e;
    }

    property Process finder: Process {
        id: finder
        running: true
        command: ["sh", "-c",
            'for p in "$ROSE_POWERMENU_CONFIG" ' +
            '"${XDG_CONFIG_HOME:-$HOME/.config}/rose-powermenu/config.toml" ' +
            '"${XDG_CONFIG_HOME:-$HOME/.config}/rose-powermenu/config.json" ' +
            '"$HOME/.rose-powermenu.toml" "$HOME/.rose-powermenu.json" ' +
            '"$0/config.toml" "$0/config.json"; do ' +
            '[ -n "$p" ] && [ -f "$p" ] && { printf "%s" "$p"; exit 0; }; done; exit 1',
            Quickshell.shellDir]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim();
                if (p) cfg.configPath = p;
            }
        }
    }

    property Process loader: Process {
        id: loader
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    cfg.data = cfg.deepMerge(cfg.defaults,
                                             cfg.camelizeKeys(JSON.parse(text)));
                    cfg.lastError = "";
                } catch (e) {
                    cfg.lastError = String(e);
                    console.warn("[powermenu] config error:", e);
                }
            }
        }
    }

    function reload() {
        if (!configPath) return;
        if (configPath.endsWith(".toml")) {
            loader.command = ["python3", "-c",
                "import tomllib,json,sys;print(json.dumps(tomllib.load(open(sys.argv[1],'rb'))))",
                configPath];
        } else {
            loader.command = ["cat", configPath];
        }
        loader.running = true;
    }

    property FileView watcher: FileView {
        path: cfg.configPath
        watchChanges: true
        onFileChanged: cfg.reload()
    }

    property Timer poller: Timer {
        interval: 1500; running: true; repeat: true
        onTriggered: cfg.reload()
    }

    onConfigPathChanged: reload()
}
