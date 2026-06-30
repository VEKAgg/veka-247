<script>
  import { onMount, onDestroy } from "svelte";
  import { api } from "$lib/api.js";
  import { channels, irlStatus, runningChannels, totalChannels } from "$lib/stores.js";
  import { addToast } from "$lib/toasts.js";
  import ChannelCard from "../components/ChannelCard.svelte";
  import IRLPanel from "../components/IRLPanel.svelte";

  let loading = true;
  let search = "";
  let ws;
  let lastUpdate = null;

  $: filtered = search
    ? $channels.filter(
        (c) =>
          c.name.toLowerCase().includes(search.toLowerCase()) ||
          (c.description || "").toLowerCase().includes(search.toLowerCase()) ||
          (c.category || "").toLowerCase().includes(search.toLowerCase())
      )
    : $channels;

  onMount(async () => {
    try {
      const [ch, irl] = await Promise.all([api.channels.list(), api.irl.status()]);
      $channels = ch;
      $irlStatus = irl;
      lastUpdate = new Date();
    } catch (e) {
      console.error("Failed to load:", e);
      addToast("Failed to load channels", "error");
    }
    loading = false;

    ws = new WebSocket(`ws://${location.host}/ws/status`);
    ws.onmessage = (e) => {
      const data = JSON.parse(e.data);
      $channels = $channels.map((c) =>
        c.id === data.channel_id ? { ...c, status: data.status, is_live: data.is_live } : c
      );
      lastUpdate = new Date();
    };
    ws.onerror = () => {
      addToast("WebSocket connection lost", "warning");
    };
  });

  onDestroy(() => {
    if (ws) ws.close();
  });

  function formatTime(date) {
    if (!date) return "";
    return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  }
</script>

<div class="dashboard">
  <header>
    <div class="header-left">
      <h1>veka-247</h1>
      <span class="subtitle">streaming dashboard</span>
    </div>
    <div class="header-right">
      <div class="stats">
        <div class="stat">
          <span class="stat-value running">{$runningChannels}</span>
          <span class="stat-label">live</span>
        </div>
        <div class="stat">
          <span class="stat-value">{$totalChannels}</span>
          <span class="stat-label">channels</span>
        </div>
      </div>
      {#if lastUpdate}
        <span class="last-update">Updated {formatTime(lastUpdate)}</span>
      {/if}
    </div>
  </header>

  {#if loading}
    <section class="channels">
      <h2>Channels</h2>
      <div class="channel-grid">
        {#each [1, 2, 3, 4] as _}
          <div class="skeleton-card">
            <div class="sk-header">
              <div class="sk-icon"></div>
              <div class="sk-status"></div>
            </div>
            <div class="sk-title"></div>
            <div class="sk-desc"></div>
            <div class="sk-meta">
              <div class="sk-meta-item"></div>
              <div class="sk-meta-item"></div>
            </div>
          </div>
        {/each}
      </div>
    </section>
  {:else}
    <section class="channels">
      <div class="section-header">
        <h2>Channels</h2>
        {#if $channels.length > 3}
          <div class="search-box">
            <span class="search-icon">🔍</span>
            <input
              type="text"
              placeholder="Search channels..."
              bind:value={search}
            />
          </div>
        {/if}
      </div>
      <div class="channel-grid">
        {#each filtered as channel (channel.id)}
          <ChannelCard {channel} />
        {:else}
          <div class="empty-state">
            {#if search}
              <p>No channels match "{search}"</p>
            {:else}
              <p>No channels configured yet.</p>
            {/if}
          </div>
        {/each}
      </div>
    </section>

    <section class="irl">
      <h2>IRL Relay</h2>
      <IRLPanel />
    </section>
  {/if}
</div>

<style>
  .dashboard { max-width: 1400px; margin: 0 auto; padding: 24px; }
  header {
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    margin-bottom: 36px;
    padding-bottom: 20px;
    border-bottom: 1px solid #1a1a24;
  }
  .header-left { display: flex; align-items: baseline; gap: 12px; }
  h1 { font-size: 28px; font-weight: 700; color: #fff; }
  .subtitle { font-size: 14px; color: #555; }
  .header-right { display: flex; align-items: center; gap: 20px; }
  .stats { display: flex; gap: 20px; }
  .stat { display: flex; flex-direction: column; align-items: center; }
  .stat-value { font-size: 24px; font-weight: 700; color: #a78bfa; }
  .stat-value.running { color: #22c55e; }
  .stat-label { font-size: 11px; color: #555; text-transform: uppercase; letter-spacing: 1px; }
  .last-update { font-size: 11px; color: #444; }
  h2 {
    font-size: 14px;
    font-weight: 600;
    color: #666;
    text-transform: uppercase;
    letter-spacing: 1.5px;
    margin-bottom: 16px;
  }
  .section-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
  .section-header h2 { margin-bottom: 0; }
  .search-box {
    display: flex;
    align-items: center;
    gap: 8px;
    background: #1a1a24;
    border: 1px solid #2a2a3a;
    border-radius: 8px;
    padding: 6px 12px;
  }
  .search-box input {
    background: none;
    border: none;
    color: #e0e0e0;
    font-size: 13px;
    outline: none;
    width: 180px;
  }
  .search-box input::placeholder { color: #555; }
  .search-icon { font-size: 14px; }
  .channel-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
    gap: 16px;
    margin-bottom: 40px;
  }
  section { margin-bottom: 40px; }
  .empty-state { text-align: center; padding: 40px; color: #555; grid-column: 1 / -1; }

  /* Skeleton loading */
  .skeleton-card {
    background: #1a1a24;
    border: 1px solid #2a2a3a;
    border-radius: 12px;
    padding: 20px;
  }
  .sk-header { display: flex; justify-content: space-between; margin-bottom: 12px; }
  .sk-icon { width: 36px; height: 36px; border-radius: 8px; background: #2a2a3a; animation: pulse 1.5s infinite; }
  .sk-status { width: 60px; height: 14px; border-radius: 4px; background: #2a2a3a; animation: pulse 1.5s infinite; }
  .sk-title { width: 70%; height: 20px; border-radius: 4px; background: #2a2a3a; margin-bottom: 8px; animation: pulse 1.5s infinite; }
  .sk-desc { width: 90%; height: 14px; border-radius: 4px; background: #2a2a3a; margin-bottom: 12px; animation: pulse 1.5s infinite; }
  .sk-meta { display: flex; justify-content: space-between; }
  .sk-meta-item { width: 80px; height: 12px; border-radius: 4px; background: #2a2a3a; animation: pulse 1.5s infinite; }
  @keyframes pulse { 0%, 100% { opacity: 0.4; } 50% { opacity: 0.8; } }
</style>
