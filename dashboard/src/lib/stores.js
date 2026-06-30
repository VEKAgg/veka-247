import { writable, derived } from "svelte/store";

export const channels = writable([]);
export const irlStatus = writable({ is_live: false, stream_info: null, overlay_active: false });

export const runningChannels = derived(channels, ($channels) =>
  $channels.filter((c) => c.status === "running").length
);

export const totalChannels = derived(channels, ($channels) => $channels.length);
