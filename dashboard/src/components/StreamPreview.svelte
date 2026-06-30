<script>
  import { onMount, onDestroy } from "svelte";
  import Hls from "hls.js";

  export let channel;

  let videoEl;
  let hls;
  let error = null;
  let retryCount = 0;
  const MAX_RETRIES = 5;

  $: hlsUrl = `/streams/${channel.slug}/stream.m3u8`;

  onMount(() => {
    initPlayer();
  });

  onDestroy(() => {
    if (hls) hls.destroy();
  });

  function initPlayer() {
    if (hls) hls.destroy();
    error = null;

    if (Hls.isSupported()) {
      hls = new Hls({
        enableWorker: true,
        lowLatencyMode: true,
        maxBufferLength: 10,
        manifestLoadingTimeOut: 10000,
        levelLoadingTimeOut: 10000,
      });
      hls.loadSource(hlsUrl);
      hls.attachMedia(videoEl);
      hls.on(Hls.Events.ERROR, (_, data) => {
        if (data.fatal) {
          if (retryCount < MAX_RETRIES) {
            error = data.type;
            retryCount++;
            setTimeout(() => initPlayer(), 5000);
          } else {
            error = "max_retries";
          }
        }
      });
      hls.on(Hls.Events.MANIFEST_PARSED, () => {
        retryCount = 0;
        error = null;
      });
    } else if (videoEl.canPlayType("application/vnd.apple.mpegurl")) {
      videoEl.src = hlsUrl;
    }
  }
</script>

<div class="preview">
  <div class="video-container">
    <video bind:this={videoEl} autoplay muted playsinline />
    {#if error}
      <div class="error-overlay">
        <div class="error-content">
          <span class="error-icon">📡</span>
          {#if error === "max_retries"}
            <span>Stream offline — max retries reached</span>
            <button class="retry-btn" on:click={() => { retryCount = 0; initPlayer(); }}>
              Retry
            </button>
          {:else}
            <span>Stream offline — retrying ({retryCount}/{MAX_RETRIES})...</span>
          {/if}
        </div>
      </div>
    {/if}
    {#if !error}
      <div class="live-indicator">
        <span class="live-dot"></span>
        PREVIEW
      </div>
    {/if}
  </div>
  <div class="info">
    <span class="label">HLS URL:</span>
    <code>{hlsUrl}</code>
  </div>
</div>

<style>
  .preview { width: 100%; }
  .video-container {
    position: relative;
    width: 100%;
    aspect-ratio: 16/9;
    background: #000;
    border-radius: 12px;
    overflow: hidden;
    border: 1px solid #2a2a3a;
  }
  video { width: 100%; height: 100%; object-fit: contain; }
  .error-overlay {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(0,0,0,0.8);
  }
  .error-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
    color: #888;
    font-size: 16px;
  }
  .error-icon { font-size: 32px; }
  .retry-btn {
    padding: 8px 20px;
    border: 1px solid #a78bfa;
    background: transparent;
    color: #a78bfa;
    border-radius: 6px;
    cursor: pointer;
    font-size: 13px;
    transition: all 0.2s;
  }
  .retry-btn:hover { background: rgba(167,139,250,0.1); }
  .live-indicator {
    position: absolute;
    top: 12px;
    left: 12px;
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 10px;
    background: rgba(0,0,0,0.6);
    border-radius: 4px;
    font-size: 10px;
    font-weight: 700;
    color: #ef4444;
    letter-spacing: 1px;
  }
  .live-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #ef4444;
    animation: pulse 2s infinite;
  }
  .info { margin-top: 12px; font-size: 13px; color: #666; }
  .info code {
    color: #a78bfa;
    font-family: 'SF Mono', 'Fira Code', monospace;
    font-size: 12px;
  }
  @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.4; } }
</style>
