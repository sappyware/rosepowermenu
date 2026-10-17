import QtQuick
import "."

Rectangle {
    id: btn

    required property string actionKey
    required property bool   focused
    signal activated()
    signal hoverEntered()

    readonly property var b: Config.data.button

    // Font size resolution:
    //   icon_size / label_size if > 0 → use them
    //   otherwise fall back to font.size (icon scaled up a bit)
    readonly property int iconPx:
        b.iconSize > 0
            ? b.iconSize
            : Math.round(Theme.fontSize * 1.7)

    readonly property int labelPx:
        b.labelSize > 0
            ? b.labelSize
            : Theme.fontSize

    width:  b.width
    height: b.height
    radius: b.radius

    // In "slide" mode the focus fill/border is drawn by the gliding highlight
    // in PowerMenu.qml, so the button itself stays plain.
    readonly property bool ownFocusStyle: focused && !Config.slide

    color: (hover.hovered && !(Config.slide && focused)) ? Theme.border
         : ownFocusStyle ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
         :                 "transparent"
    border.width: ownFocusStyle ? 2 : 1
    border.color: ownFocusStyle ? Theme.accent
                : (Config.slide && focused) ? "transparent"
                : Theme.border

    Behavior on color {
        enabled: Config.animMs > 0
        ColorAnimation { duration: Config.animMs; easing.type: Config.animEasing }
    }
    Behavior on border.width {
        enabled: Config.animMs > 0
        NumberAnimation { duration: Config.animMs; easing.type: Config.animEasing }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: if (hovered) btn.hoverEntered()
    }

    Column {
        anchors.centerIn: parent
        spacing: 8

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Config.data.icons[btn.actionKey] || "?"
            color: Theme.buttonColor(btn.actionKey)
            font.family: Theme.fontFamily
            font.pixelSize: btn.iconPx
            font.weight: Font.Normal
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Config.data.labels[btn.actionKey] || btn.actionKey
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: btn.labelPx
            font.weight: btn.focused ? Font.Bold : Theme.fontWeight
            font.italic: Theme.fontItalic
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: btn.activated()
    }
}