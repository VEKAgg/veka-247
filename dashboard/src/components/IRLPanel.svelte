<script>
  import { onMount } from "svelte";
  import { api } from "$lib/api.js";
  import { irlStatus } from "$lib/stores.js";

  let starting = false;

  onMount(async () => {
    $irlStatus = await api.irl.status();
  });

  async function startIRL() {
    starting = true;
    try {
      await api.irl.start();
      $irlStatus = await api.irl.status();
    } catch (e) {
      alert("Failed to start IRL: " + e.message);
    }
    starting = false;
  }

  async function stopIRL() {
    try {
      await api.irl.stop();
      $irlStatus = { is_live: false, stream_info: null, overlay_active: false };
    } catch (e) {
      alert("Failed to stop IRL: " + e.message);
    }
  }
</script>

<div class="irl-panel">
  <div class="status-row">
    <span class="status-dot" class:live={$irlStatus.is_live}></span>
    <span class="status-text">{$irlStatus.is_live ? "IRL Stream Active" : "No Active Stream"}</span>
  </div>

  {#if $irlStatus.stream_info}
    <div class="stream-info">
      <div><strong>Path:</strong> {$irlStatus.stream_info.name}</div>
      <div><strong>Readers:</strong> {$irlStatus.stream_info.readers}</div>
    </div>
  {/if}

  <div class="actions">
    {#if $irlStatus.is_live}
      <button class="stop-btn" on:click={stopIRL}>Stop Relay</button>
    {:else}
      <button class="start-btn" on:click={startIRL} disabled={starting}>
        {starting ? "Starting..." : "Start IRL Relay"}
      </button>
    {/if}
  </div>

  <div class="instructions">
    <h4>Phone Setup</h4>
    <p>Stream from your phone using Moblin, PRISM, or any RTMP app:</p>
    <code>rtmp://your-server:1935/live/irl</code>
    <p class="note">No stream key required for IRL ingest.</p>
  </div>
</div>

<style>
  .irl-panel { background: #1a1a24; border-radius: 12px; padding: 24px; }
  .status-row { display: flex; align-items: center; gap: 12px; margin-bottom: 16px; }
  .status-dot { width: 12px; height: 12px; border-radius: 50%; background: #333; }
  .status-dot.live { background: #ff4444; box-shadow: 0 0 8px #ff4444; animation: pulse 2s infinite; }
  .status-text { font-size: 16px; font-weight: 600; color: #fff; }
  .stream-info { background: #0f0f13; padding: 12px; border-radius: 8px; margin-bottom: 16px; font-size: 13px; color: #888; }
  .stream-info div { margin-bottom: 4px; }
  .actions { margin-bottom: 24px; }
  .start-btn, .stop-btn { padding: 10px 24px; border: none; border-radius: 8px; font-size: 14px; font-weight: 600; cursor: pointer; }
  .start-btn { background: #22c55e; color: #000; }
  .start-btn:disabled { opacity: 0.5; cursor: not-allowed; }
  .stop-btn { background: #ef4444; color: #fff; }
  .instructions { border-top: 1px solid #2a2a3a; padding-top: 16px; }
  .instructions h4 { font-size: 14px; color: #888; margin-bottom: 8px; }
  .instructions p { font-size: 13px; color: #666; margin-bottom: 8px; }
  .instructions code { display: block; padding: 8px 12px; background: #0f0f13; border-radius: 6px; color: #a78bfa; font-size: 13px; margin-bottom: 8px; }
  .note { font-size: 12px; color: #555; }
  @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.5; } }
</style>
