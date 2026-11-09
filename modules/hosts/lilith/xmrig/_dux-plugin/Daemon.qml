import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins
import "Config.js" as Config

// Polls the miners and the pool once for every bar, screen and control
// center instance, and shares the result as the "state" global variable.
PluginComponent {
    id: root

    readonly property string pid: "xmrigControl"
    readonly property var cfg: Config.config

    property var units: ({})
    property var summaries: ({})
    property var poolStats: null
    property var minerStats: null
    property int ticks: 0
    property var published: null

    // `dms ipc call xmrigControl status` prints what the widgets show.
    IpcHandler {
        target: "xmrigControl"

        function status(): string {
            return JSON.stringify(root.published);
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }

    // The widgets bump "refresh" after starting or stopping a miner.
    Connections {
        target: PluginService
        function onGlobalVarChanged(pluginId, varName) {
            if (pluginId === root.pid && varName === "refresh")
                root.poll();
        }
    }

    function getJson(url, done) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let data = null;
            if (xhr.status === 200) {
                try {
                    data = JSON.parse(xhr.responseText);
                } catch (e) {
                    data = null;
                }
            }
            done(data);
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function poll() {
        Proc.runCommand("xmrigControl.status", [cfg.status], (stdout, exitCode) => {
            const units = {};
            for (const line of stdout.trim().split("\n")) {
                const [id, state, paused] = line.split(" ");
                if (id)
                    units[id] = {
                        "state": state,
                        "paused": paused === "1"
                    };
            }
            root.units = units;
            root.publish();
        }, 0);

        for (const miner of cfg.miners) {
            const id = miner.id;
            getJson(`http://127.0.0.1:${miner.apiPort}/2/summary`, data => {
                const summaries = Object.assign({}, root.summaries);
                summaries[id] = data;
                root.summaries = summaries;
                root.publish();
            });
        }

        // The pool updates its profit figures and balances every few minutes.
        if (ticks % 12 === 0) {
            getJson(`${cfg.poolApi}/pool/stats`, data => {
                if (data) {
                    root.poolStats = data.pool_statistics;
                    root.publish();
                }
            });
            getJson(`${cfg.poolApi}/miner/${cfg.address}/stats`, data => {
                if (data) {
                    root.minerStats = data;
                    root.publish();
                }
            });
        }
        ticks += 1;
    }

    // XMR per day for one H/s of the given algorithm, from the coin that pays
    // best on it. MoneroOcean switches each miner to that coin.
    function profitPerHash(algo) {
        if (!poolStats || !algo)
            return 0;
        let best = 0;
        for (const port in poolStats.coins) {
            const coin = poolStats.coins[port];
            if (coin.algo === algo && coin.active !== false)
                best = Math.max(best, poolStats.coinProfit[port] || 0);
        }
        return best;
    }

    function publish() {
        const miners = cfg.miners.map(miner => {
            const unit = units[miner.id] || {
                "state": "unknown",
                "paused": false
            };
            const active = unit.state === "active";
            const summary = active ? summaries[miner.id] : null;
            const total = summary?.hashrate?.total ?? [];
            const rate = total[1] ?? total[0] ?? 0;
            const algo = summary?.algo ?? "";
            return {
                "id": miner.id,
                "label": miner.label,
                "state": unit.state,
                "active": active,
                "paused": !active && unit.paused,
                "algo": algo,
                "hashrate": rate,
                "shares": summary?.results?.shares_good ?? 0,
                "xmrPerDay": rate * profitPerHash(algo)
            };
        });

        const xmrPerDay = miners.reduce((sum, m) => sum + m.xmrPerDay, 0);
        const price = poolStats?.price?.eur ?? 0;
        published = {
            "miners": miners,
            "pool": poolStats ? {
                "xmrPerDay": xmrPerDay,
                "eurPerDay": xmrPerDay * price,
                "price": price,
                "pending": (minerStats?.amtDue ?? 0) / 1e12,
                "paid": (minerStats?.amtPaid ?? 0) / 1e12
            } : null
        };
        PluginService.setGlobalVar(pid, "state", published);
    }
}
