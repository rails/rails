import * as ActionCable from "./action_cable"
import adapters from "./adapters"

export default Object.defineProperties(Object.create(ActionCable), {
  logger: {
    get() { return adapters.logger },
    set(value) { adapters.logger = value }
  },
  WebSocket: {
    get() { return adapters.WebSocket },
    set(value) { adapters.WebSocket = value }
  }
})
