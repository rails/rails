import logger from "./logger"

// Responsible for ensuring the cable connection is in good health by validating the heartbeat pings sent from the server, and attempting
// revival reconnections if things go astray. Internal class, not intended for direct user manipulation.

const now = () => new Date().getTime()

const secondsSince = time => (now() - time) / 1000

class ConnectionMonitor {
  constructor(connection) {
    this.visibilityDidChange = this.visibilityDidChange.bind(this)
    this.connection = connection
    this.reconnectAttempts = 0
  }

  start() {
    if (!this.isRunning()) {
      this.startedAt = now()
      delete this.stoppedAt
      this.startPolling()
      addEventListener("visibilitychange", this.visibilityDidChange)
      logger.log(`ConnectionMonitor started. stale threshold = ${this.constructor.staleThreshold} s`)
    }
  }

  stop() {
    if (this.isRunning()) {
      this.stoppedAt = now()
      this.stopPolling()
      removeEventListener("visibilitychange", this.visibilityDidChange)
      logger.log("ConnectionMonitor stopped")
    }
  }

  isRunning() {
    return this.startedAt && !this.stoppedAt
  }

  recordPing() {
    this.pingedAt = now()
  }

  recordConnect() {
    this.reconnectAttempts = 0
    this.recordPing()
    delete this.disconnectedAt
    logger.log("ConnectionMonitor recorded connect")
  }

  recordDisconnect() {
    this.disconnectedAt = now()
    logger.log("ConnectionMonitor recorded disconnect")
  }

  // Private

  startPolling() {
    this.stopPolling()
    this.poll()
  }

  stopPolling() {
    clearTimeout(this.pollTimeout)
  }

  poll() {
    this.pollTimeout = setTimeout(() => {
      this.reconnectIfStale()
      this.poll()
    }
    , this.getPollInterval())
  }

  getPollInterval() {
    const { staleThreshold, reconnectionBackoffRate } = this.constructor
    const backoff = Math.pow(1 + reconnectionBackoffRate, Math.min(this.reconnectAttempts, 10))
    const jitterMax = this.reconnectAttempts === 0 ? 1.0 : reconnectionBackoffRate
    const jitter = jitterMax * Math.random()
    return staleThreshold * 1000 * backoff * (1 + jitter)
  }

  reconnectIfStale() {
    if (this.connectionIsStale()) {
      logger.log(`ConnectionMonitor detected stale connection. reconnectAttempts = ${this.reconnectAttempts}, time stale = ${secondsSince(this.refreshedAt)} s, stale threshold = ${this.constructor.staleThreshold} s`)
      this.reconnectAttempts++
      if (this.disconnectedRecently()) {
        logger.log(`ConnectionMonitor skipping reopening recent disconnect. time disconnected = ${secondsSince(this.disconnectedAt)} s`)
      } else {
        logger.log("ConnectionMonitor reopening")
        this.connection.reopen()
      }
    }
  }

  get refreshedAt() {
    return this.pingedAt ? this.pingedAt : this.startedAt
  }

  connectionIsStale() {
    return secondsSince(this.refreshedAt) > this.constructor.staleThreshold
  }

  disconnectedRecently() {
    return this.disconnectedAt && (secondsSince(this.disconnectedAt) < this.constructor.staleThreshold)
  }

  visibilityDidChange() {
    if (document.visibilityState === "visible") {
      setTimeout(() => {
        if (this.connectionIsStale() || !this.connection.isOpen()) {
          logger.log(`ConnectionMonitor reopening stale connection on visibilitychange. visibilityState = ${document.visibilityState}`)
          this.connection.reopen()
        }
      }
      , 200)
    }
  }

}

ConnectionMonitor.staleThreshold = 6 // Server::Connections::BEAT_INTERVAL * 2 (missed two pings)
ConnectionMonitor.reconnectionBackoffRate = 0.15

export default ConnectionMonitor
