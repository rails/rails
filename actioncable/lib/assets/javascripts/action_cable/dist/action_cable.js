(function() {
  this.ActionCable = {
    INTERNAL: {
      "identifiers": {
        "ping": "_ping"
      },
      "message_types": {
        "confirmation": "confirm_subscription",
        "rejection": "reject_subscription"
      }
    },
    createConsumer: function(url) {
      if (url == null) {
        url = this.getConfig("url");
      }
      return new ActionCable.Consumer(this.createWebSocketURL(url));
    },
    getConfig: function(name) {
      var element;
      element = document.head.querySelector("meta[name='action-cable-" + name + "']");
      return element != null ? element.getAttribute("content") : void 0;
    },
    createWebSocketURL: function(url) {
      var a;
      if (url && !/^wss?:/i.test(url)) {
        a = document.createElement("a");
        a.href = url;
        a.href = a.href;
        a.protocol = a.protocol.replace("http", "ws");
        return a.href;
      } else {
        return url;
      }
    }
  };

}).call(this);
(function() {
  var message_types,
    bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    slice = [].slice,
    indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  message_types = ActionCable.INTERNAL.message_types;

  ActionCable.Connection = (function() {
    Connection.reopenDelay = 500;

    function Connection(consumer) {
      this.consumer = consumer;
      this.open = bind(this.open, this);
      this.open();
    }

    Connection.prototype.send = function(data) {
      if (this.isOpen()) {
        this.webSocket.send(JSON.stringify(data));
        return true;
      } else {
        return false;
      }
    };

    Connection.prototype.open = function() {
      if (this.webSocket && !this.isState("closed")) {
        throw new Error("Existing connection must be closed before opening");
      } else {
        this.webSocket = new WebSocket(this.consumer.url);
        this.installEventHandlers();
        return true;
      }
    };

    Connection.prototype.close = function() {
      var ref;
      return (ref = this.webSocket) != null ? ref.close() : void 0;
    };

    Connection.prototype.reopen = function() {
      if (this.isState("closed")) {
        return this.open();
      } else {
        try {
          return this.close();
        } finally {
          setTimeout(this.open, this.constructor.reopenDelay);
        }
      }
    };

    Connection.prototype.isOpen = function() {
      return this.isState("open");
    };

    Connection.prototype.isState = function() {
      var ref, states;
      states = 1 <= arguments.length ? slice.call(arguments, 0) : [];
      return ref = this.getState(), indexOf.call(states, ref) >= 0;
    };

    Connection.prototype.getState = function() {
      var ref, state, value;
      for (state in WebSocket) {
        value = WebSocket[state];
        if (value === ((ref = this.webSocket) != null ? ref.readyState : void 0)) {
          return state.toLowerCase();
        }
      }
      return null;
    };

    Connection.prototype.installEventHandlers = function() {
      var eventName, handler;
      for (eventName in this.events) {
        handler = this.events[eventName].bind(this);
        this.webSocket["on" + eventName] = handler;
      }
    };

    Connection.prototype.events = {
      message: function(event) {
        var identifier, message, ref, type;
        ref = JSON.parse(event.data), identifier = ref.identifier, message = ref.message, type = ref.type;
        switch (type) {
          case message_types.confirmation:
            return this.consumer.subscriptions.notify(identifier, "connected");
          case message_types.rejection:
            return this.consumer.subscriptions.reject(identifier);
          default:
            return this.consumer.subscriptions.notify(identifier, "received", message);
        }
      },
      open: function() {
        this.disconnected = false;
        return this.consumer.subscriptions.reload();
      },
      close: function() {
        return this.disconnect();
      },
      error: function() {
        return this.disconnect();
      }
    };

    Connection.prototype.disconnect = function() {
      if (this.disconnected) {
        return;
      }
      this.disconnected = true;
      return this.consumer.subscriptions.notifyAll("disconnected");
    };

    return Connection;

  })();

}).call(this);
(function() {
  var bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  ActionCable.ConnectionMonitor = (function() {
    var clamp, now, secondsSince;

    ConnectionMonitor.pollInterval = {
      min: 3,
      max: 30
    };

    ConnectionMonitor.staleThreshold = 6;

    ConnectionMonitor.prototype.identifier = ActionCable.INTERNAL.identifiers.ping;

    function ConnectionMonitor(consumer) {
      this.consumer = consumer;
      this.visibilityDidChange = bind(this.visibilityDidChange, this);
      this.consumer.subscriptions.add(this);
      this.start();
    }

    ConnectionMonitor.prototype.connected = function() {
      this.reset();
      this.pingedAt = now();
      return delete this.disconnectedAt;
    };

    ConnectionMonitor.prototype.disconnected = function() {
      return this.disconnectedAt = now();
    };

    ConnectionMonitor.prototype.received = function() {
      return this.pingedAt = now();
    };

    ConnectionMonitor.prototype.reset = function() {
      return this.reconnectAttempts = 0;
    };

    ConnectionMonitor.prototype.start = function() {
      this.reset();
      delete this.stoppedAt;
      this.startedAt = now();
      this.poll();
      return document.addEventListener("visibilitychange", this.visibilityDidChange);
    };

    ConnectionMonitor.prototype.stop = function() {
      this.stoppedAt = now();
      return document.removeEventListener("visibilitychange", this.visibilityDidChange);
    };

    ConnectionMonitor.prototype.poll = function() {
      return setTimeout((function(_this) {
        return function() {
          if (!_this.stoppedAt) {
            _this.reconnectIfStale();
            return _this.poll();
          }
        };
      })(this), this.getInterval());
    };

    ConnectionMonitor.prototype.getInterval = function() {
      var interval, max, min, ref;
      ref = this.constructor.pollInterval, min = ref.min, max = ref.max;
      interval = 5 * Math.log(this.reconnectAttempts + 1);
      return clamp(interval, min, max) * 1000;
    };

    ConnectionMonitor.prototype.reconnectIfStale = function() {
      if (this.connectionIsStale()) {
        this.reconnectAttempts++;
        if (!this.disconnectedRecently()) {
          return this.consumer.connection.reopen();
        }
      }
    };

    ConnectionMonitor.prototype.connectionIsStale = function() {
      var ref;
      return secondsSince((ref = this.pingedAt) != null ? ref : this.startedAt) > this.constructor.staleThreshold;
    };

    ConnectionMonitor.prototype.disconnectedRecently = function() {
      return this.disconnectedAt && secondsSince(this.disconnectedAt) < this.constructor.staleThreshold;
    };

    ConnectionMonitor.prototype.visibilityDidChange = function() {
      if (document.visibilityState === "visible") {
        return setTimeout((function(_this) {
          return function() {
            if (_this.connectionIsStale() || !_this.consumer.connection.isOpen()) {
              return _this.consumer.connection.reopen();
            }
          };
        })(this), 200);
      }
    };

    now = function() {
      return new Date().getTime();
    };

    secondsSince = function(time) {
      return (now() - time) / 1000;
    };

    clamp = function(number, min, max) {
      return Math.max(min, Math.min(max, number));
    };

    return ConnectionMonitor;

  })();

}).call(this);
(function() {
  var slice = [].slice;

  ActionCable.Subscriptions = (function() {
    function Subscriptions(consumer) {
      this.consumer = consumer;
      this.subscriptions = [];
    }

    Subscriptions.prototype.create = function(channelName, mixin) {
      var channel, params;
      channel = channelName;
      params = typeof channel === "object" ? channel : {
        channel: channel
      };
      return new ActionCable.Subscription(this, params, mixin);
    };

    Subscriptions.prototype.add = function(subscription) {
      this.subscriptions.push(subscription);
      this.notify(subscription, "initialized");
      return this.sendCommand(subscription, "subscribe");
    };

    Subscriptions.prototype.remove = function(subscription) {
      this.forget(subscription);
      if (!this.findAll(subscription.identifier).length) {
        return this.sendCommand(subscription, "unsubscribe");
      }
    };

    Subscriptions.prototype.reject = function(identifier) {
      var i, len, ref, results, subscription;
      ref = this.findAll(identifier);
      results = [];
      for (i = 0, len = ref.length; i < len; i++) {
        subscription = ref[i];
        this.forget(subscription);
        results.push(this.notify(subscription, "rejected"));
      }
      return results;
    };

    Subscriptions.prototype.forget = function(subscription) {
      var s;
      return this.subscriptions = (function() {
        var i, len, ref, results;
        ref = this.subscriptions;
        results = [];
        for (i = 0, len = ref.length; i < len; i++) {
          s = ref[i];
          if (s !== subscription) {
            results.push(s);
          }
        }
        return results;
      }).call(this);
    };

    Subscriptions.prototype.findAll = function(identifier) {
      var i, len, ref, results, s;
      ref = this.subscriptions;
      results = [];
      for (i = 0, len = ref.length; i < len; i++) {
        s = ref[i];
        if (s.identifier === identifier) {
          results.push(s);
        }
      }
      return results;
    };

    Subscriptions.prototype.reload = function() {
      var i, len, ref, results, subscription;
      ref = this.subscriptions;
      results = [];
      for (i = 0, len = ref.length; i < len; i++) {
        subscription = ref[i];
        results.push(this.sendCommand(subscription, "subscribe"));
      }
      return results;
    };

    Subscriptions.prototype.notifyAll = function() {
      var args, callbackName, i, len, ref, results, subscription;
      callbackName = arguments[0], args = 2 <= arguments.length ? slice.call(arguments, 1) : [];
      ref = this.subscriptions;
      results = [];
      for (i = 0, len = ref.length; i < len; i++) {
        subscription = ref[i];
        results.push(this.notify.apply(this, [subscription, callbackName].concat(slice.call(args))));
      }
      return results;
    };

    Subscriptions.prototype.notify = function() {
      var args, callbackName, i, len, results, subscription, subscriptions;
      subscription = arguments[0], callbackName = arguments[1], args = 3 <= arguments.length ? slice.call(arguments, 2) : [];
      if (typeof subscription === "string") {
        subscriptions = this.findAll(subscription);
      } else {
        subscriptions = [subscription];
      }
      results = [];
      for (i = 0, len = subscriptions.length; i < len; i++) {
        subscription = subscriptions[i];
        results.push(typeof subscription[callbackName] === "function" ? subscription[callbackName].apply(subscription, args) : void 0);
      }
      return results;
    };

    Subscriptions.prototype.sendCommand = function(subscription, command) {
      var identifier;
      identifier = subscription.identifier;
      if (identifier === ActionCable.INTERNAL.identifiers.ping) {
        return this.consumer.connection.isOpen();
      } else {
        return this.consumer.send({
          command: command,
          identifier: identifier
        });
      }
    };

    return Subscriptions;

  })();

}).call(this);
(function() {
  ActionCable.Subscription = (function() {
    var extend;

    function Subscription(subscriptions, params, mixin) {
      this.subscriptions = subscriptions;
      if (params == null) {
        params = {};
      }
      this.identifier = JSON.stringify(params);
      extend(this, mixin);
      this.subscriptions.add(this);
      this.consumer = this.subscriptions.consumer;
    }

    Subscription.prototype.perform = function(action, data) {
      if (data == null) {
        data = {};
      }
      data.action = action;
      return this.send(data);
    };

    Subscription.prototype.send = function(data) {
      return this.consumer.send({
        command: "message",
        identifier: this.identifier,
        data: JSON.stringify(data)
      });
    };

    Subscription.prototype.unsubscribe = function() {
      return this.subscriptions.remove(this);
    };

    extend = function(object, properties) {
      var key, value;
      if (properties != null) {
        for (key in properties) {
          value = properties[key];
          object[key] = value;
        }
      }
      return object;
    };

    return Subscription;

  })();

}).call(this);
(function() {
  ActionCable.Consumer = (function() {
    function Consumer(url) {
      this.url = url;
      this.subscriptions = new ActionCable.Subscriptions(this);
      this.connection = new ActionCable.Connection(this);
      this.connectionMonitor = new ActionCable.ConnectionMonitor(this);
    }

    Consumer.prototype.send = function(data) {
      return this.connection.send(data);
    };

    return Consumer;

  })();

}).call(this);
