import Connection from "./connection"
import ConnectionMonitor from "./connection_monitor"
import Consumer from "./consumer"
import INTERNAL from "./internal"
import Subscription from "./subscription"
import Subscriptions from "./subscriptions"

export default {
  Connection,
  ConnectionMonitor,
  Consumer,
  INTERNAL,
  Subscription,
  Subscriptions,
  WebSocket: window.WebSocket,
  logger: window.console,

  createConsumer(url) {
    if (url == null) {
      const urlConfig = this.getConfig("url")
      url = (urlConfig ? urlConfig : this.INTERNAL.default_mount_path)
    }
    return new Consumer(this.createWebSocketURL(url))
  },

  getConfig(name) {
    const element = document.head.querySelector(`meta[name='action-cable-${name}']`)
    return (element ? element.getAttribute("content") : undefined)
  },

  createWebSocketURL(url) {
    if (url && !/^wss?:/i.test(url)) {
      const a = document.createElement("a")
      a.href = url
      // Fix populating Location properties in IE. Otherwise, protocol will be blank.
      a.href = a.href
      a.protocol = a.protocol.replace("http", "ws")
      return a.href
    } else {
      return url
    }
  },

  startDebugging() {
    this.debugging = true
  },

  stopDebugging() {
    this.debugging = null
  },

  log(...messages) {
    if (this.debugging) {
      messages.push(Date.now())
      this.logger.log("[ActionCable]", ...messages)
    }
  }
}
