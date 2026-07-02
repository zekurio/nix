import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

const STATUS_KEY = "fast-transport";

type FastVariant = {
  /** Provider id as exposed by ctx.model.provider. */
  provider: string;
  /** Human-readable target name for notifications. */
  label: string;
  /** Provider payload fields to add when fast mode is enabled. */
  payload: Record<string, unknown>;
};

const FAST_VARIANTS: FastVariant[] = [
  {
    provider: "openai",
    label: "OpenAI/Codex OAuth priority service tier",
    payload: {service_tier: "priority"},
  },
  {
    provider: "openai-codex",
    label: "Codex OAuth priority service tier",
    payload: {service_tier: "priority"},
  },
];

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function variantFor(ctx: ExtensionContext): FastVariant | undefined {
  const provider = ctx.model?.provider;
  return FAST_VARIANTS.find((variant) => variant.provider === provider);
}

function modelName(ctx: ExtensionContext): string {
  return ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "no active model";
}

function formatTokens(count: number): string {
  if (count < 1000) return count.toString();
  if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
  if (count < 1000000) return `${Math.round(count / 1000)}k`;
  if (count < 10000000) return `${(count / 1000000).toFixed(1)}M`;
  return `${Math.round(count / 1000000)}M`;
}

function sanitizeStatusText(text: string): string {
  return text.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim();
}

export default function fastExtension(pi: ExtensionAPI): void {
  let enabled = true;

  function installFooter(ctx: ExtensionContext): void {
    if (!ctx.hasUI) return;

    ctx.ui.setFooter((_tui, theme, footerData) => ({
      invalidate() {},
      render(width: number): string[] {
        let totalInput = 0;
        let totalOutput = 0;
        let totalCacheRead = 0;
        let totalCacheWrite = 0;
        let totalCost = 0;

        for (const entry of ctx.sessionManager.getEntries()) {
          if (entry.type === "message" && entry.message.role === "assistant") {
            totalInput += entry.message.usage.input;
            totalOutput += entry.message.usage.output;
            totalCacheRead += entry.message.usage.cacheRead;
            totalCacheWrite += entry.message.usage.cacheWrite;
            totalCost += entry.message.usage.cost.total;
          }
        }

        const contextUsage = ctx.getContextUsage();
        const contextWindow = contextUsage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
        const contextPercentValue = contextUsage?.percent ?? 0;
        const contextPercent = contextUsage?.percent !== null ? contextPercentValue.toFixed(1) : "?";
        const contextPercentDisplay =
          contextPercent === "?" ? `?/${formatTokens(contextWindow)} (auto)` : `${contextPercent}%/${formatTokens(contextWindow)} (auto)`;

        let pwd = ctx.cwd;
        const home = process.env.HOME || process.env.USERPROFILE;
        if (home && pwd.startsWith(home)) pwd = `~${pwd.slice(home.length)}`;

        const branch = footerData.getGitBranch();
        if (branch) pwd = `${pwd} (${branch})`;

        const sessionName = pi.getSessionName();
        if (sessionName) pwd = `${pwd} • ${sessionName}`;

        const statsParts: string[] = [];
        if (totalInput) statsParts.push(`↑${formatTokens(totalInput)}`);
        if (totalOutput) statsParts.push(`↓${formatTokens(totalOutput)}`);
        if (totalCacheRead) statsParts.push(`R${formatTokens(totalCacheRead)}`);
        if (totalCacheWrite) statsParts.push(`W${formatTokens(totalCacheWrite)}`);

        const usingSubscription = ctx.model ? ctx.modelRegistry.isUsingOAuth(ctx.model) : false;
        if (totalCost || usingSubscription) statsParts.push(`$${totalCost.toFixed(3)}${usingSubscription ? " (sub)" : ""}`);
        statsParts.push(contextPercentDisplay);

        let statsLeft = statsParts.join(" ");
        let statsLeftWidth = visibleWidth(statsLeft);
        if (statsLeftWidth > width) {
          statsLeft = truncateToWidth(statsLeft, width, "...");
          statsLeftWidth = visibleWidth(statsLeft);
        }

        const modelSlug = `${ctx.model?.id || "no-model"}${enabled ? " fast" : ""}`;
        let rightSideWithoutProvider = modelSlug;
        if (ctx.model?.reasoning) {
          const thinkingLevel = pi.getThinkingLevel();
          rightSideWithoutProvider = thinkingLevel === "off" ? `${modelSlug} • thinking off` : `${modelSlug} • ${thinkingLevel}`;
        }

        let rightSide = rightSideWithoutProvider;
        if (footerData.getAvailableProviderCount() > 1 && ctx.model) {
          const withProvider = `(${ctx.model.provider}) ${rightSideWithoutProvider}`;
          if (statsLeftWidth + 2 + visibleWidth(withProvider) <= width) rightSide = withProvider;
        }

        const rightSideWidth = visibleWidth(rightSide);
        const totalNeeded = statsLeftWidth + 2 + rightSideWidth;
        let statsLine: string;
        if (totalNeeded <= width) {
          statsLine = statsLeft + " ".repeat(width - statsLeftWidth - rightSideWidth) + rightSide;
        } else {
          const availableForRight = width - statsLeftWidth - 2;
          if (availableForRight > 0) {
            const truncatedRight = truncateToWidth(rightSide, availableForRight, "");
            statsLine = statsLeft + " ".repeat(Math.max(0, width - statsLeftWidth - visibleWidth(truncatedRight))) + truncatedRight;
          } else {
            statsLine = statsLeft;
          }
        }

        const lines = [
          truncateToWidth(theme.fg("dim", pwd), width, theme.fg("dim", "...")),
          theme.fg("dim", statsLine),
        ];

        const extensionStatuses = footerData.getExtensionStatuses();
        if (extensionStatuses.size > 0) {
          const statusLine = Array.from(extensionStatuses.entries())
            .filter(([key]) => key !== STATUS_KEY)
            .sort(([a], [b]) => a.localeCompare(b))
            .map(([, text]) => sanitizeStatusText(text))
            .join(" ");
          if (statusLine) lines.push(truncateToWidth(statusLine, width, theme.fg("dim", "...")));
        }

        return lines;
      },
    }));
  }

  function updateStatus(ctx: ExtensionContext): void {
    if (!ctx.hasUI) return;
    ctx.ui.setStatus(STATUS_KEY, undefined);
    installFooter(ctx);
  }

  function setEnabled(next: boolean, ctx: ExtensionContext, notify = true): void {
    enabled = next;
    updateStatus(ctx);

    if (!notify || !ctx.hasUI) return;
    if (!enabled) {
      ctx.ui.notify("Fast mode disabled.", "info");
      return;
    }

    const variant = variantFor(ctx);
    if (variant) {
      ctx.ui.notify(`Fast mode enabled for ${variant.label}.`, "info");
    } else {
      ctx.ui.notify(`Fast mode enabled, but no fast variant is mapped for ${modelName(ctx)}.`, "info");
    }
  }

  pi.registerFlag("fast", {
    description: "Start with fast transport enabled for mapped providers",
    type: "boolean",
    default: true,
  });

  function toggleFast(ctx: ExtensionContext): void {
    setEnabled(!enabled, ctx);
  }

  pi.registerShortcut("ctrl+f", {
    description: "Toggle fast transport",
    handler: async (ctx) => {
      toggleFast(ctx);
    },
  });

  pi.registerCommand("fast", {
    description: "Toggle fast transport for mapped providers; accepts on/off/status",
    handler: async (args, ctx) => {
      const arg = args.trim().toLowerCase();
      if (arg === "on" || arg === "enable" || arg === "enabled") {
        setEnabled(true, ctx);
      } else if (arg === "off" || arg === "disable" || arg === "disabled") {
        setEnabled(false, ctx);
      } else if (arg === "status") {
        const variant = variantFor(ctx);
        const target = variant ? variant.label : `no mapping for ${modelName(ctx)}`;
        ctx.ui.notify(`Fast mode is ${enabled ? "enabled" : "disabled"}; target: ${target}.`, "info");
      } else if (arg === "") {
        toggleFast(ctx);
      } else {
        ctx.ui.notify("Usage: /fast [on|off|status]", "warning");
      }
    },
  });

  pi.on("session_start", (_event, ctx) => {
    if (pi.getFlag("fast") === true) enabled = true;
    installFooter(ctx);
  });

  pi.on("session_switch", (_event, ctx) => {
    if (pi.getFlag("fast") === true) enabled = true;
    installFooter(ctx);
  });

  pi.on("model_select", (_event, ctx) => {
    updateStatus(ctx);
  });

  pi.on("thinking_level_select", (_event, ctx) => {
    updateStatus(ctx);
  });

  pi.on("before_provider_request", (event, ctx) => {
    if (!enabled || !isRecord(event.payload)) return;

    const variant = variantFor(ctx);
    if (!variant) return;

    const nextPayload = {...event.payload};
    let changed = false;

    for (const [key, value] of Object.entries(variant.payload)) {
      if (Object.prototype.hasOwnProperty.call(nextPayload, key)) continue;
      nextPayload[key] = value;
      changed = true;
    }

    return changed ? nextPayload : undefined;
  });
}
