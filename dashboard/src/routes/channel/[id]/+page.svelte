<script>
  import { onMount } from "svelte";
  import { page } from "$app/stores";
  import { api } from "$lib/api.js";
  import { addToast } from "$lib/toasts.js";
  import StreamPreview from "../../../components/StreamPreview.svelte";
  import ClipManager from "../../../components/ClipManager.svelte";
  import PlatformForm from "../../../components/PlatformForm.svelte";
  import AlertConfig from "../../../components/AlertConfig.svelte";

  let channel = null;
  let platforms = [];
  let clips = [];
  let loading = true;
  let activeTab = "preview";
  let toggling = false;

  $: slug = $page.params.id;

  const tabs = [
    { id: "preview", label: "Preview", icon: "📺" },
    { id: "clips", label: "Clips", icon: "🎬" },
    { id: "platforms", label: "Platforms", icon: "📡" },
    { id: "alerts", label: "Alerts", icon: "🔔" },
  ];

  onMount(async () => {
    try {
      channel = await api.channels.get(slug);
      [platforms, clips] = await Promise.all([
        api.platforms.list(channel.id),
        api.clips.list(channel.id),
      ]);
    } catch (e) {
      console.error("Failed to load channel:", e);
      addToast("Failed to load channel", "error");
    }
    loading = false;
  });

  async function toggleStream() {
    if (!channel || toggling) return;
    toggling = true;
    try {
      if (channel.status === "running") {
        await api.channels.stop(channel.id);
        channel = { ...channel, status: "stopped", process_pid: null };
        addToast(`${channel.name} stopped`, "info");
      } else {
        await api.channels.start(channel.id);
        channel = { ...channel, status: "starting" };
        addToast(`${channel.name} starting...`, "info");
      }
    } catch (e) {
      addToast("Failed: " + e.message, "error");
    }
    toggling = false;
  }

  const statusColors = {
    running: "#22c55e",
    stopped: "#555",
    starting: "#f59e0b",
    error: "#ef4444",
  };
</script>

{#if loading}
  <div class="detail-page">
    <div class="skeleton-header">
      <div class="sk-back"></div>
      <div class="sk-title"></div>
      <div class="sk-btn"></div>
    </div>
    <div class="skeleton-tabs">
      {#each [1, 2, 3, 4] as _}
        <div class="sk-tab"></div>
      {/each}
    </div>
    <div class="skeleton-content"></div>
  </div>
{:else if channel}
  <div class="detail-page">
    <header>
      <nav class="breadcrumb">
        <a href="/">← Channels</a>
        <span class="sep">/</span>
        <span class="current">{channel.name}</span>
      </nav>
      <div class="header-actions">
        <span class="status-indicator" style="color: {statusColors[channel.status] || '#555'}">
          <span class="status-dot" style="background: {statusColors[channel.status] || '#555'}"></span>
          {channel.status}
        </span>
        <button
          class="btn-toggle"
          class:running={channel.status === "running"}
          class:starting={channel.status === "starting"}
          on:click={toggleStream}
          disabled={toggling || channel.status === "starting"}
        >
          {#if channel.status === "running"}
            Stop Stream
          {:else if channel.status === "starting"}
            Starting...
          {:else}
            Start Stream
          {/if}
        </button>
      </div>
    </header>

    <nav class="tabs">
      {#each tabs as tab}
        <button
          class:active={activeTab === tab.id}
          on:click={() => (activeTab = tab.id)}
        >
          <span class="tab-icon">{tab.icon}</span>
          {tab.label}
        </button>
      {/each}
    </nav>

    <div class="content">
      {#if activeTab === "preview"}
        <StreamPreview {channel} />
      {:else if activeTab === "clips"}
        <ClipManager {channel} bind:clips />
      {:else if activeTab === "platforms"}
        <PlatformForm {channel} bind:platforms />
      {:else if activeTab === "alerts"}
        <AlertConfig {channel} />
      {/if}
    </div>
  </div>
{/if}

<style>
  .detail-page { max-width: 1200px; margin: 0 auto; padding: 24px; }
  header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 24px;
  }
  .breadcrumb {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 14px;
  }
  .breadcrumb a {
    color: #666;
    text-decoration: none;
    transition: color 0.2s;
  }
  .breadcrumb a:hover { color: #a78bfa; }
  .sep { color: #333; }
  .current { color: #fff; font-weight: 600; }
  .header-actions { display: flex; align-items: center; gap: 16px; }
  .status-indicator {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 13px;
    font-weight: 600;
    text-transform: capitalize;
  }
  .status-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
  }
  .status-dot[style*="running"] {
    box-shadow: 0 0 8px #22c55e;
    animation: pulse-dot 2s infinite;
  }
  .btn-toggle {
    padding: 10px 28px;
    border: none;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    background: #22c55e;
    color: #000;
  }
  .btn-toggle:hover:not(:disabled) { filter: brightness(0.9); }
  .btn-toggle.running { background: #ef4444; color: #fff; }
  .btn-toggle.starting { background: #f59e0b; color: #000; cursor: wait; }
  .btn-toggle:disabled { opacity: 0.6; cursor: not-allowed; }
  .tabs {
    display: flex;
    gap: 4px;
    margin-bottom: 24px;
    border-bottom: 1px solid #1a1a24;
    padding-bottom: 0;
  }
  .tabs button {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 10px 20px;
    border: none;
    background: none;
    color: #666;
    font-size: 14px;
    cursor: pointer;
    border-bottom: 2px solid transparent;
    margin-bottom: -1px;
    transition: all 0.2s;
  }
  .tabs button:hover { color: #ccc; }
  .tabs button.active { color: #a78bfa; border-bottom-color: #a78bfa; }
  .tab-icon { font-size: 15px; }
  .content { min-height: 400px; }

  /* Skeleton */
  .skeleton-header { display: flex; align-items: center; gap: 16px; margin-bottom: 24px; }
  .sk-back { width: 100px; height: 16px; border-radius: 4px; background: #2a2a3a; animation: pulse 1.5s infinite; }
  .sk-title { width: 200px; height: 28px; border-radius: 4px; background: #2a2a3a; animation: pulse 1.5s infinite; }
  .sk-btn { width: 120px; height: 40px; border-radius: 8px; background: #2a2a3a; animation: pulse 1.5s infinite; }
  .skeleton-tabs { display: flex; gap: 8px; margin-bottom: 24px; }
  .sk-tab { width: 100px; height: 38px; border-radius: 6px; background: #2a2a3a; animation: pulse 1.5s infinite; }
  .skeleton-content { width: 100%; height: 400px; border-radius: 12px; background: #1a1a24; animation: pulse 1.5s infinite; }
  @keyframes pulse { 0%, 100% { opacity: 0.4; } 50% { opacity: 0.8; } }
  @keyframes pulse-dot { 0%, 100% { opacity: 1; } 50% { opacity: 0.4; } }
</style>
