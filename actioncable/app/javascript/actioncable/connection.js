import { ConnectionMonitor } from "./connection_monitor"
import { log } from "./helpers"

// Encapsulate the cable connection held by the consumer. This is an internal class not intended for direct user manipulation.

const { message_types, protocols } = {
  "message_types":{"welcome":"welcome","ping":"ping","confirmation":"confirm_subscription","rejection":"reject_subscription"},
  "default_mount_path":"/cable",
  "protocols":["actioncable-v1-json","actioncable-unsupported"]
}
const adjustedLength = Math.max(protocols.length, 1),
  supportedProtocols = protocols.slice(0, adjustedLength - 1)
//  ,unsupportedProtocol = protocols[adjustedLength - 1]

export class Connection {
  static initClass() {
    this.reopenDelay = 500

    this.prototype.events = {
      message(event) {
        if (!this.isProtocolSupported()) { return }
        const {identifier, message, type} = JSON.parse(event.data)
        switch (type) {
          case message_types.welcome:
            this.monitor.recordConnect()
            return this.subscriptions.reload()
          case message_types.ping:
            return this.monitor.recordPing()
          case message_types.confirmation:
            return this.subscriptions.notify(identifier, "connected")
          case message_types.rejection:
            return this.subscriptions.reject(identifier)
          default:
            return this.subscriptions.notify(identifier, "received", message)
        }
      },

      open() {
        log(`WebSocket onopen event, using '${this.getProtocol()}' subprotocol`)
        this.disconnected = false
        if (!this.isProtocolSupported()) {
          log("Protocol is unsupported. Stopping monitor and disconnecting.")
          return this.close({allowReconnect: false})
        }
      },

      close(event) {
        log("WebSocket onclose event")
        if (this.disconnected) { return }
        this.disconnected = true
        this.monitor.recordDisconnect()
        return this.subscriptions.notifyAll("disconnected", {willAttemptReconnect: this.monitor.isRunning()})
      },

      error() {
        return log("WebSocket onerror event")
      }
    }
  }

  constructor(consumer) {
    this.open = this.open.bind(this)
    this.consumer = consumer
    this.subscriptions = this.consumer
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
      log(`Attempted to open WebSocket, but existing socket is ${this.getState()}`)
      return false
    } else {
      log(`Opening WebSocket, current state is ${this.getState()}, subprotocols: ${protocols}`)
      if (this.webSocket != null) { this.uninstallEventHandlers() }
      this.webSocket = new WebSocket(this.consumer.url, protocols)
      this.installEventHandlers()
      this.monitor.start()
      return true
    }
  }

  close(param) {
    if (param == null) { param = {allowReconnect: true} }
    const {allowReconnect} = param
    if (!allowReconnect) { this.monitor.stop() }
    if (this.isActive()) { return (this.webSocket != null ? this.webSocket.close() : undefined) }
  }

  reopen() {
    log(`Reopening WebSocket, current state is ${this.getState()}`)
    if (this.isActive()) {
      try {
        return this.close()
      } catch (error) {
        return log("Failed to reopen WebSocket", error)
      }
      finally {
        log(`Reopening WebSocket in ${this.constructor.reopenDelay}ms`)
        setTimeout(this.open, this.constructor.reopenDelay)
      }
    } else {
      return this.open()
    }
  }

  getProtocol() {
    return (this.webSocket != null ? this.webSocket.protocol : undefined)
  }

  isOpen() {
    return this.isState("open")
  }

  isActive() {
    return this.isState("open", "connecting")
  }

  // Private

  isProtocolSupported() {
    let needle
    return (needle = this.getProtocol(), Array.from(supportedProtocols).includes(needle))
  }

  isState(...states) {
    let needle
    return (needle = this.getState(), Array.from(states).includes(needle))
  }

  getState() {
    for (let state in WebSocket) {
      const value = WebSocket[state]
      if (value === (this.webSocket != null ? this.webSocket.readyState : undefined)) { return state.toLowerCase() }
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
Connection.initClass()
