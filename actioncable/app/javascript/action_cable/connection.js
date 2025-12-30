import adapters from "./adapters"
import ConnectionMonitor from "./connection_monitor"
import INTERNAL from "./internal"
import logger from "./logger"

// Encapsulate the cable connection held by the consumer. This is an internal class not intended for direct user manipulation.

const {message_types, protocols} = INTERNAL
const supportedProtocols = protocols.slice(0, protocols.length - 1)

const indexOf = [].indexOf

class Connection {
  constructor(consumer) {
    this.open = this.open.bind(this)
    this.consumer = consumer
    this.subscriptions = this.consumer.subscriptions
    this.monitor = new ConnectionMonitor(this)
    this.disconnected = true
  }

  send(data) {
    if (this.isOpen()) {
      this.webSocket.send(JSON.stringify(data))
      return true
    } else {
      return false
    }
  }

  open() {
    if (this.isActive()) {
      logger.log(`Attempted to open WebSocket, but existing socket is ${this.getState()}`)
      return false
    } else {
      const socketProtocols = [...protocols, ...this.consumer.subprotocols || []]
      logger.log(`Opening WebSocket, current state is ${this.getState()}, subprotocols: ${socketProtocols}`)
      if (this.webSocket) { this.uninstallEventHandlers() }
      this.webSocket = new adapters.WebSocket(this.consumer.url, socketProtocols)
      this.installEventHandlers()
      this.monitor.start()
      return true
    }
  }

  close({allowReconnect} = {allowReconnect: true}) {
    if (!allowReconnect) { this.monitor.stop() }
    // Avoid closing websockets in a "connecting" state due to Safari 15.1+ bug. See: https://github.com/rails/rails/issues/43835#issuecomment-1002288478
    if (this.isOpen()) {
      return this.webSocket.close()
    }
  }

  reopen() {
    logger.log(`Reopening WebSocket, current state is ${this.getState()}`)
    if (this.isActive()) {
      try {
        return this.close()
      } catch (error) {
        logger.log("Failed to reopen WebSocket", error)
      }
      finally {
        logger.log(`Reopening WebSocket in ${this.constructor.reopenDelay}ms`)
        setTimeout(this.open, this.constructor.reopenDelay)
      }
    } else {
      return this.open()
    }
  }

  getProtocol() {
    if (this.webSocket) {
      return this.webSocket.protocol
    }
  }

  isOpen() {
    return this.isState("open")
  }

  isActive() {
    return this.isState("open", "connecting")
  }

  triedToReconnect() {
    return this.monitor.reconnectAttempts > 0
  }

  // Private

  isProtocolSupported() {
    return indexOf.call(supportedProtocols, this.getProtocol()) >= 0
  }

  isState(...states) {
    return indexOf.call(states, this.getState()) >= 0
  }

  getState() {
    if (this.webSocket) {
      for (let state in adapters.WebSocket) {
        if (adapters.WebSocket[state] === this.webSocket.readyState) {
          return state.toLowerCase()
        }
      }
    }
    return null
  }

  installEventHandlers() {
    for (let eventName in this.events) {
      const handler = this.events[eventName].bind(this)
      this.webSocket[`on${eventName}`] = handler
    }
  }

  uninstallEventHandlers() {
    for (let eventName in this.events) {
      this.webSocket[`on${eventName}`] = function() {}
    }
  }

}

Connection.reopenDelay = 500

Connection.prototype.events = {
  message(event) {
    if (!this.isProtocolSupported()) { return }
    const {identifier, message, reason, reconnect, type} = JSON.parse(event.data)
    this.monitor.recordMessage()
    switch (type) {
      case message_types.welcome:
        if (this.triedToReconnect()) {
          this.reconnectAttempted = true
        }
        this.monitor.recordConnect()
        return this.subscriptions.reload()
      case message_types.disconnect:
        logger.log(`Disconnecting. Reason: ${reason}`)
        return this.close({allowReconnect: reconnect})
      case message_types.ping:
        return null
      case message_types.confirmation:
        this.subscriptions.confirmSubscription(identifier)
        if (this.reconnectAttempted) {
          this.reconnectAttempted = false
          return this.subscriptions.notify(identifier, "connected", {reconnected: true})
        } else {
          return this.subscriptions.notify(identifier, "connected", {reconnected: false})
        }
      case message_types.rejection:
        return this.subscriptions.reject(identifier)
      default:
        return this.subscriptions.notify(identifier, "received", message)
    }
  },

  open() {
    logger.log(`WebSocket onopen event, using '${this.getProtocol()}' subprotocol`)
    this.disconnected = false
    if (!this.isProtocolSupported()) {
      logger.log("Protocol is unsupported. Stopping monitor and disconnecting.")
      return this.close({allowReconnect: false})
    }
  },

  close(event) {
    logger.log("WebSocket onclose event")
    if (this.disconnected) { return }
    this.disconnected = true
    this.monitor.recordDisconnect()
    return this.subscriptions.notifyAll("disconnected", {willAttemptReconnect: this.monitor.isRunning()})
  },

  error() {
    logger.log("WebSocket onerror event")
  }
}

export default Connection
