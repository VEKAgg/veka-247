<script>
  import { api } from "$lib/api.js";

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
    } catch (err) {
      alert("Upload failed: " + err.message);
    }
    uploading = false;
  }

  async function deleteClip(clip) {
    if (!confirm(`Delete ${clip.filename}?`)) return;
    try {
      await api.clips.delete(channel.id, clip.id);
      clips = clips.filter((c) => c.id !== clip.id);
    } catch (err) {
      alert("Delete failed: " + err.message);
    }
  }

  async function scanFolder() {
    try {
      const res = await api.clips.scan(channel.id);
      alert(res.message);
      clips = await api.clips.list(channel.id);
    } catch (err) {
      alert("Scan failed: " + err.message);
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
  </div>

  <div
    class="drop-zone"
    class:dragover={dragOver}
    on:dragover|preventDefault={() => (dragOver = true)}
    on:dragleave={() => (dragOver = false)}
    on:drop|preventDefault={(e) => { dragOver = false; handleUpload(e); }}
  >
    <p>Drag & drop clips here, or use the upload button</p>
  </div>

  <div class="clip-list">
    {#each clips as clip (clip.id)}
      <div class="clip-row">
        <span class="clip-name">{clip.filename}</span>
        <span class="clip-size">{formatSize(clip.file_size_bytes)}</span>
        <button class="delete-btn" on:click={() => deleteClip(clip)}>Delete</button>
      </div>
    {:else}
      <p class="empty">No clips yet. Upload some or scan the folder.</p>
    {/each}
  </div>
</div>

<style>
  .clip-manager { width: 100%; }
  .actions { display: flex; gap: 12px; margin-bottom: 16px; }
  .upload-btn, .scan-btn {
    padding: 10px 20px;
    border: none;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    background: #a78bfa;
    color: #000;
  }
  .upload-btn.disabled { opacity: 0.5; cursor: not-allowed; }
  .scan-btn { background: #333; color: #fff; }
  .drop-zone {
    border: 2px dashed #333;
    border-radius: 12px;
    padding: 40px;
    text-align: center;
    color: #555;
    margin-bottom: 24px;
    transition: all 0.2s;
  }
  .drop-zone.dragover { border-color: #a78bfa; color: #a78bfa; background: rgba(167,139,250,0.05); }
  .clip-list { display: flex; flex-direction: column; gap: 4px; }
  .clip-row {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 12px 16px;
    background: #1a1a24;
    border-radius: 8px;
  }
  .clip-name { flex: 1; font-size: 14px; color: #e0e0e0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .clip-size { font-size: 13px; color: #666; }
  .delete-btn { padding: 4px 12px; border: none; background: #333; color: #ff4444; border-radius: 4px; cursor: pointer; font-size: 12px; }
  .delete-btn:hover { background: #ff4444; color: #fff; }
  .empty { text-align: center; padding: 40px; color: #555; }
</style>
