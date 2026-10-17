import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "."

PanelWindow {
    id: root

    required property var state

    readonly property var buttons: {
        var list = Config.data.layout.buttons || [];
        return list.filter(function(k) { return Config.data.actions[k] !== undefined; });
    }

    // ---- layer shell: full-screen overlay, grabs keyboard -----------------
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rose-powermenu"
    WlrLayershell.keyboardFocus: root.state.opened
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore   // zone -1: cover the whole screen, bar included
    color: "transparent"
    visible: root.state.opened

    // ---- animation settings (all from [animation] in the config) ---------
    readonly property string openStyle: String(Config.anim("openStyle", "glide")).toLowerCase()
    readonly property int    openMs:    Math.max(0, Math.round(Number(Config.anim("openMs", 240)) || 0))
    readonly property real   openOffset: Number(Config.anim("openOffset", 28)) || 0
    readonly property real   openScale: {
        var v = Number(Config.anim("openScale", 0.94));
        return isNaN(v) ? 0.94 : Math.max(0.1, Math.min(1, v));
    }
    readonly property int openEase: Config.ease(Config.anim("openEasing", "OutCubic"), Easing.OutCubic)

    readonly property bool tvEnabled: Config.anim("tvOff", true) === true
    readonly property int  tvMs:     Math.max(0, Math.round(Number(Config.anim("tvOffMs", 380)) || 0))
    readonly property int  tvLineMs: Math.max(0, Math.round(Number(Config.anim("tvLineMs", 220)) || 0))
    readonly property int  tvEase:   Config.ease(Config.anim("tvEasing", "InOutCubic"), Easing.InOutCubic)
    readonly property color tvColor:     Config.anim("tvColor", "#000000")
    readonly property color tvLineColor: Config.anim("tvLineColor", "#ffffff")

    // runtime state
    property real   dimFactor: 1
    property real   revealX: 1              // 0 → 1: card revealed from the center
    property bool   busy: false            // tv-off is playing, ignore input
    property string pendingKey: ""
    property real   tvProgress: 0          // 0 → 1: bars closing
    property real   tvLine: 1              // 1 → 0: line shrinking to a dot
    property real   tvLineOpacity: 1
    property string confirmPending: ""

    // ---- dim backdrop ------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, Config.data.overlay.dim * root.dimFactor)

        MouseArea {
            anchors.fill: parent
            onClicked: if (!root.busy) root.state.opened = false
        }
    }

    // ---- center card -------------------------------------------------------
    // Wrapper that clips the card while it opens ("expand" style): its width grows
    // from the center outwards, so the card is revealed to the left and right at once.
    Item {
        id: reveal
        anchors.centerIn: parent
        width:  card.width * root.revealX
        height: card.height
        clip:   root.revealX < 1

        Rectangle {
            id: card
            anchors.centerIn: parent
            width:  stage.width  + Config.data.overlay.paddingX * 2
            height: stage.height + Config.data.overlay.paddingY * 2
            radius: Config.data.overlay.radius
            color:  Theme.bg
            border.width: 1
            border.color: Theme.border

            transform: Translate { id: shift; y: 0 }

            // Stop click-through from hitting the backdrop
            MouseArea { anchors.fill: parent }

            Item {
                id: stage
                anchors.centerIn: parent
                width:  row.implicitWidth
                height: row.implicitHeight

                // ---- gliding focus highlight (style = "slide") ----------------
                Rectangle {
                    id: glide

                    // false while the menu is opening, so it appears in place
                    // instead of gliding in from the corner.
                    property bool armed: false

                    readonly property var focusItem: {
                        var c = repeater.count;           // re-evaluate when buttons exist
                        return repeater.itemAt(root.state.focusIndex);
                    }
                    readonly property bool ready: focusItem !== null && focusItem !== undefined

                    visible: Config.slide && ready
                    x:      ready ? focusItem.x      : 0
                    y:      ready ? focusItem.y      : 0
                    width:  ready ? focusItem.width  : 0
                    height: ready ? focusItem.height : 0
                    radius: Config.data.button.radius
                    color:  Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                    border.width: 2
                    border.color: Theme.accent

                    Behavior on x {
                        enabled: glide.armed && Config.animMs > 0
                        NumberAnimation { duration: Config.animMs; easing.type: Config.animEasing }
                    }
                    Behavior on y {
                        enabled: glide.armed && Config.animMs > 0
                        NumberAnimation { duration: Config.animMs; easing.type: Config.animEasing }
                    }
                    Behavior on width {
                        enabled: glide.armed && Config.animMs > 0
                        NumberAnimation { duration: Config.animMs; easing.type: Config.animEasing }
                    }
                    Behavior on height {
                        enabled: glide.armed && Config.animMs > 0
                        NumberAnimation { duration: Config.animMs; easing.type: Config.animEasing }
                    }
                }

                Row {
                    id: row
                    spacing: Config.data.overlay.gap

                    Repeater {
                        id: repeater
                        model: root.buttons
                        delegate: PowerButton {
                            required property int index
                            required property var modelData
                            actionKey: modelData
                            focused:   root.state.focusIndex === index
                            onActivated: root.runAction(modelData)
                            // slide mode: the highlight follows the mouse too
                            onHoverEntered: if (Config.slide && !root.busy) root.state.focusIndex = index
                        }
                    }
                }
            }

            // ---- keyboard handling ------------------------------------------
            focus: true
            Keys.onEscapePressed: if (!root.busy) root.state.opened = false
            Keys.onLeftPressed: {
                var n = root.buttons.length;
                if (!root.busy && n > 0) root.state.focusIndex = (root.state.focusIndex - 1 + n) % n;
            }
            Keys.onRightPressed: {
                var n = root.buttons.length;
                if (!root.busy && n > 0) root.state.focusIndex = (root.state.focusIndex + 1) % n;
            }
            Keys.onReturnPressed: root.runAction(root.buttons[root.state.focusIndex])
            Keys.onEnterPressed:  root.runAction(root.buttons[root.state.focusIndex])
            Keys.onSpacePressed:  root.runAction(root.buttons[root.state.focusIndex])
        }
    }

    // ---- "TV off" overlay ---------------------------------------------------
    // Two bars close in from the top and bottom edge until they meet, then a
    // bright line shrinks to a dot and fades.
    Item {
        id: tv
        anchors.fill: parent
        z: 100
        visible: root.tvProgress > 0

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: Math.ceil(parent.height / 2 * root.tvProgress)
            color: root.tvColor
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Math.ceil(parent.height / 2 * root.tvProgress)
            color: root.tvColor
        }
        Rectangle {
            visible: root.tvProgress >= 1
            anchors.centerIn: parent
            width: parent.width * root.tvLine
            height: 3
            radius: 2
            opacity: root.tvLineOpacity
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0;  color: Qt.alpha(root.tvLineColor, 0) }
                GradientStop { position: 0.15; color: root.tvLineColor }
                GradientStop { position: 0.85; color: root.tvLineColor }
                GradientStop { position: 1.0;  color: Qt.alpha(root.tvLineColor, 0) }
            }
        }
    }

    SequentialAnimation {
        id: tvAnim
        NumberAnimation {
            target: root; property: "tvProgress"; from: 0; to: 1
            duration: root.tvMs; easing.type: root.tvEase
        }
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "tvLine"; from: 1; to: 0
                duration: root.tvLineMs; easing.type: Easing.InQuad
            }
            SequentialAnimation {
                PauseAnimation { duration: Math.round(root.tvLineMs * 0.6) }
                NumberAnimation {
                    target: root; property: "tvLineOpacity"; from: 1; to: 0
                    duration: Math.round(root.tvLineMs * 0.4)
                }
            }
        }
        ScriptAction { script: root.finishTv() }
    }

    // ---- opening animation --------------------------------------------------
    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: root; property: "dimFactor"; from: 0; to: 1
            duration: root.openMs; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: card; property: "opacity"; from: 0; to: 1
            duration: root.openMs; easing.type: root.openEase
        }
        NumberAnimation {
            target: root; property: "revealX"
            from: root.openStyle === "expand" ? 0 : 1; to: 1
            duration: root.openMs; easing.type: root.openEase
        }
        NumberAnimation {
            target: card; property: "scale"
            from: (root.openStyle === "fade" || root.openStyle === "expand") ? 1 : root.openScale; to: 1
            duration: root.openMs; easing.type: root.openEase
        }
        NumberAnimation {
            target: shift; property: "y"
            from: root.openStyle === "glide" ? root.openOffset : 0; to: 0
            duration: root.openMs; easing.type: root.openEase
        }
    }

    function resetVisuals() {
        openAnim.stop();
        tvAnim.stop();
        holdTimer.stop();
        dimFactor = 1; revealX = 1; card.opacity = 1; card.scale = 1; shift.y = 0;
        tvProgress = 0; tvLine = 1; tvLineOpacity = 1;
        busy = false; pendingKey = "";
    }

    Connections {
        target: root.state
        function onOpenedChanged() {
            glide.armed = false;
            root.resetVisuals();
            if (root.state.opened) {
                armTimer.restart();
                root.confirmPending = "";
                if (root.openMs > 0 && root.openStyle !== "none")
                    openAnim.restart();
            }
        }
    }
    Timer { id: armTimer; interval: 60; onTriggered: glide.armed = true }

    // ---- action runner -----------------------------------------------------
    function execAction(key) {
        var cmd = Config.data.actions[key];
        if (cmd) {
            console.log("[powermenu] running:", cmd);
            Quickshell.execDetached(["sh", "-c", cmd]);
        }
    }

    function runAction(key) {
        if (!key || busy) return;
        var dangerous = (key === "reboot" || key === "shutdown" || key === "logout");
        // Needs a second press on the SAME button within 3 s.
        if (Config.data.button.confirmDangerous && dangerous &&
            root.confirmPending !== key) {
            root.confirmPending = key;
            confirmTimer.restart();
            return;
        }
        root.confirmPending = "";

        var tvKeys = Config.anim("tvOffActions", ["suspend", "reboot", "shutdown"]);
        if (tvEnabled && tvMs > 0 && tvKeys.indexOf(key) >= 0) {
            busy = true;
            pendingKey = key;
            tvAnim.restart();
            return;
        }
        execAction(key);
        root.state.opened = false;
    }

    // tv-off finished: screen is black, now run the command
    function finishTv() {
        var key = pendingKey;
        execAction(key);
        // suspend: let go quickly so the desktop is back after wake-up;
        // reboot/shutdown/logout: stay black until the session dies.
        holdTimer.interval = Math.max(1, key === "suspend"
            ? 400 : Math.round(Number(Config.anim("tvHoldMs", 2500)) || 0));
        holdTimer.restart();
    }

    Timer {
        id: holdTimer
        onTriggered: root.state.opened = false     // onOpenedChanged resets everything
    }

    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: root.confirmPending = ""
    }
}
