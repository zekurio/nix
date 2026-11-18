import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets
import qs.Modules.Plugins
import "Config.js" as Config

PluginComponent {
    id: root

    PluginGlobalVar {
        id: shared
        varName: "hdrOn"
        defaultValue: false
    }

    readonly property bool hdrOn: shared.value
    property bool busy: false

    readonly property string statusText: hdrOn ? "Desktop in HDR" : "SDR, fullscreen HDR switches on its own"
    readonly property string icon: hdrOn ? "hdr_on" : "hdr_off"

    function toggle() {
        if (busy)
            return;
        busy = true;
        const target = hdrOn ? "off" : "on";
        Proc.runCommand("hdrToggle.switch", [Config.config.command, target], (stdout, exitCode) => {
            root.busy = false;
            if (exitCode !== 0)
                ToastService.showError(`Could not switch HDR ${target}`);
            PluginService.setGlobalVar("hdrToggle", "refresh", Date.now());
        }, 0);
    }

    ccWidgetIcon: icon
    ccWidgetPrimaryText: "HDR"
    ccWidgetSecondaryText: statusText
    ccWidgetIsActive: hdrOn

    onCcWidgetToggled: toggle()

    // A click switches instead of opening a popout. With the bar's hover
    // popouts turned on, Dux would run this on hover too.
    pillClickAction: () => toggle()

    horizontalBarPill: Component {
        DIcon {
            name: root.icon
            filled: root.hdrOn
            color: root.hdrOn ? Theme.primary : Theme.surfaceVariantText
            size: root.iconSize
        }
    }

    verticalBarPill: Component {
        DIcon {
            name: root.icon
            filled: root.hdrOn
            color: root.hdrOn ? Theme.primary : Theme.surfaceVariantText
            size: root.iconSize
        }
    }
}
