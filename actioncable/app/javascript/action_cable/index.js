import { ActionCable, createConsumer, createWebSocketURL, getConfig } from "./action_cable"
import adapters from "./adapters"
import Connection from "./connection"
import ConnectionMonitor from "./connection_monitor"
import Consumer from "./consumer"
import INTERNAL from "./internal"
import { log, startDebugging, stopDebugging } from "./logger"
import Subscription from "./subscription"
import Subscriptions from "./subscriptions"

ActionCable.createConsumer = createConsumer
ActionCable.createWebSocketURL = createWebSocketURL
ActionCable.Connection = Connection
ActionCable.ConnectionMonitor = ConnectionMonitor
ActionCable.Consumer = Consumer
ActionCable.getConfig = getConfig
ActionCable.INTERNAL = INTERNAL
ActionCable.log = log
ActionCable.startDebugging = startDebugging
ActionCable.stopDebugging = stopDebugging
ActionCable.Subscription = Subscription
ActionCable.Subscriptions = Subscriptions

Object.defineProperties(ActionCable, {
  logger: {
    get() { return adapters.logger },
    set(value) { adapters.logger = value }
  },
  WebSocket: {
    get() { return adapters.WebSocket },
    set(value) { adapters.WebSocket = value }
  }
})

export default ActionCable
