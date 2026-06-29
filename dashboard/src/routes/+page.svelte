<script>
  import { onMount } from "svelte";
  import { api } from "$lib/api.js";
  import { channels, irlStatus, runningChannels, totalChannels } from "$lib/stores.js";
  import ChannelCard from "../components/ChannelCard.svelte";
  import IRLPanel from "../components/IRLPanel.svelte";

  let loading = true;

  onMount(async () => {
    try {
      const [ch, irl] = await Promise.all([api.channels.list(), api.irl.status()]);
      $channels = ch;
      $irlStatus = irl;
    } catch (e) {
      console.error("Failed to load:", e);
    }
    loading = false;

    const ws = new WebSocket(`ws://${location.host}/ws/status`);
    ws.onmessage = (e) => {
      const data = JSON.parse(e.data);
      $channels = $channels.map((c) =>
        c.id === data.channel_id ? { ...c, status: data.status, is_live: data.is_live } : c
      );
    };
  });
</script>

<div class="dashboard">
  <header>
    <h1>veka-247</h1>
    <div class="stats">
      <span class="stat">
        <span class="stat-value">{$runningChannels}</span>
        <span class="stat-label">running</span>
      </span>
      <span class="stat">
        <span class="stat-value">{$totalChannels}</span>
        <span class="stat-label">channels</span>
      </span>
    </div>
  </header>

  {#if loading}
    <div class="loading">Loading channels...</div>
  {:else}
    <section class="channels">
      <h2>Channels</h2>
      <div class="channel-grid">
        {#each $channels as channel (channel.id)}
          <ChannelCard {channel} />
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
  header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 32px; }
  h1 { font-size: 28px; font-weight: 700; color: #fff; }
  h2 { font-size: 18px; font-weight: 600; color: #888; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 16px; }
  .stats { display: flex; gap: 24px; }
  .stat { display: flex; flex-direction: column; align-items: center; }
  .stat-value { font-size: 24px; font-weight: 700; color: #a78bfa; }
  .stat-label { font-size: 12px; color: #666; text-transform: uppercase; }
  .loading { text-align: center; padding: 60px; color: #666; }
  .channel-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 16px; margin-bottom: 40px; }
  section { margin-bottom: 40px; }
</style>
