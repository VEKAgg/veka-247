<script>
  import { onMount } from "svelte";
  import { api } from "$lib/api.js";

  export let channel;

  let configs = [];
  let templates = [];
  let loading = true;

  const alertTypes = ["donation", "follow", "subscription", "raid", "cheer"];

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
    await api.alerts.updateConfig(channel.id, config.id, { is_enabled: !config.is_enabled });
    configs = configs.map((c) => (c.id === config.id ? { ...c, is_enabled: !c.is_enabled } : c));
  }

  async function testAlert(type) {
    try {
      await api.alerts.test(channel.id, {
        type,
        name: "TestUser",
        amount: 4.20,
        message: "This is a test alert!",
        duration: 5,
      });
    } catch (e) {
      alert("Test failed: " + e.message);
    }
  }
</script>

<div class="alert-config">
  {#if loading}
    <p class="loading">Loading alerts...</p>
  {:else}
    <div class="alert-list">
      {#each alertTypes as type}
        {@const config = configs.find((c) => c.type === type)}
        <div class="alert-row" class:enabled={config?.is_enabled}>
          <span class="alert-type">{type}</span>
          {#if config}
            <button class="toggle-btn" on:click={() => toggleAlert(config)}>
              {config.is_enabled ? "Enabled" : "Disabled"}
            </button>
          {:else}
            <span class="not-configured">Not configured</span>
          {/if}
          <button class="test-btn" on:click={() => testAlert(type)}>Test</button>
        </div>
      {/each}
    </div>

    <div class="webhook-info">
      <h3>Webhook URLs</h3>
      <p>Add these to your Streamlabs/StreamElements dashboard:</p>
      <div class="webhook-url">
        <code>Streamlabs: {location.origin}/api/alerts/{channel.id}/webhook/streamlabs</code>
      </div>
      <div class="webhook-url">
        <code>StreamElements: {location.origin}/api/alerts/{channel.id}/webhook/streamelements</code>
      </div>
    </div>
  {/if}
</div>

<style>
  .alert-config { width: 100%; }
  .alert-list { display: flex; flex-direction: column; gap: 8px; margin-bottom: 24px; }
  .alert-row {
    display: flex; align-items: center; gap: 16px;
    padding: 12px 16px; background: #1a1a24; border-radius: 8px;
  }
  .alert-row.enabled { border-left: 3px solid #22c55e; }
  .alert-type { font-weight: 600; color: #fff; text-transform: capitalize; min-width: 120px; }
  .toggle-btn { padding: 4px 12px; border: none; border-radius: 4px; font-size: 12px; cursor: pointer; background: #22c55e; color: #000; }
  .not-configured { color: #555; font-size: 13px; }
  .test-btn { padding: 4px 12px; border: 1px solid #a78bfa; background: none; color: #a78bfa; border-radius: 4px; cursor: pointer; font-size: 12px; }
  .test-btn:hover { background: #a78bfa; color: #000; }
  .webhook-info { background: #1a1a24; padding: 20px; border-radius: 12px; }
  .webhook-info h3 { font-size: 16px; color: #fff; margin-bottom: 8px; }
  .webhook-info p { font-size: 13px; color: #888; margin-bottom: 12px; }
  .webhook-url { padding: 8px 12px; background: #0f0f13; border-radius: 6px; margin-bottom: 8px; }
  .webhook-url code { font-size: 12px; color: #a78bfa; word-break: break-all; }
  .loading { text-align: center; padding: 24px; color: #666; }
</style>
