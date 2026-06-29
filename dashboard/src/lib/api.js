const BASE = "/api";

async function request(path, options = {}) {
  const res = await fetch(`${BASE}${path}`, {
    headers: { "Content-Type": "application/json", ...options.headers },
    ...options,
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: res.statusText }));
    throw new Error(err.detail || "Request failed");
  }
  return res.json();
}

export const api = {
  channels: {
    list: () => request("/channels/"),
    get: (id) => request(`/channels/${id}`),
    create: (data) => request("/channels/", { method: "POST", body: JSON.stringify(data) }),
    update: (id, data) => request(`/channels/${id}`, { method: "PATCH", body: JSON.stringify(data) }),
    delete: (id) => request(`/channels/${id}`, { method: "DELETE" }),
    start: (id) => request(`/channels/${id}/start`, { method: "POST" }),
    stop: (id) => request(`/channels/${id}/stop`, { method: "POST" }),
    status: (id) => request(`/channels/${id}/status`),
  },
  platforms: {
    list: (channelId) => request(`/channels/${channelId}/platforms`),
    create: (channelId, data) =>
      request(`/channels/${channelId}/platforms`, { method: "POST", body: JSON.stringify(data) }),
    update: (channelId, platformId, data) =>
      request(`/channels/${channelId}/platforms/${platformId}`, { method: "PATCH", body: JSON.stringify(data) }),
    delete: (channelId, platformId) =>
      request(`/channels/${channelId}/platforms/${platformId}`, { method: "DELETE" }),
  },
  clips: {
    list: (channelId) => request(`/channels/${channelId}/clips`),
    upload: async (channelId, files) => {
      const form = new FormData();
      for (const file of files) form.append("files", file);
      const res = await fetch(`${BASE}/channels/${channelId}/clips/upload`, {
        method: "POST",
        body: form,
      });
      return res.json();
    },
    delete: (channelId, clipId) =>
      request(`/channels/${channelId}/clips/${clipId}`, { method: "DELETE" }),
    scan: (channelId) => request(`/channels/${channelId}/clips/scan`, { method: "POST" }),
  },
  alerts: {
    templates: () => request("/alerts/templates"),
    listConfig: (channelId) => request(`/alerts/${channelId}/config`),
    createConfig: (channelId, data) =>
      request(`/alerts/${channelId}/config`, { method: "POST", body: JSON.stringify(data) }),
    updateConfig: (channelId, alertId, data) =>
      request(`/alerts/${channelId}/config/${alertId}`, { method: "PATCH", body: JSON.stringify(data) }),
    test: (channelId, event) =>
      request(`/alerts/${channelId}/test`, { method: "POST", body: JSON.stringify(event) }),
  },
  irl: {
    status: () => request("/irl/status"),
    start: (channelId) => request(`/irl/start${channelId ? `?channel_id=${channelId}` : ""}`, { method: "POST" }),
    stop: () => request("/irl/stop", { method: "POST" }),
  },
};
