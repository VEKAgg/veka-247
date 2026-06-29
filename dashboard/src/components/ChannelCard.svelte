<script>
  export let channel;

  const statusColors = {
    running: "#00ff88",
    stopped: "#666",
    starting: "#ffaa00",
    error: "#ff4444",
  };

  const categoryIcons = {
    gta5: "🚗",
    elite_dangerous: "🚀",
    forza: "🏎️",
    rocket_league: "⚽",
  };
</script>

<a href="/channel/{channel.slug}" class="card">
  <div class="card-header">
    <span class="icon">{categoryIcons[channel.category] || "📺"}</span>
    <span class="status" style="color: {statusColors[channel.status] || '#666'}">
      {channel.status}
    </span>
  </div>
  <h3>{channel.name}</h3>
  <p class="desc">{channel.description || "No description"}</p>
  <div class="meta">
    <span>{channel.clip_folder}</span>
    <span>{channel.rtmp_path}</span>
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
    transition: all 0.2s;
  }
  .card:hover {
    border-color: #a78bfa;
    transform: translateY(-2px);
    box-shadow: 0 4px 20px rgba(167, 139, 250, 0.1);
  }
  .card-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }
  .icon { font-size: 28px; }
  .status { font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 1px; }
  h3 { font-size: 20px; font-weight: 700; color: #fff; margin-bottom: 6px; }
  .desc { font-size: 13px; color: #888; margin-bottom: 12px; }
  .meta { display: flex; justify-content: space-between; font-size: 11px; color: #555; }
</style>
