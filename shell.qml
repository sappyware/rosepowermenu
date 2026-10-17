//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick
import "."

ShellRoot {
    id: root

    // Global state the IPC handler flips.
    QtObject {
        id: state
        property bool opened: false
        property int  focusIndex: 0
    }

    // The actual menu window.
    PowerMenu {
        id: menu
        state: state
    }

    // IPC:  qs -c rose-powermenu ipc call power toggle
    IpcHandler {
        target: "power"

        function toggle(): void {
            state.opened = !state.opened;
            if (state.opened) state.focusIndex = 0;
        }
        function open(): void {
            state.opened = true;
            state.focusIndex = 0;
        }
        function close(): void {
            state.opened = false;
        }
    }
}
