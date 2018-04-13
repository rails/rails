/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
//= require mock-socket

const {TestHelpers} = ActionCable;

TestHelpers.consumerTest = function(name, options, callback) {
  if (options == null) { options = {}; }
  if (callback == null) {
    callback = options;
    options = {};
  }

  if (options.url == null) { options.url = TestHelpers.testURL; }

  return QUnit.test(name, function(assert) {
    const doneAsync = assert.async();

    ActionCable.WebSocket = MockWebSocket;
    const server = new MockServer(options.url);
    const consumer = ActionCable.createConsumer(options.url);

    server.on("connection", function() {
      const clients = server.clients();
      assert.equal(clients.length, 1);
      return assert.equal(clients[0].readyState, WebSocket.OPEN);
    });

    server.broadcastTo = function(subscription, data, callback) {
      if (data == null) { data = {}; }
      data.identifier = subscription.identifier;

      if (data.message_type) {
        data.type = ActionCable.INTERNAL.message_types[data.message_type];
        delete data.message_type;
      }

      server.send(JSON.stringify(data));
      return TestHelpers.defer(callback);
    };

    const done = function() {
      consumer.disconnect();
      server.close();
      return doneAsync();
    };

    const testData = {assert, consumer, server, done};

    if (options.connect === false) {
      return callback(testData);
    } else {
      server.on("connection", function() {
        testData.client = server.clients()[0];
        return callback(testData);
      });
      return consumer.connect();
    }
  });
};
