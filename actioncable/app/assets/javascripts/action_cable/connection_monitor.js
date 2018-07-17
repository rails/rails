// Responsible for ensuring the cable connection is in good health by validating the heartbeat pings sent from the server, and attempting
// revival reconnections if things go astray. Internal class, not intended for direct user manipulation.
let now = undefined;
let secondsSince = undefined;
let clamp = undefined;
const Cls = (ActionCable.ConnectionMonitor = class ConnectionMonitor {
  static initClass() {
    this.pollInterval = {
      min: 3,
      max: 30
    };

    this.staleThreshold = 6;

    now = () => new Date().getTime();

    secondsSince = time => (now() - time) / 1000;

    clamp = (number, min, max) => Math.max(min, Math.min(max, number));
     // Server::Connections::BEAT_INTERVAL * 2 (missed two pings)
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
      return ActionCable.log(`ConnectionMonitor started. pollInterval = ${this.getPollInterval()} ms`);
    }
  }

  stop() {
    if (this.isRunning()) {
      this.stoppedAt = now();
      this.stopPolling();
      document.removeEventListener("visibilitychange", this.visibilityDidChange);
      return ActionCable.log("ConnectionMonitor stopped");
    }
  }

  isRunning() {
    return (this.startedAt != null) && (this.stoppedAt == null);
  }

  recordPing() {
    return this.pingedAt = now();
  }

  recordConnect() {
    this.reconnectAttempts = 0;
    this.recordPing();
    delete this.disconnectedAt;
    return ActionCable.log("ConnectionMonitor recorded connect");
  }

  recordDisconnect() {
    this.disconnectedAt = now();
    return ActionCable.log("ConnectionMonitor recorded disconnect");
  }

  // Private

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
    }
    , this.getPollInterval());
  }

  getPollInterval() {
    const {min, max} = this.constructor.pollInterval;
    const interval = 5 * Math.log(this.reconnectAttempts + 1);
    return Math.round(clamp(interval, min, max) * 1000);
  }

  reconnectIfStale() {
    if (this.connectionIsStale()) {
      ActionCable.log(`ConnectionMonitor detected stale connection. reconnectAttempts = ${this.reconnectAttempts}, pollInterval = ${this.getPollInterval()} ms, time disconnected = ${secondsSince(this.disconnectedAt)} s, stale threshold = ${this.constructor.staleThreshold} s`);
      this.reconnectAttempts++;
      if (this.disconnectedRecently()) {
        return ActionCable.log("ConnectionMonitor skipping reopening recent disconnect");
      } else {
        ActionCable.log("ConnectionMonitor reopening");
        return this.connection.reopen();
      }
    }
  }

  connectionIsStale() {
    return secondsSince(this.pingedAt != null ? this.pingedAt : this.startedAt) > this.constructor.staleThreshold;
  }

  disconnectedRecently() {
    return this.disconnectedAt && (secondsSince(this.disconnectedAt) < this.constructor.staleThreshold);
  }

  visibilityDidChange() {
    if (document.visibilityState === "visible") {
      return setTimeout(() => {
        if (this.connectionIsStale() || !this.connection.isOpen()) {
          ActionCable.log(`ConnectionMonitor reopening stale connection on visibilitychange. visbilityState = ${document.visibilityState}`);
          return this.connection.reopen();
        }
      }
      , 200);
    }
  }
});
Cls.initClass();
return Cls;
