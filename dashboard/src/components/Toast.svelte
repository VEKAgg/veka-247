<script>
  import { toasts } from "$lib/toasts.js";
</script>

<div class="toast-container">
  {#each $toasts as toast (toast.id)}
    <div class="toast {toast.type}" class:removing={toast.removing}>
      <span class="toast-icon">
        {#if toast.type === "success"}✓
        {:else if toast.type === "error"}✕
        {:else if toast.type === "warning"}⚠
        {:else}ℹ
        {/if}
      </span>
      <span class="toast-msg">{toast.message}</span>
    </div>
  {/each}
</div>

<style>
  .toast-container {
    position: fixed;
    top: 20px;
    right: 20px;
    z-index: 9999;
    display: flex;
    flex-direction: column;
    gap: 8px;
    pointer-events: none;
  }
  .toast {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 12px 20px;
    border-radius: 10px;
    font-size: 14px;
    font-weight: 500;
    color: #fff;
    background: #1a1a2e;
    border: 1px solid #2a2a3a;
    box-shadow: 0 4px 20px rgba(0,0,0,0.4);
    animation: slideIn 0.3s ease-out;
    pointer-events: auto;
  }
  .toast.removing {
    animation: slideOut 0.3s ease-in forwards;
  }
  .toast.success { border-left: 3px solid #22c55e; }
  .toast.error { border-left: 3px solid #ef4444; }
  .toast.warning { border-left: 3px solid #f59e0b; }
  .toast.info { border-left: 3px solid #3b82f6; }
  .toast-icon { font-size: 16px; font-weight: 700; }
  .toast.success .toast-icon { color: #22c55e; }
  .toast.error .toast-icon { color: #ef4444; }
  .toast.warning .toast-icon { color: #f59e0b; }
  .toast.info .toast-icon { color: #3b82f6; }
  @keyframes slideIn {
    from { transform: translateX(100%); opacity: 0; }
    to { transform: translateX(0); opacity: 1; }
  }
  @keyframes slideOut {
    from { transform: translateX(0); opacity: 1; }
    to { transform: translateX(100%); opacity: 0; }
  }
</style>
