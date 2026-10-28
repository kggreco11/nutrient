export async function sendChat(
  payload,
  { base = "", token = "", fetchImpl = fetch } = {},
) {
  const response = await fetchImpl(base + "/api/chat", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token
        ? {
            Authorization: "Bearer " + token,
            "OAI-Sites-Authorization": "Bearer " + token,
          }
        : {}),
    },
    credentials: "include",
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(180000),
  });
  if (
    !(response.headers.get("content-type") || "").includes("application/json")
  ) {
    throw Error(
      response.status === 401 || response.status === 403
        ? "Sign in to connect chat, then retry."
        : "Chat is unavailable right now. Try again.",
    );
  }
  const data = await response.json();
  if (!response.ok)
    throw Error(
      response.status === 401 || response.status === 403
        ? "Your chat connection expired. Reconnect in Settings, then retry."
        : data.error || "Couldn’t send that message. Try again.",
    );
  if (typeof data.reply !== "string")
    throw Error("Chat returned an empty response. Try again.");
  return data;
}
