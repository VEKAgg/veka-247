<script>
  export let channel;

  const statusColors = {
    running: "#22c55e",
    stopped: "#555",
    starting: "#f59e0b",
    error: "#ef4444",
  };

  const statusBg = {
    running: "rgba(34,197,94,0.1)",
    stopped: "rgba(85,85,85,0.1)",
    starting: "rgba(245,158,11,0.1)",
    error: "rgba(239,68,68,0.1)",
  };

  const categoryIcons = {
    gta5: "🚗",
    elite_dangerous: "🚀",
    forza: "🏎️",
    rocket_league: "⚽",
  };

  $: platforms = channel.platforms || [];
  $: hasTwitch = platforms.some((p) => p.platform_type === "twitch" && p.is_active);
  $: hasYoutube = platforms.some((p) => p.platform_type === "youtube" && p.is_active);
  $: hasKick = platforms.some((p) => p.platform_type === "kick" && p.is_active);
</script>

<a href="/channel/{channel.slug}" class="card">
  <div class="card-header">
    <span class="icon">{categoryIcons[channel.category] || "📺"}</span>
    <span
      class="status"
      style="color: {statusColors[channel.status] || '#555'}; background: {statusBg[channel.status] || 'rgba(85,85,85,0.1)'}"
    >
      <span class="status-dot" style="background: {statusColors[channel.status] || '#555'}"></span>
      {channel.status}
    </span>
  </div>

  <h3>{channel.name}</h3>
  <p class="desc">{channel.description || "No description"}</p>

  <div class="card-footer">
    <div class="platforms">
      {#if hasTwitch}
        <span class="platform-badge twitch" title="Twitch">🟣</span>
      {/if}
      {#if hasYoutube}
        <span class="platform-badge youtube" title="YouTube">🔴</span>
      {/if}
      {#if hasKick}
        <span class="platform-badge kick" title="Kick">🟢</span>
      {/if}
      {#if !hasTwitch && !hasYoutube && !hasKick}
        <span class="no-platforms">No platforms</span>
      {/if}
    </div>
    <span class="rtmp">{channel.rtmp_path}</span>
  </div>
</a>

<style>
  .card {
    display: block;
    background: #1a1a24;
    border: 1px solid #2a2a3a;
    border-radius: 12px;
    padding: 20px;
    text-decoration: none;
    color: inherit;
    transition: all 0.2s ease;
    position: relative;
    overflow: hidden;
  }
  .card::before {
    content: '';
    position: absolute;
    inset: 0;
    border-radius: 12px;
    padding: 1px;
    background: linear-gradient(135deg, transparent 40%, rgba(167,139,250,0.15));
    -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
    -webkit-mask-composite: xor;
    mask-composite: exclude;
    pointer-events: none;
    opacity: 0;
    transition: opacity 0.2s;
  }
  .card:hover::before { opacity: 1; }
  .card:hover {
    border-color: #3a3a4a;
    transform: translateY(-2px);
    box-shadow: 0 8px 30px rgba(0,0,0,0.3);
  }
  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 12px;
  }
  .icon { font-size: 28px; }
  .status {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 1px;
    padding: 4px 10px;
    border-radius: 20px;
  }
  .status-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
  }
  .status-dot[style*="running"] {
    box-shadow: 0 0 6px #22c55e;
    animation: pulse-dot 2s infinite;
  }
  h3 { font-size: 18px; font-weight: 700; color: #fff; margin-bottom: 6px; }
  .desc {
    font-size: 13px;
    color: #777;
    margin-bottom: 16px;
    line-height: 1.4;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  .card-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .platforms { display: flex; gap: 4px; }
  .platform-badge {
    font-size: 12px;
    width: 22px;
    height: 22px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 4px;
    background: rgba(255,255,255,0.05);
  }
  .no-platforms { font-size: 11px; color: #444; }
  .rtmp {
    font-size: 11px;
    color: #444;
    font-family: 'SF Mono', 'Fira Code', monospace;
  }
  @keyframes pulse-dot {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.4; }
  }
</style>
