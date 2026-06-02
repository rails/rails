**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Action Cable Overview
=====================

In this guide, you will learn how to use Action Cable to add real-time bi-directional communication to your Rails application.

After reading this guide, you will know:

* What Action Cable is and how it works.
* Action Cable core concepts such as Connections, Channels, and Streams.
* How to use the JavaScript client library.
* The pub/sub adapters available for Action Cable.
* How to configure and deploy Action Cable.

--------------------------------------------------------------------------------

What is Action Cable?
---------------------

Action Cable provides a mechanism for real-time bi-directional communication with the web browser by pairing [WebSockets](https://en.wikipedia.org/wiki/WebSocket) with [Pub/Sub](https://en.wikipedia.org/wiki/Publish-subscribe_pattern). Using it, we can receive and broadcast data to the browser in real-time with ease.

### WebSockets

The WebSocket protocol enables bi-directional communication between a browser and server over a persistent connection. It's standardized in [RFC 6455](https://datatracker.ietf.org/doc/html/rfc6455).

In contrast, HTTP is a stateless protocol reliant on the browser making a request to which a server sends a response. The WebSocket protocol is completely distinct from HTTP but is designed to work in tandem with it.

A WebSocket connection starts with an HTTP `GET` request asking the server to upgrade the connection to a WebSocket. The server will then repond with a `101 Switching Protocols` status code and the connection will switch over to a WebSocket. This is known as a _handshake_.

![Sequence diagram depicting the WebSocket handshake](images/action_cable/handshake.png)

WebSocket connections in the browser are managed using a [JavaScript API](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket). Action Cable provides a JavaScript library to abstract some of the complexity.

### Pub/Sub

[Pub/Sub](https://en.wikipedia.org/wiki/Publish-subscribe_pattern) is shorthand for _publish-subscribe_. It's a software messaging paradigm where entities can _subscribe_ to data streams. Other entities, called _publishers_, can then publish data to these streams for delivery to all subscribers.

This paradigm makes it easy to broadcast data based on _topics_, rather than sending data to specific receivers.

Action Cable doesn't implement pub/sub itself, instead it relies on an external service via an adapter. The default is [Solid Cable](https://github.com/rails/solid_cable) which uses SQLite for message storage and delivery. Adapters for PostgreSQL and Redis are also available.

### The Server

Action Cable implements its own server. The server is responsible for handling the WebSocket connection and incoming and outgoing messages, while delegating to the pub/sub provider to track subscriptions and broadcasts.

It uses [Rack hijacking](https://github.com/rack/rack/blob/main/SPEC.rdoc#hijacking) to take control of the HTTP connection from your application server and processes messages using an event loop. It maintains its own thread pool separate from the application server.

The server uses the WebSocket implementation provided by [websocket-driver](https://github.com/faye/websocket-driver-ruby), [nio4r](https://github.com/celluloid/nio4r) for the event loop, and [concurrent-ruby](https://github.com/ruby-concurrency/concurrent-ruby) for the thread pool.

The server implementation is adapterized. This means the default implementation can be replaced using third-party libraries. This is useful if you wish to use a different WebSocket implementation, a different delivery mechanism than WebSockets, or a different concurrency model.

### Messaging Protocol

Action Cable standardizes a JSON-based messaging protocol between the client and server. It is used to create and confirm channel subscriptions, perform server actions, process heartbeat pings, and many other use cases we'll cover in the rest of this guide.

The server components and JavaScript client library abstract the details of this protocol so you're unlikely to craft raw messages manually.

Connections, Channels, and Streams
----------------------------------

In this section we'll discuss how to create a WebSocket connection using Action Cable, and then receive and broadcast messages over that connection.

### Creating a Connection

The first step to create a WebSocket connection is the _handshake_ to switch the connection from HTTP to a WebSocket. Action Cable's JavaScript library can be used for this:

```js
import { createConsumer } from "@rails/actioncable"

const consumer = createConsumer()
consumer.connect()
```

A _consumer_ is Action Cable's terminology for a client that can send and receive messages. Once the JavaScript client has triggered the handshake, we need to handle it on the server. This is done in `ApplicationCable::Connection`.

```ruby
# app/channels/application_cable/connection.rb

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = authenticate_user
    end

    private
      def authenticate_user
        # Authenticate the user using cookies.

        # Reject the connection using `reject_unauthorized_connection`
        # if authentication fails.
      end
  end
end
```

An instance of `ApplicationCable::Connection` is created for each connection. Creating a consumer on the client will trigger the `connect` method shown above. Use cookies to authenticate the user, rejecting the connection if it fails. `current_user` is set on the connection to uniquely identify it.

The Rails `session` cannot be accessed in this context. If your session data is stored in a cookie, you can access it using:

```ruby
cookie_name = Rails.app.config.session_options[:key]
cookies.encrypted[cookie_name]
```

If you're using a different session store, you'll need to create a special cookie to authenticate the user when creating a WebSocket connection, or manually read the data from your chosen session store.

Cookies are not available once the connection has been upgraded to a WebSocket.

After the handshake has succeeded, the client can subscribe to _streams_ to which messages can be broadcast or received. On the server, this is handled by _channels_, which are analogous to _controllers_ in a typical MVC setup. Channels have access to the values defined by [`identified_by`](https://api.rubyonrails.org/classes/ActionCable/Connection/Identification/ClassMethods.html#method-i-identified_by) in the `Connection` which can be used for authorization checks.

```ruby
# app/channels/chat_channel.rb

class ChatChannel < ApplicationCable::Channel
  def subscribed
    # `current_user` is set by the connection.
    # Authorize the subscription before allowing it.
    if current_user.can_access?(params[:room])
      stream_from "chat_#{params[:room]}"
    end
  end
end
```

The [`stream_from`](https://api.rubyonrails.org/classes/ActionCable/Channel/Streams.html#method-i-stream_from) method takes the name of a stream to subscribe to. Stream names are ephemeral and don't need to be explicitly created. They are global across your application and can be thought of as a _topic_ to which messages are broadcast.

On the client, subscribe to the chat channel and supply a `:room` parameter as:

```js
import { createConsumer } from "@rails/actioncable"
const consumer = createConsumer()

consumer.subscriptions.create({
  channel: "ChatChannel",
  room: "general"
})
```

Once the connection and subscription has been established, we can broadcast and receive messages.

NOTE: When creating a subscription, we don't need to explicitly call `consumer.connect()`. The connection will be automatically created when subscribing.

### Broadcasting Messages

Messages can be published to a stream from anywhere in the Rails app:

```ruby
ActionCable.server.broadcast("chat_general", { body: "Ahoy!" })
```

On the client, a callback is set receive messages and other lifecycle events:

```js
import { createConsumer } from "@rails/actioncable"
const consumer = createConsumer()

consumer.subscriptions.create(
  {
    channel: "ChatChannel",
    room: "general"
  },
  {
    connected() {
      console.log("Subscribed to ChatChannel")
    },

    disconnected() {
      console.log("Unsubscribed from ChatChannel")
    },

    received(data) {
      console.log(data.body)
    }
  }
)
```

Since WebSockets are bi-directional, clients can send data to the server over the same connection.

```js#11
import { createConsumer } from "@rails/actioncable"
const consumer = createConsumer()

const generalChat = consumer.subscriptions.create(
  {
    channel: "ChatChannel",
    room: "general"
  },
  {
    connected() {
      generalChat.send({ body: "Hi, I'm online!" })
    }
  }
)
```

This message is received in the `ChatChannel`.

```ruby
# app/channels/chat_channel.rb

class ChatChannel < ApplicationCable::Channel
  # ...

  def receive(data)
    # Handle received message
  end
end
```

A common use case is to rebroadcast data received from the client back to all the subscribers.

```ruby
# app/channels/chat_channel.rb

class ChatChannel < ApplicationCable::Channel
  # ...

  def receive(data)
    ActionCable.server.broadcast("chat_#{params[:room]}", data["body"])
  end
end
```

Note that this will also broadcast the message back to the initial sender. Depending on your use case, you may wish to add client-side logic to ignore the duplicate message.

Clients can also trigger actions in the channel.

```ruby
# app/channels/chat_channel.rb

class ChatChannel < ApplicationCable::Channel
  # ...

  def appear
    current_user.appear
  end
end
```

```js
import { createConsumer } from "@rails/actioncable"
const consumer = createConsumer()

const generalChat = consumer.subscriptions.create(
  {
    channel: "ChatChannel",
    room: "general"
  },
  {
    connected() {
      // Triggers the `appear` method in `ChatChannel`
      generalChat.perform("appear")
    }
  }
)
```

That covers the basics of creating a WebSocket connection and sending and receiving messages using Action Cable. In the next sections, we'll look more closely at the server components and client library.

Server Components
-----------------

Rails doesn't create Action Cable files when a new project is generated. Create them by generating a new channel:

```bash
$ bin/rails generation channel chat
```

This will create the `app/channels` directory and the following application files:

* `app/channels/application_cable/connection.rb` <br>
  The entrypoint for WebSocket connections.

* `app/channels/application_cable/channel.rb` <br>
  The base class for all channels.

* `app/channels/chat_channel.rb` <br>
  The channel class itself.

A test file and some JavaScript files will also be created. See the next section on the [JavaScript Client Library](#javascript-client-library) to learn more about the generated JavaScript files and the [Testing guide](testing.html#testing-action-cable) for guidance on writing tests for Action Cable channels.

### Connection

This is the default `Connection` file generated by Rails:

```ruby
# app/channels/application_cable/connection.rb

module ApplicationCable
  class Connection < ActionCable::Connection::Base
  end
end
```

An instance of this class represents every WebSocket connection. As demonstrated in the previous section, authenticate the connection before accepting it:

```ruby
# app/channels/application_cable/connection.rb

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      # Authenticate the connection, using `reject_unauthorized_connection` to
      # terminate it if authentication fails.
    end

    def disconnect
      # Any cleanup work needed when the cable connection is cut.
    end
  end
end
```

[`identified_by`](https://api.rubyonrails.org/classes/ActionCable/Connection/Identification/ClassMethods.html#method-i-identified_by) accepts multiple arguments if you would like to make multiple objects available to the connection. It serves as the Action Cable equivalent of [`ActiveSupport::CurrentAttributes`](https://api.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html). You must set at least one value declared by `identified_by` for the connection to succeed.

Cookies are not available in a WebSocket connection so any user-specific data for authorization or other uses must be stored in `identified_by` attributes.

Complete usage information is available in the [API docs](https://api.rubyonrails.org/classes/ActionCable/Connection/Base.html).

#### Connection Callbacks

Similar to controllers, callbacks are available in the `Connection` which are invoked when sending commands to the client, such as subscribing, unsubscribing, or performing an action:

* [`before_command`][]
* [`after_command`][]
* [`around_command`][]

[`after_command`]: https://api.rubyonrails.org/classes/ActionCable/Connection/Callbacks/ClassMethods.html#method-i-after_command
[`around_command`]: https://api.rubyonrails.org/classes/ActionCable/Connection/Callbacks/ClassMethods.html#method-i-around_command
[`before_command`]: https://api.rubyonrails.org/classes/ActionCable/Connection/Callbacks/ClassMethods.html#method-i-before_command

#### Handling Exceptions

Unhandled exceptions are caught and logged using Rails' logger. If you would like to globally intercept these exceptions, use [`rescue_from`][]. This can be used to report exceptions to an external bug tracking service.

```ruby
# app/channels/application_cable/connection.rb

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    rescue_from StandardError, with: :report_error

    private
      def report_error(e)
        SomeExternalBugtrackingService.notify(e)
      end
  end
end
```

[`rescue_from`]: https://api.rubyonrails.org/classes/ActiveSupport/Rescuable/ClassMethods.html#method-i-rescue_from

### Channels

A channel provides a structure to group behavior into logical units when communicating over WebSockets. It's analogous to a controller in a typical MVC setup.

When you generate your first channel, Rails also creates a `ApplicationCable::Channel` class which is the base class for all your channels.

```ruby
# app/channels/application_cable/channel.rb

module ApplicationCable
  class Channel < ActionCable::Channel::Base
  end
end
```

Here's an example of a channel which implements a chat room:

```ruby
# app/channels/chat_channel.rb

class ChatChannel < ApplicationCable::Channel

  # Called when a consumer subscribes to this channel
  def subscribed
    @room = Chat::Room[params[:room_id]]
    return reject unless current_user.can_access?(@room)

    current_user.appear
    stream_from @room
  end

  # Called when a consumer unsubscribes from this channel
  def unsubscribed
    current_user.disappear
  end

  # A remote action that can be triggered by the consumer
  def speak(data)
    @room.speak(data, user: current_user)
  end
end
```

Channel instances are long-lived. A channel object will be instantiated when the cable consumer becomes a subscriber, and lives until the consumer disconnects. This could be seconds, minutes, hours, or even days. This contrasts with controller instances which are dereferenced after every request.

Ensure that you allocate objects in channels cautiously to prevent its memory usage from ballooning. Object references in a channel live as long as the channel itself, which also means you need to ensure the data within an object remains fresh.

#### Subscriptions and Broadcasting

When a consumer triggers a subscription to a channel, a new channel instance is created and the `subscribed` method is called. Here, you can do any initial setup as well as wire up any streams you would like to send to the client.

```ruby
# app/channels/chat_channel.rb

class ChatChannel < ApplicationCable::Channel
  def subscribed
    @room = Chat::Room[params[:room_id]]
    return reject unless current_user.can_access?(@room)

    current_user.appear
    stream_for @room
  end

  # ...
end
```

Ensure you do an authorization check so users only access permitted resources. Use `reject` to disallow the subscription.

Set up a stream for subscribers using [`stream_from`][] or [`stream_for`][]. [`stream_from`][] only accepts a string as the stream name:

```ruby
# app/channels/chat_channel.rb
class ChatChannel < ApplicationCable::Channel
  def subscribed
    # ...

    room_name = params[:room]
    stream_from "room_#{room_name}"
  end

  # ...
end
```

[`stream_for`][] accepts one or more _broadcastables_, which are objects that respond to `to_gid_param` or `to_param`. Active Records objects respond to both these methods. `stream_for` will serialize them into a string.

```ruby#7
# app/channels/chat_channel.rb
class ChatChannel < ApplicationCable::Channel
  def subscribed
    # ...

    @room = Chat::Room[params[:room_id]]
    stream_for @room
  end

  # ...
end
```

The above snippet establishes a stream from `chat:Z2lkOi8vY2FibGUtdGVzdC9Sb29tLzE`, where `Z2lkOi8vY2FibGUtdGVzdC9Sb29tLzE` is the Base64 encoded [Global ID](https://github.com/rails/globalid) for the `@room` object.

Supply multiple arguments to namespace stream names:

```ruby
# Streams from `chat:room:Z2lkOi8vY2FibGUtdGVzdC9Sb29tLzE`.
stream_for :room, @room
```

[`stream_from`]: https://api.rubyonrails.org/classes/ActionCable/Channel/Streams.html#method-i-stream_from
[`stream_for`]: https://api.rubyonrails.org/classes/ActionCable/Channel/Streams.html#method-i-stream_for

You can broadcast messages to a stream from anywhere in your Rails app:

```ruby
ActionCable.server.broadcast("chat_general", { body: "Ahoy!" })
```

Broadcast to a stream derived from _broadcastables_ using [`broadcast_to`](https://api.rubyonrails.org/classes/ActionCable/Channel/Broadcasting/ClassMethods.html#method-i-broadcast_to):

```ruby
# Broadcasts to `chat:Z2lkOi8vY2FibGUtdGVzdC9Sb29tLzE`
ChatChannel.broadcast_to(@room, { body: "Ahoy!" })
```

`broadcast_to` is also available as an instance method:

```ruby
# app/channels/chat_channel.rb
class ChatChannel < ApplicationCable::Channel
  def subscribed
    @room = #...
  end

  def receive(data)
    broadcast_to @room, data
  end

  # ...
end
```

#### Processing Remote Actions

Unlike controllers, channel actions do not follow a RESTful convention. Instead, clients can perform remote-procedure calls on Action Cable channels. All public methods on the channel can be called by the client once they are subscribed.

```ruby
# app/channels/chat_channel.rb
class ChatChannel < ApplicationCable::Channel
  # ...

  # A remote action that can be triggered by the consumer
  # The `params` object is available as well as the data
  # sent by the client.
  def speak(data)
    room_id = params[:room_id]
    logger.debug "Data received for #{room_id}: #{data}"

    @room.speak(data, user: current_user)
  end
end
```

```js
import { createConsumer } from "@rails/actioncable"
const consumer = createConsumer()

const generalChat = consumer.subscriptions.create(
  {
    channel: "ChatChannel",
    room_id: "667ea191042b8303e920"
  },
  {
    connected() {
      // Triggers the `speak` method in `ChatChannel`
      generalChat.perform("speak", { message: "Hello!" })
    }
  }
)
```

#### Handling Exceptions

As with `ApplicationCable::Connection`, use [`rescue_from`][] in a channel to handle exceptions:

```ruby
# app/channels/chat_channel.rb
class ChatChannel < ApplicationCable::Channel
  rescue_from "MyError", with: :deliver_error_message

  private
    def deliver_error_message(error)
      # Handle error ...
    end
end
```

#### Channel Callbacks

A channel also provides callback hooks, similar to controllers and `Connection`, that are invoked during the lifecycle of a channel:

* [`before_subscribe`][]
* [`after_subscribe`][] (aliased as [`on_subscribe`][])
* [`before_unsubscribe`][]
* [`after_unsubscribe`][] (aliased as [`on_unsubscribe`][])

[`ActionCable::Channel::Callbacks`]: https://api.rubyonrails.org/classes/ActionCable/Channel/Callbacks.html
[`after_subscribe`]: https://api.rubyonrails.org/classes/ActionCable/Channel/Callbacks/ClassMethods.html#method-i-after_subscribe
[`after_unsubscribe`]: https://api.rubyonrails.org/classes/ActionCable/Channel/Callbacks/ClassMethods.html#method-i-after_unsubscribe
[`before_subscribe`]: https://api.rubyonrails.org/classes/ActionCable/Channel/Callbacks/ClassMethods.html#method-i-before_subscribe
[`before_unsubscribe`]: https://api.rubyonrails.org/classes/ActionCable/Channel/Callbacks/ClassMethods.html#method-i-before_unsubscribe
[`on_subscribe`]: https://api.rubyonrails.org/classes/ActionCable/Channel/Callbacks/ClassMethods.html#method-i-on_subscribe
[`on_unsubscribe`]: https://api.rubyonrails.org/classes/ActionCable/Channel/Callbacks/ClassMethods.html#method-i-on_unsubscribe

JavaScript Client Library
-------------------------

Rails provides a JavaScript client library for Action Cable which implements an abstraction layer over the native [`WebSocket`](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket) API. This makes it easy to subscribe to channels, trigger remote actions, and receive broadcasted messages using the Action Cable JSON messaging protocol.

When you generate a new channel, a JavaScript file is also created alongside the Ruby files. The following files are created when you generate your first channel (`bin/rails generate channel chat`):

- `app/javascript/channels/chat_channel.js` <br>
  Creates the channel subscription and handles callbacks.

- `app/javascript/channels/consumer.js` <br>
  Instantiates a consumer for all channels to share.

- `app/javascript/channels/index.js` <br>
  Imports all channel files.

An `import "channels"` directive will also be added to you `application.js` entrypoint. As such, a subscription to all your channels will be triggered when the user loads a page on your application. If you need fine-grained control to create specific subscriptions on specific pages, you'll need to modify the JavaScript file structure.

The techniques for this are out-of-scope for this guide as JavaScript setups can vary significantly across applications.

### Consumer

A _consumer_ is the Action Cable client that handles the WebSocket connection and channel subscriptions. The default `consumer.js` generated by Rails is shown below:

```js
// app/javascript/channels/consumer.js

import { createConsumer } from "@rails/actioncable"

export default createConsumer()
```

This will instantiate a consumer that will, by default, trigger a WebSocket connection at `/cable`. The connection will only be established when a subscription is triggered or `consumer.connect()` is called.

Supply a URL or a function to `createConsumer` to connect to a different URL or path.

```js
// Specify a different URL to connect to
createConsumer('wss://example.com/cable')

// Use a function to dynamically generate the URL
createConsumer(getWebSocketURL)

function getWebSocketURL() {
  const token = localStorage.getItem('auth-token')
  return `wss://example.com/cable?token=${token}`
}
```

You can globally set the url for the consumer by adding a `<meta>` tag named `action-cable-url` to your document's `<head>`. The [`action_cable_meta_tag`] helper method can be used for this.

See the [mount paths](#mount-path-and-url) section for details on mounting Action Cable on a different path, and the [deployment](#deployment) section to learn how to setup standalone Action Cable servers.

### Channels

The default JavaScript channel generated by Rails is:

```js
// app/javascript/channels/chat_channel.js

import consumer from "channels/consumer"

consumer.subscriptions.create("ChatChannel", {
  connected() {
    // Called when the subscription is ready for use on the server
  },

  disconnected() {
    // Called when the subscription has been terminated by the server
  },

  received(data) {
    // Called when there's incoming data on the websocket for this channel
  }
});
````

This sets up the subscription and defines placeholder methods for all available callbacks. You can define client-side parameters when creating a subscription which can then be used on the server:

```js
import consumer from "channels/consumer"

consumer.subscriptions.create({ channel: "ChatChannel", room: "General" })
```

Access the parameter on the server using the `params` object.

```ruby
# app/channels/chat_channel.rb

class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "chat_#{params[:room]}"
  end
end
```

A consumer can subscribe to the same channel multiple times. The below snippet demonstrates a subscription to multiple chat rooms using different `room` parameter values:

```js
import consumer from "channels/consumer"

consumer.subscriptions.create({ channel: "ChatChannel", room: "general" })
consumer.subscriptions.create({ channel: "ChatChannel", room: "watercooler" })
```

Each subscription will create a new channel instance on the server.

#### Triggering Remote Actions

After a consumer has subscribed to a channel, it can trigger remote actions in that channel.

```js
import consumer from "channels/consumer"

const generalRoom = consumer.subscriptions.create(
  {
    channel: "ChatChannel",
    room: "general"
  },
  {
    connected() {
      // Triggers the `speak` method in `ChatChannel`
      generalRoom.perform("speak", { message: "Hello!" })
    }
  }
)
```

Adapters
--------

Action Cable relies on external service for _pub/sub_. Rails interacts with the service via an adapter and this must be configured in `config/cable.yml`.

```yaml
# config/cable.yml

development:
  adapter: async

test:
  adapter: test

production:
  adapter: solid_cable
  connects_to:
    database:
      writing: cable
  polling_interval: 0.1.seconds
  message_retention: 1.day
```

The default service is [Solid Cable](https://github.com/rails/solid_cable/). Rails also provides adapters for Redis and PostgreSQL, as well as an _async_ adapter for development and testing.

### Solid Cable

Solid Cable is a database-backed Action Cable adapter that keeps messages in a table and continuously polls for updates. It uses Active Record under the hood and has been tested with MySQL, SQLite, and PostgreSQL. It's installed by default in all new Rails apps.

On existing applications, run `bin/rails solid_cable:install` to set the adapter in `config/cable.yml` and create the database schema for Solid Cable.

Configuring Solid Cable to use its own database is recommended, but you can also use a single database for both application data and Action Cable.

See the [Solid Cable Readme](https://github.com/rails/solid_cable?tab=readme-ov-file) for complete usage and installation instructions.

### Redis

Action Cable's Redis adapter integrates with [Redis' pub/sub messaging system](https://redis.io/docs/latest/develop/pubsub/).

NOTE: Redis pub/sub is independent of its key-value database. They operate in the same process and share networking, but pub/sub operations do not affect the key-value database in any way.

Configure the Redis adapter by defining the URL to the Redis server as shown below:

```yaml
# config/cable.yml

production:
  adapter: redis
  url: redis://redis.infra.local:6379/1
  channel_prefix: my_app_production
```

You can optionally define a `channel_prefix` to avoid channel name collisions when using the same Redis server for multiple applications.

The Redis adapter supports SSL/TLS connections:

```yaml#5,7,8
# config/cable.yml

production:
  adapter: redis
  url: rediss://redis.infra.local:6379/1
  channel_prefix: my_app_production
  ssl_params:
    ca_file: "/path/to/ca.crt"
```

The `ssl_params` are passed directly to [`OpenSSL::SSL::SSLContext#set_params`](https://docs.ruby-lang.org/en/master/OpenSSL/SSL/SSLContext.html#method-i-set_params) and can be any valid attribute of the SSL context.

### PostgreSQL

The PostgreSQL adapter uses the [`NOTIFY`](https://www.postgresql.org/docs/current/sql-notify.html) and [`LISTEN`](https://www.postgresql.org/docs/18/sql-listen.html) commands to implement pub/sub using the PostgreSQL databse. It uses Active Record's connection pool, and thus the application's `config/database.yml` database configuration.

PostgreSQL limits `NOTIFY` payloads to 8000 bytes. This is worth bearing in mind when using this adapter as large payloads cannot be processed.

```yaml
# config/cable.yml

production:
  adapter: postgresql
```

### Async

The `async` adapter runs within the Rails process. It uses a Ruby hash to track subscribers and broadcast messages. It's intended for development and testing only. It is not designed for production use.

This adapter is limited to a single Rails process. You cannot start a Rails console (`bin/rails console`) to broadcast messages to a Rails server running in a different terminal window.

Use a web console to trigger Action Cable broadcasts when using the `async` adapter. Add `console` to any controller action or any ERB template to add a web console to the page.

```yaml
# config/cable.yml

development:
  adapter: async
```

Configuration
-------------

In this section, we'll discuss the configuration options offered by Action Cable.

### Allowed Request Origins

Action Cable, by default, will only accept connections requested from the same origin as where your app is hosted. This behaviour can be controlled using `allow_same_origin_as_host`:

```ruby
# config/environments/production.rb

# Accept connection requests from the same origin as the app.
# Defaults to `true`.
config.action_cable.allow_same_origin_as_host = true
```

Additionally, Action Cable can be configured to accept requests from specific origins. The allowlist can contain strings or regular expressions which will be matched against the HTTP request's `Origin` header. This is useful if you're running [standalone Action Cable servers](#standalone-action-cable-server).

```ruby
# config/environments/production.rb

config.action_cable.allowed_request_origins = ["https://my-app.com", %r{https://*.my-app.com}]
```

Allow requests from any origin by disabling request forgery protection:

```ruby
# config/environments/production.rb

config.action_cable.disable_request_forgery_protection = true
```

### Mount Path and URL

Action Cable is _mounted_ at `/cable` by default. This means the JavaScript `consumer` makes a request to `/cable` to initiate the WebSocket handshake. You can change the mount path in your configuration:

```ruby
# config/initializers/action_cable.rb

Rails.app.config.action_cable.mount_path = "/websocket"
```

When running a [standalone Action Cable server](#standalone-action-cable-server), configure the URL to the server using:

```ruby
# config/environments/production.rb

config.action_cable.mount_path = nil
config.action_cable.url = "wss://cable.my-rails-app.com"
```

Set the Action Cable URL for the JavaSript consumer by adding [`action_cable_meta_tag`][] to your application's `<head>`:

```erb
<%# app/views/layouts/application.html.erb %>

<head>
  <%= action_cable_meta_tag %>
</head>
```

This will write the Action Cable URL in a `<meta>` tag which will be automatically read by Action Cable's JavaScript client to create a consumer pointing to the custom URL.

[`action_cable_meta_tag`]: https://api.rubyonrails.org/classes/ActionCable/Helpers/ActionCableHelper.html#method-i-action_cable_meta_tag

### Worker Pool

Action Cable maintains its own thread pool which is distinct from your application server's thread pool. It's exclusively used to process WebSocket messages for Action Cable without affecting HTTP requests. The size of the thread pool can be configured using:

```ruby
# config/initializers/action_cable.rb

Rails.app.config.action_cable.worker_pool_size = 4
```

The default value is `4`. Each worker requires it's own database connection. A worker pool size of `4` requires 4 database connections. Ensure the `pool` attribute in your `config/database.yml` is high enough to allow both Action Cable's threads and your application server's threads to hold database connections.

### Client-side Logging

Action Cable's JavaScript library contains debugging log messages which are written to the console for events such as the creation of a WebSocket connection, or the confirmation of a channel subcription.

The logger is disabled by default, but you can enable it using:

```js
import * as ActionCable from '@rails/actioncable'

ActionCable.logger.enabled = true
```

You can use this logger in your own client-side channels as well.

### Log Tags

On the server, you can add tags to Action Cable logs to make them easier to filter. Define as many tags as you'd like in an array, and use a lamda to dynamically generate a value based on the initial handshake HTTP request.

```ruby
# config/initializers/action_cable.rb

Rails.app.config.action_cable.log_tags = [
  :action_cable,
  -> request { request.uuid }
]
```

Deployment
----------

Action Cable can be run within your main Rails server's process. It will be mounted at `/cable` by default and can accept and process WebSocket connections alongside HTTP requests. No additional configuration is required for this setup.

For apps handling a higher level of traffic, you may wish to run standalone Action Cable Servers.

### Standalone Action Cable Server

A standalone Action Cable server boots your Rails app as normal, but only processes Action Cable connections and no HTTP requests.

The below Rack configuration demonstrates how to start an Action Cable server:

```ruby
# cable.ru

require_relative "../config/environment"
Rails.application.eager_load!

run ActionCable.server
```

Start the server using:

```bash
$ bundle exec puma -p 28080 cable.ru
```

Your Action Cable server will be started on port 28080.

Ensure you [configure Rails to point to the Action Cable server's URL](#mount-path-and-url).

## Testing

Consult the [testing guide](testing.html#testing-action-cable) for details on testing Action Cable components.
