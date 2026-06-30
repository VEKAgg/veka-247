<script>
  import { onMount } from "svelte";
  import { api } from "$lib/api.js";
  import { irlStatus } from "$lib/stores.js";
  import { addToast } from "$lib/toasts.js";

  let starting = false;
  let rtmpCopied = false;

  onMount(async () => {
    try {
      $irlStatus = await api.irl.status();
    } catch (e) {
      console.error("Failed to fetch IRL status:", e);
    }
  });

  async function startIRL() {
    starting = true;
    try {
      await api.irl.start();
      $irlStatus = await api.irl.status();
      addToast("IRL relay started", "success");
    } catch (e) {
      addToast("Failed to start IRL: " + e.message, "error");
    }
    starting = false;
  }

  async function stopIRL() {
    try {
      await api.irl.stop();
      $irlStatus = { is_live: false, stream_info: null, overlay_active: false };
      addToast("IRL relay stopped", "info");
    } catch (e) {
      addToast("Failed to stop IRL: " + e.message, "error");
    }
  }

  async function copyRtmpUrl() {
    const url = `${location.hostname}:1935/live/irl`;
    try {
      await navigator.clipboard.writeText(`rtmp://${url}`);
      rtmpCopied = true;
      addToast("RTMP URL copied to clipboard", "success");
      setTimeout(() => (rtmpCopied = false), 2000);
    } catch {
      addToast("Failed to copy", "error");
    }
  }
</script>

<div class="irl-panel">
  <div class="status-row">
    <span class="status-dot" class:live={$irlStatus.is_live}></span>
    <span class="status-text">{$irlStatus.is_live ? "IRL Stream Active" : "No Active Stream"}</span>
    {#if $irlStatus.is_live}
      <span class="live-badge">LIVE</span>
    {/if}
  </div>

  {#if $irlStatus.stream_info}
    <div class="stream-info">
      <div class="info-row">
        <span class="info-label">Path</span>
        <span class="info-value">{$irlStatus.stream_info.name}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Readers</span>
        <span class="info-value">{$irlStatus.stream_info.readers}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Ready</span>
        <span class="info-value" class:ready={$irlStatus.stream_info.ready}>
          {$irlStatus.stream_info.ready ? "Yes" : "No"}
        </span>
      </div>
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
    <div class="rtmp-url-row">
      <code>rtmp://{location.hostname}:1935/live/irl</code>
      <button class="copy-btn" on:click={copyRtmpUrl} title="Copy to clipboard">
        {rtmpCopied ? "✓" : "📋"}
      </button>
    </div>
    <p class="note">No stream key required for IRL ingest.</p>
  </div>
</div>

<style>
  .irl-panel {
    background: #1a1a24;
    border: 1px solid #2a2a3a;
    border-radius: 12px;
    padding: 24px;
  }
  .status-row {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 16px;
  }
  .status-dot {
    width: 12px;
    height: 12px;
    border-radius: 50%;
    background: #333;
    transition: all 0.3s;
  }
  .status-dot.live {
    background: #ef4444;
    box-shadow: 0 0 12px #ef4444;
    animation: pulse 2s infinite;
  }
  .status-text { font-size: 16px; font-weight: 600; color: #fff; }
  .live-badge {
    font-size: 10px;
    font-weight: 700;
    color: #fff;
    background: #ef4444;
    padding: 2px 8px;
    border-radius: 4px;
    letter-spacing: 1px;
    animation: pulse 2s infinite;
  }
  .stream-info {
    background: #0f0f13;
    padding: 14px;
    border-radius: 8px;
    margin-bottom: 16px;
    border: 1px solid #1a1a24;
  }
  .info-row {
    display: flex;
    justify-content: space-between;
    padding: 4px 0;
  }
  .info-label { font-size: 12px; color: #666; }
  .info-value { font-size: 13px; color: #aaa; font-family: monospace; }
  .info-value.ready { color: #22c55e; }
  .actions { margin-bottom: 24px; }
  .start-btn, .stop-btn {
    padding: 10px 24px;
    border: none;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
  }
  .start-btn {
    background: #22c55e;
    color: #000;
  }
  .start-btn:hover:not(:disabled) { background: #16a34a; }
  .start-btn:disabled { opacity: 0.5; cursor: not-allowed; }
  .stop-btn {
    background: #ef4444;
    color: #fff;
  }
  .stop-btn:hover { background: #dc2626; }
  .instructions {
    border-top: 1px solid #2a2a3a;
    padding-top: 16px;
  }
  .instructions h4 { font-size: 14px; color: #888; margin-bottom: 8px; }
  .instructions p { font-size: 13px; color: #666; margin-bottom: 10px; }
  .rtmp-url-row {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 10px;
  }
  .rtmp-url-row code {
    flex: 1;
    display: block;
    padding: 10px 14px;
    background: #0f0f13;
    border: 1px solid #1a1a24;
    border-radius: 6px;
    color: #a78bfa;
    font-size: 13px;
    font-family: 'SF Mono', 'Fira Code', monospace;
  }
  .copy-btn {
    padding: 8px 12px;
    border: 1px solid #2a2a3a;
    background: #1a1a24;
    color: #888;
    border-radius: 6px;
    cursor: pointer;
    font-size: 14px;
    transition: all 0.2s;
  }
  .copy-btn:hover { border-color: #a78bfa; color: #a78bfa; }
  .note { font-size: 12px; color: #444; }
  @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.5; } }
</style>
