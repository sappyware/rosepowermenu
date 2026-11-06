import "."
import QtQuick

Rectangle {
    id: btn

    required property string actionKey
    required property bool focused
    property bool confirming: false
    property int openGen: 0
    property int idx: 0
    readonly property var b: Config.data.button
    readonly property bool md: Theme.md3
    readonly property bool pressed: ma.pressed
    readonly property int iconPx: b.iconSize > 0 ? b.iconSize : Math.round(Theme.fontSize * 1.7)
    readonly property int labelPx: b.labelSize > 0 ? b.labelSize : Theme.fontSize
    readonly property bool ownFocusStyle: focused && !Config.slide
    readonly property var roles: md ? Theme.buttonRoles(actionKey) : ({
    })
    readonly property bool onHighlight: md && focused
    readonly property color mdIcon: confirming ? Theme.r.onError : onHighlight ? roles.on : roles.main
    readonly property color mdLabel: confirming ? Theme.r.onError : onHighlight ? roles.on : Theme.muted
    property real enter: 1
    property real pressScale: md && pressed ? 0.88 : 1

    signal activated()
    signal hoverEntered()

    width: b.width
    height: b.height
    radius: md ? (pressed ? 18 : Math.round(Math.min(width, height) * (ownFocusStyle ? 0.36 : 0.3))) : b.radius
    color: md ? (ownFocusStyle ? (confirming ? Theme.r.error : roles.container) : "transparent") : (hover.hovered && !(Config.slide && focused)) ? Theme.border : ownFocusStyle ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18) : "transparent"
    border.width: md ? 0 : (ownFocusStyle ? 2 : 1)
    border.color: ownFocusStyle ? Theme.accent : (Config.slide && focused) ? "transparent" : Theme.border
    onOpenGenChanged: {
        if (md && Config.anim("openStyle", "pop") !== "none") {
            enterAnim.restart();
        }
    }

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hovered) {
                btn.hoverEntered();
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: btn.radius
        color: Theme.fg
        opacity: btn.md ? (btn.pressed ? 0.12 : (hover.hovered && !btn.focused ? 0.08 : 0)) : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }

        }

    }

    SequentialAnimation {
        id: enterAnim

        ScriptAction {
            script: btn.enter = 0
        }

        PauseAnimation {
            duration: 90 + Math.min(btn.idx, 8) * 55
        }

        NumberAnimation {
            target: btn
            property: "enter"
            to: 1
            duration: Theme.springy ? 560 : 340
            easing.type: Theme.springy ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: 2.4
        }

    }

    Column {
        id: content

        anchors.centerIn: parent
        spacing: 8
        opacity: btn.md ? Math.max(0, Math.min(1, btn.enter * 1.5)) : 1
        scale: btn.md ? (0.5 + 0.5 * btn.enter) * btn.pressScale : 1

        Text {
            id: icon

            anchors.horizontalCenter: parent.horizontalCenter
            text: Config.data.icons[btn.actionKey] || "?"
            color: btn.md ? btn.mdIcon : Theme.buttonColor(btn.actionKey)
            font.family: btn.md ? Theme.iconFont : Theme.fontFamily
            font.pixelSize: btn.iconPx
            font.weight: Font.Normal
            scale: btn.md && btn.focused ? 1.18 : 1

            SequentialAnimation {
                running: btn.md && btn.confirming
                loops: Animation.Infinite
                onRunningChanged: {
                    if (!running) {
                        icon.rotation = 0;
                    }
                }

                NumberAnimation {
                    target: icon
                    property: "rotation"
                    to: -12
                    duration: 90
                    easing.type: Easing.OutSine
                }

                NumberAnimation {
                    target: icon
                    property: "rotation"
                    to: 12
                    duration: 180
                    easing.type: Easing.InOutSine
                }

                NumberAnimation {
                    target: icon
                    property: "rotation"
                    to: 0
                    duration: 90
                    easing.type: Easing.InSine
                }

                PauseAnimation {
                    duration: 260
                }

            }

            Behavior on color {
                enabled: btn.md

                ColorAnimation {
                    duration: 250
                }

            }

            Behavior on scale {
                enabled: btn.md

                NumberAnimation {
                    duration: Theme.springy ? 460 : 240
                    easing.type: Theme.springy ? Easing.OutBack : Easing.OutCubic
                    easing.overshoot: 2.8
                }

            }

        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: btn.md && btn.confirming ? "Sure?" : (Config.data.labels[btn.actionKey] || btn.actionKey)
            color: btn.md ? btn.mdLabel : Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: btn.labelPx
            font.weight: btn.focused ? Font.Bold : Theme.fontWeight
            font.italic: Theme.fontItalic

            Behavior on color {
                enabled: btn.md

                ColorAnimation {
                    duration: 250
                }

            }

        }

        transform: Translate {
            y: btn.md ? (1 - btn.enter) * 26 : 0
        }

    }

    MouseArea {
        id: ma

        anchors.fill: parent
        hoverEnabled: true
        onClicked: btn.activated()
    }

    Behavior on color {
        enabled: md || Config.animMs > 0

        ColorAnimation {
            duration: md ? 250 : Config.animMs
            easing.type: Config.animEasing
        }

    }

    Behavior on border.width {
        enabled: !md && Config.animMs > 0

        NumberAnimation {
            duration: Config.animMs
            easing.type: Config.animEasing
        }

    }

    Behavior on radius {
        enabled: md

        NumberAnimation {
            duration: 260
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasized
        }

    }

    Behavior on pressScale {
        enabled: btn.md

        NumberAnimation {
            duration: Theme.springy ? 380 : 200
            easing.type: Theme.springy ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: 2.6
        }

    }

}
