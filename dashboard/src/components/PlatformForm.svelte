<script>
  import { api } from "$lib/api.js";

  export let channel;
  export let platforms = [];

  let showAdd = false;
  let newPlatform = { platform_type: "twitch", name: "", rtmp_url: "", stream_key: "" };

  const defaults = {
    twitch: { rtmp_url: "rtmp://aps30.contribute.live-video.net/app", name: "Twitch (Mumbai)" },
    youtube: { rtmp_url: "rtmp://a.rtmp.youtube.com/live2", name: "YouTube" },
    kick: { rtmp_url: "", name: "Kick" },
  };

  function selectType(type) {
    newPlatform.platform_type = type;
    newPlatform.rtmp_url = defaults[type]?.rtmp_url || "";
    newPlatform.name = defaults[type]?.name || "";
  }

  async function addPlatform() {
    try {
      const p = await api.platforms.create(channel.id, newPlatform);
      platforms = [...platforms, p];
      showAdd = false;
      newPlatform = { platform_type: "twitch", name: "", rtmp_url: "", stream_key: "" };
    } catch (err) {
      alert("Failed: " + err.message);
    }
  }

  async function removePlatform(p) {
    if (!confirm(`Remove ${p.platform_type}?`)) return;
    await api.platforms.delete(channel.id, p.id);
    platforms = platforms.filter((x) => x.id !== p.id);
  }

  async function toggleActive(p) {
    await api.platforms.update(channel.id, p.id, { is_active: !p.is_active });
    platforms = platforms.map((x) => (x.id === p.id ? { ...x, is_active: !x.is_active } : x));
  }
</script>

<div class="platform-form">
  <div class="platform-list">
    {#each platforms as p (p.id)}
      <div class="platform-row" class:inactive={!p.is_active}>
        <span class="platform-icon">
          {#if p.platform_type === "twitch"}🟣
          {:else if p.platform_type === "youtube"}🔴
          {:else if p.platform_type === "kick"}🟢
          {:else}📡
          {/if}
        </span>
        <span class="platform-name">{p.name || p.platform_type}</span>
        <span class="platform-url">{p.rtmp_url}</span>
        <button class="toggle-btn" on:click={() => toggleActive(p)}>
          {p.is_active ? "Active" : "Disabled"}
        </button>
        <button class="remove-btn" on:click={() => removePlatform(p)}>Remove</button>
      </div>
    {:else}
      <p class="empty">No platforms configured. Add one below.</p>
    {/each}
  </div>

  {#if showAdd}
    <div class="add-form">
      <div class="type-selector">
        {#each ["twitch", "youtube", "kick"] as type}
          <button
            class="type-btn"
            class:active={newPlatform.platform_type === type}
            on:click={() => selectType(type)}
          >
            {type}
          </button>
        {/each}
      </div>
      <input bind:value={newPlatform.name} placeholder="Display name" />
      <input bind:value={newPlatform.rtmp_url} placeholder="RTMP URL" />
      <input bind:value={newPlatform.stream_key} type="password" placeholder="Stream key" />
      <div class="form-actions">
        <button class="save-btn" on:click={addPlatform}>Add Platform</button>
        <button class="cancel-btn" on:click={() => (showAdd = false)}>Cancel</button>
      </div>
    </div>
  {:else}
    <button class="add-btn" on:click={() => (showAdd = true)}>+ Add Platform</button>
  {/if}
</div>

<style>
  .platform-form { width: 100%; }
  .platform-list { display: flex; flex-direction: column; gap: 8px; margin-bottom: 16px; }
  .platform-row {
    display: flex; align-items: center; gap: 12px;
    padding: 12px 16px; background: #1a1a24; border-radius: 8px;
  }
  .platform-row.inactive { opacity: 0.5; }
  .platform-icon { font-size: 20px; }
  .platform-name { font-weight: 600; color: #fff; min-width: 80px; }
  .platform-url { flex: 1; font-size: 12px; color: #666; font-family: monospace; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .toggle-btn { padding: 4px 12px; border: none; border-radius: 4px; font-size: 12px; cursor: pointer; background: #22c55e; color: #000; }
  .toggle-btn { background: #333; color: #888; }
  .remove-btn { padding: 4px 12px; border: none; border-radius: 4px; font-size: 12px; cursor: pointer; background: #333; color: #ff4444; }
  .add-btn { padding: 10px; border: 2px dashed #333; background: none; color: #666; border-radius: 8px; cursor: pointer; width: 100%; }
  .add-btn:hover { border-color: #a78bfa; color: #a78bfa; }
  .add-form { background: #1a1a24; padding: 20px; border-radius: 12px; display: flex; flex-direction: column; gap: 12px; }
  .type-selector { display: flex; gap: 8px; }
  .type-btn { padding: 8px 16px; border: 1px solid #333; background: none; color: #888; border-radius: 6px; cursor: pointer; text-transform: capitalize; }
  .type-btn.active { border-color: #a78bfa; color: #a78bfa; background: rgba(167,139,250,0.1); }
  input { padding: 10px 14px; border: 1px solid #333; background: #0f0f13; color: #fff; border-radius: 8px; font-size: 14px; }
  input:focus { outline: none; border-color: #a78bfa; }
  .form-actions { display: flex; gap: 8px; }
  .save-btn { padding: 10px 20px; border: none; background: #a78bfa; color: #000; border-radius: 8px; cursor: pointer; font-weight: 600; }
  .cancel-btn { padding: 10px 20px; border: none; background: #333; color: #fff; border-radius: 8px; cursor: pointer; }
  .empty { text-align: center; padding: 24px; color: #555; }
</style>
