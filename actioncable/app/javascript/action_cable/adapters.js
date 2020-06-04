const adapters = {}

if (typeof self !== "undefined") {
  adapters.logger = self.console
  adapters.WebSocket = self.WebSocket
}

export default adapters
