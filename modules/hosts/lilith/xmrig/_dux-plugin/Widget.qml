import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets
import qs.Modules.Plugins
import "Config.js" as Config
import "Format.js" as Format

PluginComponent {
    id: root

    PluginGlobalVar {
        id: shared
        varName: "state"
        defaultValue: null
    }

    readonly property var minerState: shared.value
    readonly property var miners: minerState?.miners ?? []
    readonly property bool anyActive: miners.some(m => m.active)
    readonly property bool anyPaused: miners.some(m => m.paused)
    readonly property real totalHashrate: miners.reduce((sum, m) => sum + m.hashrate, 0)
    readonly property string statusText: {
        if (anyActive) {
            const running = miners.filter(m => m.active).map(m => m.label).join(" + ");
            const pool = minerState?.pool;
            return pool ? `${running} · about ${Format.eur(pool.eurPerDay)} a day` : running;
        }
        if (anyPaused)
            return "Paused for a game";
        return "Off";
    }
    readonly property string pillIcon: !anyActive && anyPaused ? "pause_circle" : "local_fire_department"

    function control(action, which) {
        Proc.runCommand(`xmrigControl.${action}.${which}`, [Config.config.control, action, which], (stdout, exitCode) => {
            if (exitCode !== 0)
                ToastService.showError(`Could not ${action} the ${which === "all" ? "miners" : which.toUpperCase() + " miner"}`);
            PluginService.setGlobalVar("xmrigControl", "refresh", Date.now());
        }, 0);
    }

    ccWidgetIcon: pillIcon
    ccWidgetPrimaryText: "Mining"
    ccWidgetSecondaryText: statusText
    ccWidgetIsActive: anyActive
    ccDetailHeight: 390

    onCcWidgetToggled: control(anyActive ? "stop" : "start", "all")

    ccDetailContent: Component {
        Item {
            readonly property string title: "Mining"

            DFlickable {
                anchors.fill: parent
                contentHeight: detailPanel.height
                clip: true

                MinerPanel {
                    id: detailPanel
                    width: parent.width
                    minerState: root.minerState
                    onControl: (action, which) => root.control(action, which)
                }
            }
        }
    }

    // Right-clicking the pill stops every miner, or starts them when none
    // runs, without opening the popout.
    pillRightClickAction: () => control(anyActive ? "stop" : "start", "all")

    popoutWidth: 380
    popoutHeight: 420
    popoutContent: Component {
        PopoutComponent {
            headerText: "Mining"
            detailsText: root.statusText

            MinerPanel {
                width: parent.width
                minerState: root.minerState
                onControl: (action, which) => root.control(action, which)
            }
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DIcon {
                name: root.pillIcon
                filled: root.anyActive
                color: root.anyActive ? Theme.primary : Theme.surfaceVariantText
                size: root.iconSize
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.anyActive
                text: Format.hashrateShort(root.totalHashrate)
                color: Theme.surfaceText
                font.pixelSize: root.textSize
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DIcon {
                name: root.pillIcon
                filled: root.anyActive
                color: root.anyActive ? Theme.primary : Theme.surfaceVariantText
                size: root.iconSize
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: root.anyActive
                text: Format.hashrateShort(root.totalHashrate)
                color: Theme.surfaceText
                font.pixelSize: root.textSize
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
