const {module, test} = QUnit;
const {consumerTest} = ActionCable.TestHelpers;

module("ActionCable.Subscription", function() {
  consumerTest("#initialized callback", ({server, consumer, assert, done}) =>
    consumer.subscriptions.create("chat", {
      initialized() {
        assert.ok(true);
        return done();
      }
    }
    )
  );

  consumerTest("#connected callback", function({server, consumer, assert, done}) {
    const subscription = consumer.subscriptions.create("chat", {
      connected() {
        assert.ok(true);
        return done();
      }
    }
    );

    return server.broadcastTo(subscription, {message_type: "confirmation"});
  });

  consumerTest("#disconnected callback", function({server, consumer, assert, done}) {
    const subscription = consumer.subscriptions.create("chat", {
      disconnected() {
        assert.ok(true);
        return done();
      }
    }
    );

    return server.broadcastTo(subscription, {message_type: "confirmation"}, () => server.close());
  });

  return consumerTest("#perform", function({consumer, server, assert, done}) {
    const subscription = consumer.subscriptions.create("chat", {
      connected() {
        return this.perform({publish: "hi"});
      }
    }
    );

    server.on("message", function(message) {
      const data = JSON.parse(message);
      assert.equal(data.identifier, subscription.identifier);
      assert.equal(data.command, "message");
      assert.deepEqual(data.data, JSON.stringify({action: { publish: "hi" }}));
      return done();
    });

    return server.broadcastTo(subscription, {message_type: "confirmation"});
  });
});
