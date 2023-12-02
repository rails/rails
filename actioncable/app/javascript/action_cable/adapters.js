export default {
  logger: typeof self !== "undefined" ? self.console : global.console,
  WebSocket: typeof self !== "undefined" ? self.WebSocket : global.WebSocket
}
