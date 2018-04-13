/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
//= require ./connection
//= require ./subscriptions
//= require ./subscription

// The ActionCable.Consumer establishes the connection to a server-side Ruby Connection object. Once established,
// the ActionCable.ConnectionMonitor will ensure that its properly maintained through heartbeats and checking for stale updates.
// The Consumer instance is also the gateway to establishing subscriptions to desired channels through the #createSubscription
// method.
//
// The following example shows how this can be setup:
//
//   @App = {}
//   App.cable = ActionCable.createConsumer "ws://example.com/accounts/1"
//   App.appearance = App.cable.subscriptions.create "AppearanceChannel"
//
// For more details on how you'd configure an actual channel subscription, see ActionCable.Subscription.
//
// When a consumer is created, it automatically connects with the server.
//
// To disconnect from the server, call
//
//   App.cable.disconnect()
//
// and to restart the connection:
//
//   App.cable.connect()
//
// Any channel subscriptions which existed prior to disconnecting will
// automatically resubscribe.
ActionCable.Consumer = class Consumer {
  constructor(url) {
    this.url = url;
    this.subscriptions = new ActionCable.Subscriptions(this);
    this.connection = new ActionCable.Connection(this);
  }

  send(data) {
    return this.connection.send(data);
  }

  connect() {
    return this.connection.open();
  }

  disconnect() {
    return this.connection.close({allowReconnect: false});
  }

  ensureActiveConnection() {
    if (!this.connection.isActive()) {
      return this.connection.open();
    }
  }
};
