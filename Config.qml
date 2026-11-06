import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

QtObject {
    id: cfg

    readonly property var defaults: ({
        "theme": "catppuccin-mocha",
        "design": "custom",
        "md3": {
            "mode": "auto",
            "source": "seed",
            "seed": "#6750A4",
            "variant": "analogous",
            "tint": 2,
            "motion": "expressive",
            "iconFont": "IosevkaTerm Nerd Font Mono",
            "wallpaper": "",
            "wallpaperCmd": "",
            "wallpaperPollMs": 5000
        },
        "font": {
            "family": "IosevkaTerm Nerd Font Mono",
            "fallback": ["Symbols Nerd Font Mono", "monospace"],
            "size": 22,
            "weight": "normal",
            "italic": false
        },
        "layout": {
            "buttons": ["lock", "logout", "suspend", "reboot", "shutdown"]
        },
        "animation": {
            "style": "slide",
            "focusMs": 180,
            "easing": "OutCubic",
            "openStyle": "expand",
            "openMs": 240,
            "openEasing": "OutCubic",
            "openOffset": 28,
            "openScale": 0.94,
            "tvOff": true,
            "tvOffActions": ["suspend", "reboot", "shutdown"],
            "tvOffMs": 380,
            "tvLineMs": 220,
            "tvEasing": "InOutCubic",
            "tvHoldMs": 2500,
            "tvColor": "#000000",
            "tvLineColor": "#ffffff"
        },
        "overlay": {
            "dim": 0.55,
            "radius": 16,
            "paddingX": 24,
            "paddingY": 20,
            "gap": 14
        },
        "button": {
            "width": 100,
            "height": 110,
            "radius": 14,
            "iconSize": 36,
            "labelSize": 13,
            "paddingY": 14,
            "confirmDangerous": true
        },
        "actions": {
            "lock": "lock",
            "logout": "mmsg dispatch quit",
            "suspend": "systemctl suspend",
            "reboot": "systemctl reboot",
            "shutdown": "systemctl poweroff"
        },
        "labels": {
            "lock": "Lock",
            "logout": "Logout",
            "suspend": "Sleep",
            "reboot": "Reboot",
            "shutdown": "Off"
        },
        "icons": {
            "lock": "\uf023",
            "logout": "\uf2f5",
            "suspend": "\uf186",
            "reboot": "\uf01e",
            "shutdown": "\uf011"
        },
        "colors": {
        },
        "button_colors": {
        }
    })
    readonly property var md3Defaults: ({
        "font": {
            "family": "Google Sans",
            "fallback": ["Google Sans Flex", "Roboto Flex", "Roboto", "sans-serif"],
            "size": 16,
            "weight": 500,
            "italic": false
        },
        "overlay": {
            "dim": 0.4,
            "radius": 40,
            "paddingX": 24,
            "paddingY": 24,
            "gap": 10
        },
        "button": {
            "width": 108,
            "height": 116,
            "radius": 32,
            "iconSize": 30,
            "labelSize": 13
        },
        "animation": {
            "style": "slide",
            "focusMs": 420,
            "easing": "OutBack",
            "openStyle": "pop",
            "openMs": 480,
            "openEasing": "OutBack",
            "openOffset": 40,
            "openScale": 0.8
        }
    })
    property var data: defaults
    property string configPath: ""
    property string lastError: ""
    readonly property var _easings: ({
        "linear": Easing.Linear,
        "inquad": Easing.InQuad,
        "outquad": Easing.OutQuad,
        "inoutquad": Easing.InOutQuad,
        "incubic": Easing.InCubic,
        "outcubic": Easing.OutCubic,
        "inoutcubic": Easing.InOutCubic,
        "inquart": Easing.InQuart,
        "outquart": Easing.OutQuart,
        "inoutquart": Easing.InOutQuart,
        "outexpo": Easing.OutExpo,
        "inoutexpo": Easing.InOutExpo,
        "outsine": Easing.OutSine,
        "inoutsine": Easing.InOutSine,
        "outback": Easing.OutBack,
        "inoutback": Easing.InOutBack,
        "outelastic": Easing.OutElastic,
        "outbounce": Easing.OutBounce
    })
    readonly property bool slide: String(get("animation.style", "slide")).toLowerCase() === "slide"
    readonly property int animMs: Math.max(0, Math.round(Number(get("animation.focusMs", 180)) || 0))
    readonly property int animEasing: {
        var e = _easings[String(get("animation.easing", "OutCubic")).toLowerCase()];
        return e === undefined ? Easing.OutCubic : e;
    }
    property Process finder
    property Process loader
    property FileView watcher
    property Timer poller

    function _toCamel(s) {
        return s.replace(/_([a-z])/g, function(_, c) {
            return c.toUpperCase();
        });
    }

    function camelizeKeys(o) {
        if (Array.isArray(o))
            return o.map(camelizeKeys);

        if (o !== null && typeof o === "object") {
            var r = {
            };
            for (var k in o) r[_toCamel(k)] = camelizeKeys(o[k])
            return r;
        }
        return o;
    }

    function deepMerge(base, over) {
        var out = {
        };
        for (var k in base) out[k] = base[k]
        for (var k in over) {
            var b = out[k], o = over[k];
            if (b && typeof b === "object" && !Array.isArray(b) && o && typeof o === "object" && !Array.isArray(o))
                out[k] = deepMerge(b, o);
            else
                out[k] = o;
        }
        return out;
    }

    function get(path, fallback) {
        var parts = path.split("."), v = data;
        for (var i = 0; i < parts.length; i++) {
            if (v === undefined || v === null)
                return fallback;

            v = v[parts[i]];
        }
        return v === undefined ? fallback : v;
    }

    function anim(key, fallback) {
        return get("animation." + key, fallback);
    }

    function ease(name, fallback) {
        var e = _easings[String(name).toLowerCase()];
        return e === undefined ? fallback : e;
    }

    function reload() {
        if (!configPath)
            return ;

        if (configPath.endsWith(".toml"))
            loader.command = ["python3", "-c", "import tomllib,json,sys;print(json.dumps(tomllib.load(open(sys.argv[1],'rb'))))", configPath];
        else
            loader.command = ["cat", configPath];
        loader.running = true;
    }

    onConfigPathChanged: reload()

    finder: Process {
        id: finder

        running: true
        command: ["sh", "-c", 'for p in "$ROSE_POWERMENU_CONFIG" ' + '"${XDG_CONFIG_HOME:-$HOME/.config}/rosepowermenu/config.toml" ' + '"${XDG_CONFIG_HOME:-$HOME/.config}/rosepowermenu/config.json" ' + '"$HOME/.rosepowermenu.toml" "$HOME/.rosepowermenu.json" ' + '"$0/config.toml" "$0/config.json"; do ' + '[ -n "$p" ] && [ -f "$p" ] && { printf "%s" "$p"; exit 0; }; done; exit 1', Quickshell.shellDir]

        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim();
                if (p)
                    cfg.configPath = p;

            }
        }

    }

    loader: Process {
        id: loader

        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var user = cfg.camelizeKeys(JSON.parse(text));
                    var base = cfg.defaults;
                    if ((user.design !== undefined ? user.design : base.design) === "md3e")
                        base = cfg.deepMerge(base, cfg.md3Defaults);

                    cfg.data = cfg.deepMerge(base, user);
                    cfg.lastError = "";
                } catch (e) {
                    cfg.lastError = String(e);
                    console.warn("[powermenu] config error:", e);
                }
            }
        }

    }

    watcher: FileView {
        path: cfg.configPath
        watchChanges: true
        onFileChanged: cfg.reload()
    }

    poller: Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: cfg.reload()
    }

}
