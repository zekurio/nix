.pragma library

function hashrate(value) {
    if (!value)
        return "0 H/s";
    if (value >= 1e6)
        return (value / 1e6).toFixed(1) + " MH/s";
    if (value >= 1e3)
        return (value / 1e3).toFixed(1) + " kH/s";
    return Math.round(value) + " H/s";
}

// The bar has no room for the unit's "/s".
function hashrateShort(value) {
    if (value >= 1e6)
        return (value / 1e6).toFixed(1) + "M";
    if (value >= 1e3)
        return (value / 1e3).toFixed(1) + "k";
    return Math.round(value || 0).toString();
}

function xmr(value) {
    return (value || 0).toFixed(value >= 0.01 ? 4 : 6) + " XMR";
}

function eur(value) {
    return "€" + (value || 0).toFixed(2);
}

function minerLine(miner) {
    if (miner.active) {
        if (!miner.algo)
            return "Starting";
        return miner.algo + " · " + hashrate(miner.hashrate) + " · " + miner.shares + " shares";
    }
    if (miner.paused)
        return "Paused for a game";
    if (miner.state === "failed")
        return "Failed, see journalctl -u xmrig-" + miner.id;
    if (miner.state === "activating")
        return "Starting";
    return "Off";
}
