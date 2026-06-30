<script>
  import Toast from "../components/Toast.svelte";
</script>

<slot />
<Toast />

<footer>
  <span>veka-247</span>
  <span class="sep">·</span>
  <span>v1.0.0</span>
</footer>

<style>
  footer {
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 8px;
    padding: 24px;
    font-size: 12px;
    color: #444;
    border-top: 1px solid #1a1a24;
    margin-top: 40px;
  }
  .sep { color: #333; }
</style>
