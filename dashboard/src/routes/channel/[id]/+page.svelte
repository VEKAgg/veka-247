<script>
  import { onMount } from "svelte";
  import { page } from "$app/stores";
  import { api } from "$lib/api.js";
  import StreamPreview from "./StreamPreview.svelte";
  import ClipManager from "./ClipManager.svelte";
  import PlatformForm from "./PlatformForm.svelte";
  import AlertConfig from "./AlertConfig.svelte";

  let channel = null;
  let platforms = [];
  let clips = [];
  let loading = true;
  let activeTab = "preview";

  $: slug = $page.params.id;

  onMount(async () => {
    try {
      channel = await api.channels.get(slug);
      [platforms, clips] = await Promise.all([
        api.platforms.list(channel.id),
        api.clips.list(channel.id),
      ]);
    } catch (e) {
      console.error("Failed to load channel:", e);
    }
    loading = false;
  });

  async function toggleStream() {
    if (!channel) return;
    if (channel.status === "running") {
      await api.channels.stop(channel.id);
      channel = { ...channel, status: "stopped", process_pid: null };
    } else {
      await api.channels.start(channel.id);
      channel = { ...channel, status: "starting" };
    }
  }
</script>

{#if loading}
  <div class="loading">Loading channel...</div>
{:else if channel}
  <div class="channel-detail">
    <header>
      <a href="/" class="back">&larr; Back</a>
      <h1>{channel.name}</h1>
      <button class="btn-toggle" class:running={channel.status === "running"} on:click={toggleStream}>
        {channel.status === "running" ? "Stop" : "Start"}
      </button>
    </header>

    <nav class="tabs">
      {#each ["preview", "clips", "platforms", "alerts"] as tab}
        <button class:active={activeTab === tab} on:click={() => (activeTab = tab)}>
          {tab}
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
  .channel-detail { max-width: 1200px; margin: 0 auto; padding: 24px; }
  header { display: flex; align-items: center; gap: 16px; margin-bottom: 24px; }
  .back { color: #888; text-decoration: none; font-size: 14px; }
  .back:hover { color: #fff; }
  h1 { font-size: 28px; font-weight: 700; color: #fff; flex: 1; }
  .btn-toggle {
    padding: 10px 24px;
    border: none;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    background: #22c55e;
    color: #000;
  }
  .btn-toggle.running { background: #ef4444; color: #fff; }
  .tabs { display: flex; gap: 4px; margin-bottom: 24px; border-bottom: 1px solid #2a2a3a; padding-bottom: 0; }
  .tabs button {
    padding: 10px 20px;
    border: none;
    background: none;
    color: #666;
    font-size: 14px;
    cursor: pointer;
    border-bottom: 2px solid transparent;
    margin-bottom: -1px;
    text-transform: capitalize;
  }
  .tabs button.active { color: #a78bfa; border-bottom-color: #a78bfa; }
  .tabs button:hover { color: #fff; }
  .loading { text-align: center; padding: 60px; color: #666; }
</style>
