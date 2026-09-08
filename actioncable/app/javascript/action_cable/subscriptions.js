import logger from "./logger"
import Subscription from "./subscription"
import SubscriptionGuarantor from "./subscription_guarantor"

// Collection class for creating (and internally managing) channel subscriptions.
// The only method intended to be triggered by the user is ActionCable.Subscriptions#create,
// and it should be called through the consumer like so:
//
//   App = {}
//   App.cable = ActionCable.createConsumer("ws://example.com/accounts/1")
//   App.appearance = App.cable.subscriptions.create("AppearanceChannel")
//
// For more details on how you'd configure an actual channel subscription, see ActionCable.Subscription.

export default class Subscriptions {
  constructor(consumer) {
    this.consumer = consumer
    this.guarantor = new SubscriptionGuarantor(this)
    this.subscriptions = []

    this.pendingUnsubscribes = {}
    this.postponedSubscribes = {}
  }

  create(channelName, mixin) {
    const channel = channelName
    const params = typeof channel === "object" ? channel : {channel}
    const subscription = new Subscription(this.consumer, params, mixin)
    return this.add(subscription)
  }

  // Private

  add(subscription) {
    this.subscriptions.push(subscription)
    this.consumer.ensureActiveConnection()
    this.notify(subscription, "initialized")
    this.subscribe(subscription)
    return subscription
  }

  remove(subscription) {
    this.forget(subscription)
    if (!this.findAll(subscription.identifier).length) {
      this.unsubscribe(subscription)
    }
    return subscription
  }

  reject(identifier) {
    return this.findAll(identifier).map((subscription) => {
      this.forget(subscription)
      this.notify(subscription, "rejected")
      return subscription
    })
  }

  forget(subscription) {
    this.guarantor.forget(subscription)
    this.subscriptions = (this.subscriptions.filter((s) => s !== subscription))
    return subscription
  }

  findAll(identifier) {
    return this.subscriptions.filter((s) => s.identifier === identifier)
  }

  reload() {
    return this.subscriptions.map((subscription) =>
      this.subscribe(subscription))
  }

  notifyAll(callbackName, ...args) {
    return this.subscriptions.map((subscription) =>
      this.notify(subscription, callbackName, ...args))
  }

  notify(subscription, callbackName, ...args) {
    let subscriptions
    if (typeof subscription === "string") {
      subscriptions = this.findAll(subscription)
    } else {
      subscriptions = [subscription]
    }

    return subscriptions.map((subscription) =>
      (typeof subscription[callbackName] === "function" ? subscription[callbackName](...args) : undefined))
  }

  subscribe(subscription) {
    const {identifier} = subscription
    if (this.pendingUnsubscribes[identifier]) {
      // An unsubscribe for this identifier has been issued recently.
      // Postpone sending the subscribe command to avoid race conditions at the server
      // (the server MAY process commands concurrently, not in order).
      if (this.postponedSubscribes[identifier]) return

      this.postponedSubscribes[identifier] = setTimeout(() => {
        delete this.postponedSubscribes[identifier]
        this.findAll(identifier).forEach((s) => this.subscribe(s))
      }, this.constructor.subscribeCooldownInterval)
      return
    }
    if (this.sendCommand(subscription, "subscribe")) {
      this.guarantor.guarantee(subscription)
    }
  }

  unsubscribe(subscription) {
    const {identifier} = subscription
    this.sendCommand(subscription, "unsubscribe")
    this.resetUnsubscribeCooldownLater(identifier)
  }

  confirmSubscription(identifier) {
    logger.log(`Subscription confirmed ${identifier}`)
    const subscriptions = this.findAll(identifier)
    if (subscriptions.length === 0) {
      // Unsubscribed before confirmation arrived -> ensure unsubscribed server-side
      this.unsubscribe({ identifier })
      return []
    }
    // Select only subscriptions waiting for confirmation (ignore double-confirmed subscriptions)
    const confirmed = subscriptions.filter((subscription) => this.guarantor.isPending(subscription))
    confirmed.forEach((subscription) => this.guarantor.forget(subscription))
    return confirmed
  }

  resetUnsubscribeCooldownLater(identifier) {
    if (this.pendingUnsubscribes[identifier]) {
      clearTimeout(this.pendingUnsubscribes[identifier])
    }
    this.pendingUnsubscribes[identifier] = setTimeout(() => {
      delete this.pendingUnsubscribes[identifier]
    }, this.constructor.subscribeCooldownInterval)
  }

  sendCommand(subscription, command) {
    const {identifier} = subscription
    return this.consumer.send({command, identifier})
  }
}

// How long (ms) to hold back a subscribe command after an unsubscribe has been issued
// for the same identifier (to prevent subscribe-unsubscribe race conditions).
Subscriptions.subscribeCooldownInterval = 250
