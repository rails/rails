
const getAdapter = () => {
  const adapter = {};
  if (typeof self !== "undefined") {
    adapter.logger = self.console;
    adapter.WebSocket = self.WebSocket;
  } else if (typeof window !== "undefined") {
    adapter.logger = window.console;
    adapter.WebSocket = window.WebSocket;
  } else {
    adapter.logger = global.console;
    adapter.WebSocket = global.WebSocket;
  }
  return adapter
}
var adapters = getAdapter();

export default {
  adapters
}