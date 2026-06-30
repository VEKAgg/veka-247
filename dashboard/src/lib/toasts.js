import { writable } from "svelte/store";

export const toasts = writable([]);

let id = 0;

export function addToast(message, type = "info", duration = 4000) {
  const toast = { id: ++id, message, type, removing: false };
  toasts.update((t) => [...t, toast]);

  setTimeout(() => {
    toasts.update((t) =>
      t.map((x) => (x.id === toast.id ? { ...x, removing: true } : x))
    );
    setTimeout(() => {
      toasts.update((t) => t.filter((x) => x.id !== toast.id));
    }, 300);
  }, duration);
}
