export default {
  logger: console,
  WebSocket: typeof WebSocket === "function" ? WebSocket : null
}
