import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Modules.ControlCenter.Widgets
import "Format.js" as Format

// The miner toggles and earnings, shared by the control center detail page
// and the bar popout.
Column {
    id: panel

    property var minerState: null
    readonly property var pool: minerState?.pool ?? null
    readonly property var miners: minerState?.miners ?? []
    readonly property bool anyActive: miners.some(m => m.active)

    signal control(string action, string which)

    spacing: CcMetrics.detailContentGap

    // On while any miner runs, so switching it off always stops all of them.
    CcGroup {
        width: parent.width

        CcToggleRow {
            iconName: "local_fire_department"
            text: "All miners"
            description: panel.anyActive ? "Switch off to stop every miner" : "Switch on to start every miner"
            checked: panel.anyActive
            onToggled: checked => panel.control(checked ? "start" : "stop", "all")
        }
    }

    CcGroup {
        width: parent.width

        Repeater {
            model: panel.miners

            CcToggleRow {
                required property var modelData

                iconName: modelData.id === "gpu" ? "developer_board" : "memory"
                text: modelData.label
                description: Format.minerLine(modelData)
                checked: modelData.active
                onToggled: checked => panel.control(checked ? "start" : "stop", modelData.id)
            }
        }
    }

    CcGroup {
        width: parent.width
        visible: panel.pool !== null

        CcListRow {
            iconName: "payments"
            title: "About " + Format.eur(panel.pool?.eurPerDay) + " a day"
            subtitle: Format.xmr(panel.pool?.xmrPerDay) + " at " + Format.eur(panel.pool?.price) + " per XMR"
        }

        CcListRow {
            iconName: "account_balance_wallet"
            title: "Pending " + Format.xmr(panel.pool?.pending)
            subtitle: "Paid out " + Format.xmr(panel.pool?.paid) + " so far"
        }
    }
}
