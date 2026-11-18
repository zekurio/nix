import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins
import "Config.js" as Config

// Reads the HDR state once for every bar, screen and control center
// instance and shares it as the "hdrOn" global variable. Proc keeps one
// callback per command id, so the widgets cannot each poll under the same id.
PluginComponent {
    id: root

    readonly property string pid: "hdrToggle"

    // `dms ipc call hdrToggle status` prints what the widgets show.
    IpcHandler {
        target: "hdrToggle"

        function status(): string {
            return PluginService.getGlobalVar(root.pid, "hdrOn") ? "on" : "off";
        }
    }

    // hdr-mode only checks for a state file, so polling is cheap, and it
    // also catches `hdr-mode` runs from a terminal.
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }

    // The widgets bump "refresh" after switching.
    Connections {
        target: PluginService
        function onGlobalVarChanged(pluginId, varName) {
            if (pluginId === root.pid && varName === "refresh")
                root.poll();
        }
    }

    function poll() {
        Proc.runCommand(`${pid}.status`, [Config.config.command, "status"], (stdout, exitCode) => {
            if (exitCode === 0)
                PluginService.setGlobalVar(root.pid, "hdrOn", stdout.trim() === "on");
        }, 0);
    }
}
