
const getAdapter = () => {
  const adapter = {};
  if (typeof self !== "undefined") {
    adapter.logger = self.console;
    adapter.WebSocket = self.WebSocket;
  } else if (typeof window !== "undefined") {
    adapter.logger = window.console;
    adapter.WebSocket = window.WebSocket;
  } else {
    // eslint-disable-next-line no-undef
    adapter.logger = global.console;
    // eslint-disable-next-line no-undef
    adapter.WebSocket = global.WebSocket;
  }
  return adapter
}
var adapters = getAdapter();

export default {
  adapters
}