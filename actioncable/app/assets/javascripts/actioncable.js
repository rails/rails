(function(global, factory) {
  typeof exports === "object" && typeof module !== "undefined" ? module.exports = factory() : typeof define === "function" && define.amd ? define(factory) : global.ActiveStorage = factory();
})(this, function() {
  "use strict";
  function log(...messages) {
    if (this.debugging) {
      messages.push(Date.now());
      this.logger = window.console;
      return this.logger.log("[ActionCable]", ...Array.from(messages));
    }
  }
  let now = undefined;
  let secondsSince = undefined;
  let clamp = undefined;
  class ConnectionMonitor {
    static initClass() {
      this.pollInterval = {
        min: 3,
        max: 30
      };
      this.staleThreshold = 6;
      now = (() => new Date().getTime());
      secondsSince = (time => (now() - time) / 1e3);
      clamp = ((number, min, max) => Math.max(min, Math.min(max, number)));
    }
    constructor(connection) {
      this.visibilityDidChange = this.visibilityDidChange.bind(this);
      this.connection = connection;
      this.reconnectAttempts = 0;
    }
    start() {
      if (!this.isRunning()) {
        this.startedAt = now();
        delete this.stoppedAt;
        this.startPolling();
        document.addEventListener("visibilitychange", this.visibilityDidChange);
        return log(`ConnectionMonitor started. pollInterval = ${this.getPollInterval()} ms`);
      }
    }
    stop() {
      if (this.isRunning()) {
        this.stoppedAt = now();
        this.stopPolling();
        document.removeEventListener("visibilitychange", this.visibilityDidChange);
        return log("ConnectionMonitor stopped");
      }
    }
    isRunning() {
      return this.startedAt != null && this.stoppedAt == null;
    }
    recordPing() {
      return this.pingedAt = now();
    }
    recordConnect() {
      this.reconnectAttempts = 0;
      this.recordPing();
      delete this.disconnectedAt;
      return log("ConnectionMonitor recorded connect");
    }
    recordDisconnect() {
      this.disconnectedAt = now();
      return log("ConnectionMonitor recorded disconnect");
    }
    startPolling() {
      this.stopPolling();
      return this.poll();
    }
    stopPolling() {
      return clearTimeout(this.pollTimeout);
    }
    poll() {
      return this.pollTimeout = setTimeout(() => {
        this.reconnectIfStale();
        return this.poll();
      }, this.getPollInterval());
    }
    getPollInterval() {
      const {min: min, max: max} = this.constructor.pollInterval;
      const interval = 5 * Math.log(this.reconnectAttempts + 1);
      return Math.round(clamp(interval, min, max) * 1e3);
    }
    reconnectIfStale() {
      if (this.connectionIsStale()) {
        log(`ConnectionMonitor detected stale connection. reconnectAttempts = ${this.reconnectAttempts}, pollInterval = ${this.getPollInterval()} ms, time disconnected = ${secondsSince(this.disconnectedAt)} s, stale threshold = ${this.constructor.staleThreshold} s`);
        this.reconnectAttempts++;
        if (this.disconnectedRecently()) {
          return log("ConnectionMonitor skipping reopening recent disconnect");
        } else {
          log("ConnectionMonitor reopening");
          return this.connection.reopen();
        }
      }
    }
    connectionIsStale() {
      return secondsSince(this.pingedAt != null ? this.pingedAt : this.startedAt) > this.constructor.staleThreshold;
    }
    disconnectedRecently() {
      return this.disconnectedAt && secondsSince(this.disconnectedAt) < this.constructor.staleThreshold;
    }
    visibilityDidChange() {
      if (document.visibilityState === "visible") {
        return setTimeout(() => {
          if (this.connectionIsStale() || !this.connection.isOpen()) {
            log(`ConnectionMonitor reopening stale connection on visibilitychange. visbilityState = ${document.visibilityState}`);
            return this.connection.reopen();
          }
        }, 200);
      }
    }
  }
  ConnectionMonitor.initClass();
  const {message_types: message_types, protocols: protocols} = {
    message_types: {
      welcome: "welcome",
      ping: "ping",
      confirmation: "confirm_subscription",
      rejection: "reject_subscription"
    },
    default_mount_path: "/cable",
    protocols: [ "actioncable-v1-json", "actioncable-unsupported" ]
  };
  const adjustedLength = Math.max(protocols.length, 1), supportedProtocols = protocols.slice(0, adjustedLength - 1);
  class Connection {
    static initClass() {
      this.reopenDelay = 500;
      this.prototype.events = {
        message(event) {
          if (!this.isProtocolSupported()) {
            return;
          }
          const {identifier: identifier, message: message, type: type} = JSON.parse(event.data);
          switch (type) {
           case message_types.welcome:
            this.monitor.recordConnect();
            return this.subscriptions.reload();

           case message_types.ping:
            return this.monitor.recordPing();

           case message_types.confirmation:
            return this.subscriptions.notify(identifier, "connected");

           case message_types.rejection:
            return this.subscriptions.reject(identifier);

           default:
            return this.subscriptions.notify(identifier, "received", message);
          }
        },
        open() {
          log(`WebSocket onopen event, using '${this.getProtocol()}' subprotocol`);
          this.disconnected = false;
          if (!this.isProtocolSupported()) {
            log("Protocol is unsupported. Stopping monitor and disconnecting.");
            return this.close({
              allowReconnect: false
            });
          }
        },
        close(event) {
          log("WebSocket onclose event");
          if (this.disconnected) {
            return;
          }
          this.disconnected = true;
          this.monitor.recordDisconnect();
          return this.subscriptions.notifyAll("disconnected", {
            willAttemptReconnect: this.monitor.isRunning()
          });
        },
        error() {
          return log("WebSocket onerror event");
        }
      };
    }
    constructor(consumer) {
      this.open = this.open.bind(this);
      this.consumer = consumer;
      this.subscriptions = this.consumer;
      this.monitor = new ConnectionMonitor(this);
      this.disconnected = true;
    }
    send(data) {
      if (this.isOpen()) {
        this.webSocket.send(JSON.stringify(data));
        return true;
      } else {
        return false;
      }
    }
    open() {
      if (this.isActive()) {
        log(`Attempted to open WebSocket, but existing socket is ${this.getState()}`);
        return false;
      } else {
        log(`Opening WebSocket, current state is ${this.getState()}, subprotocols: ${protocols}`);
        if (this.webSocket != null) {
          this.uninstallEventHandlers();
        }
        this.webSocket = new WebSocket(this.consumer.url, protocols);
        this.installEventHandlers();
        this.monitor.start();
        return true;
      }
    }
    close(param) {
      if (param == null) {
        param = {
          allowReconnect: true
        };
      }
      const {allowReconnect: allowReconnect} = param;
      if (!allowReconnect) {
        this.monitor.stop();
      }
      if (this.isActive()) {
        return this.webSocket != null ? this.webSocket.close() : undefined;
      }
    }
    reopen() {
      log(`Reopening WebSocket, current state is ${this.getState()}`);
      if (this.isActive()) {
        try {
          return this.close();
        } catch (error) {
          return log("Failed to reopen WebSocket", error);
        } finally {
          log(`Reopening WebSocket in ${this.constructor.reopenDelay}ms`);
          setTimeout(this.open, this.constructor.reopenDelay);
        }
      } else {
        return this.open();
      }
    }
    getProtocol() {
      return this.webSocket != null ? this.webSocket.protocol : undefined;
    }
    isOpen() {
      return this.isState("open");
    }
    isActive() {
      return this.isState("open", "connecting");
    }
    isProtocolSupported() {
      let needle;
      return needle = this.getProtocol(), Array.from(supportedProtocols).includes(needle);
    }
    isState(...states) {
      let needle;
      return needle = this.getState(), Array.from(states).includes(needle);
    }
    getState() {
      for (let state in WebSocket) {
        const value = WebSocket[state];
        if (value === (this.webSocket != null ? this.webSocket.readyState : undefined)) {
          return state.toLowerCase();
        }
      }
      return null;
    }
    installEventHandlers() {
      for (let eventName in this.events) {
        const handler = this.events[eventName].bind(this);
        this.webSocket[`on${eventName}`] = handler;
      }
    }
    uninstallEventHandlers() {
      for (let eventName in this.events) {
        this.webSocket[`on${eventName}`] = function() {};
      }
    }
  }
  Connection.initClass();
  let extend = undefined;
  class Subscription {
    static initClass() {
      extend = function(object, properties) {
        if (properties != null) {
          for (let key in properties) {
            const value = properties[key];
            object[key] = value;
          }
        }
        return object;
      };
    }
    constructor(consumer, params, mixin) {
      this.consumer = consumer;
      if (params == null) {
        params = {};
      }
      this.identifier = JSON.stringify(params);
      extend(this, mixin);
    }
    perform(action, data) {
      if (data == null) {
        data = {};
      }
      data.action = action;
      return this.send(data);
    }
    send(data) {
      return this.consumer.send({
        command: "message",
        identifier: this.identifier,
        data: JSON.stringify(data)
      });
    }
    unsubscribe() {
      return this.consumer.subscriptions.remove(this);
    }
  }
  Subscription.initClass();
  class Subscriptions {
    constructor(consumer) {
      this.consumer = consumer;
      this.subscriptions = [];
    }
    create(channelName, mixin) {
      const channel = channelName;
      const params = typeof channel === "object" ? channel : {
        channel: channel
      };
      const subscription = new Subscription(this.consumer, params, mixin);
      return this.add(subscription);
    }
    add(subscription) {
      this.subscriptions.push(subscription);
      this.consumer.ensureActiveConnection();
      this.notify(subscription, "initialized");
      this.sendCommand(subscription, "subscribe");
      return subscription;
    }
    remove(subscription) {
      this.forget(subscription);
      if (!this.findAll(subscription.identifier).length) {
        this.sendCommand(subscription, "unsubscribe");
      }
      return subscription;
    }
    reject(identifier) {
      return (() => {
        const result = [];
        for (let subscription of Array.from(this.findAll(identifier))) {
          this.forget(subscription);
          this.notify(subscription, "rejected");
          result.push(subscription);
        }
        return result;
      })();
    }
    forget(subscription) {
      this.subscriptions = Array.from(this.subscriptions).filter(s => s !== subscription);
      return subscription;
    }
    findAll(identifier) {
      return Array.from(this.subscriptions).filter(s => s.identifier === identifier);
    }
    reload() {
      return Array.from(this.subscriptions).map(subscription => this.sendCommand(subscription, "subscribe"));
    }
    notifyAll(callbackName, ...args) {
      return Array.from(this.subscriptions).map(subscription => this.notify(subscription, callbackName, ...Array.from(args)));
    }
    notify(subscription, callbackName, ...args) {
      let subscriptions;
      if (typeof subscription === "string") {
        subscriptions = this.findAll(subscription);
      } else {
        subscriptions = [ subscription ];
      }
      return (() => {
        const result = [];
        for (subscription of Array.from(subscriptions)) {
          result.push(typeof subscription[callbackName] === "function" ? subscription[callbackName](...Array.from(args || [])) : undefined);
        }
        return result;
      })();
    }
    sendCommand(subscription, command) {
      const {identifier: identifier} = subscription;
      return this.consumer.send({
        command: command,
        identifier: identifier
      });
    }
  }
  class Consumer {
    constructor(url) {
      this.url = url;
      this.subscriptions = new Subscriptions(this);
      this.connection = new Connection(this);
    }
    send(data) {
      return this.connection.send(data);
    }
    connect() {
      return this.connection.open();
    }
    disconnect() {
      return this.connection.close({
        allowReconnect: false
      });
    }
    ensureActiveConnection() {
      if (!this.connection.isActive()) {
        return this.connection.open();
      }
    }
  }
  let defaultExport = {};
  defaultExport.ActionCable = {
    WebSocket: window.WebSocket,
    logger: window.console,
    createConsumer(url) {
      if (url == null) {
        let left;
        url = (left = this.getConfig("url")) != null ? left : this.INTERNAL.default_mount_path;
      }
      return new Consumer(this.createWebSocketURL(url));
    },
    getConfig(name) {
      const element = document.head.querySelector(`meta[name='action-cable-${name}']`);
      return element != null ? element.getAttribute("content") : undefined;
    },
    createWebSocketURL(url) {
      if (url && !/^wss?:/i.test(url)) {
        const a = document.createElement("a");
        a.href = url;
        a.href = a.href;
        a.protocol = a.protocol.replace("http", "ws");
        return a.href;
      } else {
        return url;
      }
    },
    startDebugging() {
      return this.debugging = true;
    },
    stopDebugging() {
      return this.debugging = null;
    },
    log(...messages) {
      if (this.debugging) {
        messages.push(Date.now());
        return this.logger.log("[ActionCable]", ...Array.from(messages));
      }
    }
  };
  return defaultExport;
});
