<script>
  import { api } from "$lib/api.js";
  import { addToast } from "$lib/toasts.js";

  export let channel;
  export let clips = [];

  let uploading = false;
  let dragOver = false;

  async function handleUpload(e) {
    const files = e.target.files || e.dataTransfer.files;
    if (!files.length) return;
    uploading = true;
    try {
      const uploaded = await api.clips.upload(channel.id, files);
      clips = [...clips, ...uploaded];
      addToast(`Uploaded ${uploaded.length} clip(s)`, "success");
    } catch (err) {
      addToast("Upload failed: " + err.message, "error");
    }
    uploading = false;
  }

  async function deleteClip(clip) {
    if (!confirm(`Delete ${clip.filename}?`)) return;
    try {
      await api.clips.delete(channel.id, clip.id);
      clips = clips.filter((c) => c.id !== clip.id);
      addToast(`Deleted ${clip.filename}`, "info");
    } catch (err) {
      addToast("Delete failed: " + err.message, "error");
    }
  }

  async function scanFolder() {
    try {
      const res = await api.clips.scan(channel.id);
      addToast(res.message, "success");
      clips = await api.clips.list(channel.id);
    } catch (err) {
      addToast("Scan failed: " + err.message, "error");
    }
  }

  function formatSize(bytes) {
    if (!bytes) return "—";
    const mb = bytes / 1024 / 1024;
    return `${mb.toFixed(1)} MB`;
  }
</script>

<div class="clip-manager">
  <div class="actions">
    <label class="upload-btn" class:disabled={uploading}>
      <input type="file" multiple accept=".mp4,.mkv,.mov,.avi,.flv,.ts" on:change={handleUpload} hidden />
      {uploading ? "Uploading..." : "Upload Clips"}
    </label>
    <button class="scan-btn" on:click={scanFolder}>Scan Folder</button>
    <span class="clip-count">{clips.length} clip(s)</span>
  </div>

  <!-- svelte-ignore a11y-no-static-element-interactions -->
  <div
    class="drop-zone"
    class:dragover={dragOver}
    on:dragover|preventDefault={() => (dragOver = true)}
    on:dragleave={() => (dragOver = false)}
    on:drop|preventDefault={(e) => { dragOver = false; handleUpload(e); }}
  >
    <div class="drop-icon">📁</div>
    <p>Drag & drop clips here, or use the upload button</p>
    <p class="drop-hint">Supports MP4, MKV, MOV, AVI, FLV, TS</p>
  </div>

  <div class="clip-list">
    {#each clips as clip (clip.id)}
      <div class="clip-row">
        <span class="clip-icon">🎬</span>
        <span class="clip-name">{clip.filename}</span>
        <span class="clip-size">{formatSize(clip.file_size_bytes)}</span>
        <button class="delete-btn" on:click={() => deleteClip(clip)}>Delete</button>
      </div>
    {:else}
      <div class="empty">
        <div class="empty-icon">🎞️</div>
        <p>No clips yet. Upload some or scan the folder.</p>
      </div>
    {/each}
  </div>
</div>

<style>
  .clip-manager { width: 100%; }
  .actions { display: flex; align-items: center; gap: 12px; margin-bottom: 16px; }
  .clip-count { font-size: 13px; color: #555; margin-left: auto; }
  .upload-btn, .scan-btn {
    padding: 10px 20px;
    border: none;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
  }
  .upload-btn { background: #a78bfa; color: #000; }
  .upload-btn:hover:not(.disabled) { background: #9678e6; }
  .upload-btn.disabled { opacity: 0.5; cursor: not-allowed; }
  .scan-btn { background: #2a2a3a; color: #ccc; }
  .scan-btn:hover { background: #3a3a4a; }
  .drop-zone {
    border: 2px dashed #2a2a3a;
    border-radius: 12px;
    padding: 40px;
    text-align: center;
    color: #555;
    margin-bottom: 24px;
    transition: all 0.2s;
  }
  .drop-zone.dragover {
    border-color: #a78bfa;
    color: #a78bfa;
    background: rgba(167,139,250,0.05);
  }
  .drop-icon { font-size: 32px; margin-bottom: 8px; }
  .drop-hint { font-size: 12px; color: #444; margin-top: 4px; }
  .clip-list { display: flex; flex-direction: column; gap: 4px; }
  .clip-row {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 16px;
    background: #1a1a24;
    border: 1px solid #2a2a3a;
    border-radius: 8px;
    transition: border-color 0.2s;
  }
  .clip-row:hover { border-color: #3a3a4a; }
  .clip-icon { font-size: 16px; }
  .clip-name {
    flex: 1;
    font-size: 14px;
    color: #e0e0e0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .clip-size { font-size: 13px; color: #666; font-family: monospace; }
  .delete-btn {
    padding: 4px 12px;
    border: 1px solid transparent;
    background: transparent;
    color: #666;
    border-radius: 4px;
    cursor: pointer;
    font-size: 12px;
    transition: all 0.2s;
  }
  .delete-btn:hover { background: rgba(239,68,68,0.1); color: #ef4444; border-color: rgba(239,68,68,0.3); }
  .empty { text-align: center; padding: 40px; color: #555; }
  .empty-icon { font-size: 32px; margin-bottom: 8px; }
</style>
