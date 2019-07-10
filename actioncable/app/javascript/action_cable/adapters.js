export default {
  logger: typeof module === "undefined" ? self.console : console,
  WebSocket: typeof module === "undefined" ? self.WebSocket : WebSocket
}
