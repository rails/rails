import * as ActionCable from "../../../../app/javascript/action_cable/index"

const {module, test} = QUnit

module("ActionCable.ConnectionMonitor", hooks => {
  let monitor
  hooks.beforeEach(() => monitor = new ActionCable.ConnectionMonitor({}))

  module("#getPollInterval", hooks => {
    hooks.beforeEach(() => Math._random = Math.random)
    hooks.afterEach(() => Math.random = Math._random)

    const { staleThreshold, reconnectionBackoffRate } = ActionCable.ConnectionMonitor
    const backoffFactor = 1 + reconnectionBackoffRate
    const ms = 1000

    test("uses exponential backoff", assert => {
      Math.random = () => 0

      monitor.reconnectAttempts = 0
      assert.equal(monitor.getPollInterval(), staleThreshold * ms)

      monitor.reconnectAttempts = 1
      assert.equal(monitor.getPollInterval(), staleThreshold * backoffFactor * ms)

      monitor.reconnectAttempts = 2
      assert.equal(monitor.getPollInterval(), staleThreshold * backoffFactor * backoffFactor * ms)
    })

    test("caps exponential backoff after some number of reconnection attempts", assert => {
      Math.random = () => 0
      monitor.reconnectAttempts = 42
      const cappedPollInterval = monitor.getPollInterval()

      monitor.reconnectAttempts = 9001
      assert.equal(monitor.getPollInterval(), cappedPollInterval)
    })

    test("uses 100% jitter when 0 reconnection attempts", assert => {
      Math.random = () => 0
      assert.equal(monitor.getPollInterval(), staleThreshold * ms)

      Math.random = () => 0.5
      assert.equal(monitor.getPollInterval(), staleThreshold * 1.5 * ms)
    })

    test("uses reconnectionBackoffRate for jitter when >0 reconnection attempts", assert => {
      monitor.reconnectAttempts = 1

      Math.random = () => 0.25
      assert.equal(monitor.getPollInterval(), staleThreshold * backoffFactor * (1 + reconnectionBackoffRate * 0.25) * ms)

      Math.random = () => 0.5
      assert.equal(monitor.getPollInterval(), staleThreshold * backoffFactor * (1 + reconnectionBackoffRate * 0.5) * ms)
    })

    test("applies jitter after capped exponential backoff", assert => {
      monitor.reconnectAttempts = 9001

      Math.random = () => 0
      const withoutJitter = monitor.getPollInterval()
      Math.random = () => 0.5
      const withJitter = monitor.getPollInterval()

      assert.ok(withJitter > withoutJitter)
    })
  })
})
