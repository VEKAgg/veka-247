<script>
  import { onMount, onDestroy } from "svelte";
  import Hls from "hls.js";

  export let channel;

  let videoEl;
  let hls;
  let error = null;

  $: hlsUrl = `/streams/${channel.slug}/stream.m3u8`;

  onMount(() => {
    initPlayer();
  });

  onDestroy(() => {
    if (hls) hls.destroy();
  });

  function initPlayer() {
    if (hls) hls.destroy();

    if (Hls.isSupported()) {
      hls = new Hls({
        enableWorker: true,
        lowLatencyMode: true,
        maxBufferLength: 10,
      });
      hls.loadSource(hlsUrl);
      hls.attachMedia(videoEl);
      hls.on(Hls.Events.ERROR, (_, data) => {
        if (data.fatal) {
          error = data.type;
          setTimeout(() => {
            error = null;
            initPlayer();
          }, 5000);
        }
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
        <span>Stream offline — retrying...</span>
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
  }
  video { width: 100%; height: 100%; object-fit: contain; }
  .error-overlay {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(0,0,0,0.7);
    color: #ff4444;
    font-size: 18px;
  }
  .info { margin-top: 12px; font-size: 13px; color: #666; }
  .info code { color: #a78bfa; font-family: monospace; }
</style>
