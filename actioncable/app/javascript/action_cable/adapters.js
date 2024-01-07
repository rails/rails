export default {
  logger: typeof console !== "undefined" ? console : undefined,
  WebSocket: typeof WebSocket !== "undefined" ? WebSocket : undefined,
}
