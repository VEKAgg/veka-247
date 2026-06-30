<script>
  import { onMount } from "svelte";
  import { api } from "$lib/api.js";
  import { addToast } from "$lib/toasts.js";

  export let channel;

  let configs = [];
  let templates = [];
  let loading = true;
  let testing = null;

  const alertTypes = [
    { id: "donation", icon: "💰", color: "#FFD700" },
    { id: "follow", icon: "💜", color: "#9146FF" },
    { id: "subscription", icon: "🟢", color: "#00AD03" },
    { id: "raid", icon: "🔥", color: "#FF4500" },
    { id: "cheer", icon: "⭐", color: "#FF6B00" },
  ];

  onMount(async () => {
    try {
      [configs, templates] = await Promise.all([
        api.alerts.listConfig(channel.id),
        api.alerts.templates(),
      ]);
    } catch (e) {
      console.error(e);
    }
    loading = false;
  });

  async function toggleAlert(config) {
    try {
      await api.alerts.updateConfig(channel.id, config.id, { is_enabled: !config.is_enabled });
      configs = configs.map((c) => (c.id === config.id ? { ...c, is_enabled: !c.is_enabled } : c));
      addToast(`${config.type} ${config.is_enabled ? "disabled" : "enabled"}`, "info");
    } catch (e) {
      addToast("Failed to toggle alert: " + e.message, "error");
    }
  }

  async function testAlert(type) {
    testing = type;
    try {
      await api.alerts.test(channel.id, {
        type,
        name: "TestUser",
        amount: 4.20,
        message: "This is a test alert!",
        duration: 5,
      });
      addToast(`Test ${type} alert sent`, "success");
    } catch (e) {
      addToast("Test failed: " + e.message, "error");
    }
    testing = null;
  }
</script>

<div class="alert-config">
  {#if loading}
    <div class="loading-skeleton">
      {#each [1, 2, 3] as _}
        <div class="sk-row"></div>
      {/each}
    </div>
  {:else}
    <div class="alert-list">
      {#each alertTypes as alertType}
        {@const config = configs.find((c) => c.type === alertType.id)}
        <div class="alert-row" class:enabled={config?.is_enabled}>
          <span class="alert-icon">{alertType.icon}</span>
          <span class="alert-type" style="color: {alertType.color}">{alertType.id}</span>
          <div class="alert-spacer"></div>
          {#if config}
            <button class="toggle-btn" class:active={config.is_enabled} on:click={() => toggleAlert(config)}>
              {config.is_enabled ? "Enabled" : "Disabled"}
            </button>
          {:else}
            <span class="not-configured">Not configured</span>
          {/if}
          <button
            class="test-btn"
            on:click={() => testAlert(alertType.id)}
            disabled={testing === alertType.id}
          >
            {testing === alertType.id ? "Sending..." : "Test"}
          </button>
        </div>
      {/each}
    </div>

    <div class="webhook-info">
      <h3>Webhook URLs</h3>
      <p>Add these to your Streamlabs/StreamElements dashboard:</p>
      <div class="webhook-url">
        <span class="webhook-label">Streamlabs</span>
        <code>{location.origin}/api/alerts/{channel.id}/webhook/streamlabs</code>
      </div>
      <div class="webhook-url">
        <span class="webhook-label">StreamElements</span>
        <code>{location.origin}/api/alerts/{channel.id}/webhook/streamelements</code>
      </div>
    </div>
  {/if}
</div>

<style>
  .alert-config { width: 100%; }
  .alert-list { display: flex; flex-direction: column; gap: 8px; margin-bottom: 24px; }
  .alert-row {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 14px 16px;
    background: #1a1a24;
    border: 1px solid #2a2a3a;
    border-radius: 8px;
    transition: border-color 0.2s;
  }
  .alert-row:hover { border-color: #3a3a4a; }
  .alert-row.enabled { border-left: 3px solid #22c55e; }
  .alert-icon { font-size: 18px; }
  .alert-type {
    font-weight: 600;
    text-transform: capitalize;
    min-width: 100px;
    font-size: 14px;
  }
  .alert-spacer { flex: 1; }
  .toggle-btn {
    padding: 5px 14px;
    border: 1px solid #2a2a3a;
    border-radius: 6px;
    font-size: 12px;
    cursor: pointer;
    background: transparent;
    color: #888;
    transition: all 0.2s;
  }
  .toggle-btn.active { background: rgba(34,197,94,0.1); color: #22c55e; border-color: rgba(34,197,94,0.3); }
  .not-configured { color: #444; font-size: 13px; }
  .test-btn {
    padding: 5px 14px;
    border: 1px solid #a78bfa33;
    background: transparent;
    color: #a78bfa;
    border-radius: 6px;
    cursor: pointer;
    font-size: 12px;
    transition: all 0.2s;
  }
  .test-btn:hover:not(:disabled) { background: rgba(167,139,250,0.1); border-color: #a78bfa; }
  .test-btn:disabled { opacity: 0.5; cursor: not-allowed; }
  .webhook-info {
    background: #1a1a24;
    border: 1px solid #2a2a3a;
    padding: 20px;
    border-radius: 12px;
  }
  .webhook-info h3 { font-size: 16px; color: #fff; margin-bottom: 8px; }
  .webhook-info p { font-size: 13px; color: #888; margin-bottom: 12px; }
  .webhook-url {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 10px 14px;
    background: #0f0f13;
    border: 1px solid #1a1a24;
    border-radius: 6px;
    margin-bottom: 8px;
  }
  .webhook-label {
    font-size: 12px;
    font-weight: 600;
    color: #888;
    min-width: 110px;
  }
  .webhook-url code {
    font-size: 12px;
    color: #a78bfa;
    word-break: break-all;
    font-family: 'SF Mono', 'Fira Code', monospace;
  }
  .loading-skeleton { display: flex; flex-direction: column; gap: 8px; }
  .sk-row { height: 52px; border-radius: 8px; background: #1a1a24; animation: pulse 1.5s infinite; }
  @keyframes pulse { 0%, 100% { opacity: 0.4; } 50% { opacity: 0.8; } }
</style>
