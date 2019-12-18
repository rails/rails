import Subscription from "./subscription"

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
    this.subscriptions = []
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
    this.sendCommand(subscription, "subscribe")
    return subscription
  }

  remove(subscription) {
    this.forget(subscription)
    if (!this.findAll(subscription.identifier).length) {
      this.sendCommand(subscription, "unsubscribe")
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
    this.subscriptions = (this.subscriptions.filter((s) => s !== subscription))
    return subscription
  }

  findAll(identifier) {
    return this.subscriptions.filter((s) => s.identifier === identifier)
  }

  reload() {
    return this.subscriptions.map((subscription) =>
      this.sendCommand(subscription, "subscribe"))
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

  sendCommand(subscription, command) {
    const {identifier} = subscription
    return this.consumer.send({command, identifier})
  }
}
