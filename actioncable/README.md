# Action Cable – Integrated WebSockets for Rails

Action Cable seamlessly integrates WebSockets with the rest of your Rails application.
It allows for real-time features to be written in Ruby in the same style
and form as the rest of your Rails application, while still being performant
and scalable. It's a full-stack offering that provides both a client-side
JavaScript framework and a server-side Ruby framework. You have access to your full
domain model written with Active Record or your ORM of choice.

## Terminology

A single Action Cable server can handle multiple connection instances. It has one
connection instance per WebSocket connection. A single user may have multiple
WebSockets open to your application if they use multiple browser tabs or devices.
The client of a WebSocket connection is called the consumer.

Each consumer can in turn subscribe to multiple cable channels. Each channel encapsulates
a logical unit of work, similar to what a controller does in a regular MVC setup. For example,
you could have a `ChatChannel` and an `AppearancesChannel`, and a consumer could be subscribed to either
or to both of these channels. At the very least, a consumer should be subscribed to one channel.

When the consumer is subscribed to a channel, they act as a subscriber. The connection between
the subscriber and the channel is, surprise-surprise, called a subscription. A consumer
can act as a subscriber to a given channel any number of times. For example, a consumer
could subscribe to multiple chat rooms at the same time. (And remember that a physical user may
have multiple consumers, one per tab/device open to your connection).

Each channel can then again be streaming zero or more broadcastings. A broadcasting is a
pubsub link where anything transmitted by the broadcaster is sent directly to the channel
subscribers who are streaming that named broadcasting.

As you can see, this is a fairly deep architectural stack. There's a lot of new terminology
to identify the new pieces, and on top of that, you're dealing with both client and server side
reflections of each unit.

## Examples

### A full-stack example

The first thing you must do is define your `ApplicationCable::Connection` class in Ruby. This
is the place where you authorize the incoming connection, and proceed to establish it,
if all is well. Here's the simplest example starting with the server-side connection class:

```ruby
# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    protected
      def find_verified_user
        if current_user = User.find_by(id: cookies.signed[:user_id])
          current_user
        else
          reject_unauthorized_connection
        end
      end
  end
end
```
Here `identified_by` is a connection identifier that can be used to find the specific connection again or later.
Note that anything marked as an identifier will automatically create a delegate by the same name on any channel instances created off the connection.

This relies on the fact that you will already have handled authentication of the user, and
that a successful authentication sets a signed cookie with the `user_id`. This cookie is then
automatically sent to the connection instance when a new connection is attempted, and you
use that to set the `current_user`. By identifying the connection by this same current_user,
you're also ensuring that you can later retrieve all open connections by a given user (and
potentially disconnect them all if the user is deleted or deauthorized).

Next, you should define your `ApplicationCable::Channel` class in Ruby. This is the place where you put
shared logic between your channels.

```ruby
# app/channels/application_cable/channel.rb
module ApplicationCable
  class Channel < ActionCable::Channel::Base
  end
end
```

The client-side needs to setup a consumer instance of this connection. That's done like so:

```js
// app/assets/javascripts/cable.js
//= require action_cable
//= require_self
//= require_tree ./channels

(function() {
  this.App || (this.App = {});

  App.cable = ActionCable.createConsumer("ws://cable.example.com");
}).call(this);
```

The `ws://cable.example.com` address must point to your Action Cable server(s), and it
must share a cookie namespace with the rest of the application (which may live under http://example.com).
This ensures that the signed cookie will be correctly sent.

That's all you need to establish the connection! But of course, this isn't very useful in
itself. This just gives you the plumbing. To make stuff happen, you need content. That content
is defined by declaring channels on the server and allowing the consumer to subscribe to them.


### Channel example 1: User appearances

Here's a simple example of a channel that tracks whether a user is online or not, and also what page they are currently on.
(This is useful for creating presence features like showing a green dot next to a user's name if they're online).

First you declare the server-side channel:

```ruby
# app/channels/appearance_channel.rb
class AppearanceChannel < ApplicationCable::Channel
  def subscribed
    current_user.appear
  end

  def unsubscribed
    current_user.disappear
  end

  def appear(data)
    current_user.appear on: data['appearing_on']
  end

  def away
    current_user.away
  end
end
```

The `#subscribed` callback is invoked when, as we'll show below, a client-side subscription is initiated. In this case,
we take that opportunity to say "the current user has indeed appeared". That appear/disappear API could be backed by
Redis or a database or whatever else. Here's what the client-side of that looks like:

```coffeescript
# app/assets/javascripts/cable/subscriptions/appearance.coffee
App.cable.subscriptions.create "AppearanceChannel",
  # Called when the subscription is ready for use on the server
  connected: ->
    @install()
    @appear()

  # Called when the WebSocket connection is closed
  disconnected: ->
    @uninstall()

  # Called when the subscription is rejected by the server
  rejected: ->
    @uninstall()

  appear: ->
    # Calls `AppearanceChannel#appear(data)` on the server
    @perform("appear", appearing_on: $("main").data("appearing-on"))

  away: ->
    # Calls `AppearanceChannel#away` on the server
    @perform("away")


  buttonSelector = "[data-behavior~=appear_away]"

  install: ->
    $(document).on "turbolinks:load.appearance", =>
      @appear()

    $(document).on "click.appearance", buttonSelector, =>
      @away()
      false

    $(buttonSelector).show()

  uninstall: ->
    $(document).off(".appearance")
    $(buttonSelector).hide()
```

Simply calling `App.cable.subscriptions.create` will setup the subscription, which will call `AppearanceChannel#subscribed`,
which in turn is linked to the original `App.cable` -> `ApplicationCable::Connection` instances.

Next, we link the client-side `appear` method to `AppearanceChannel#appear(data)`. This is possible because the server-side
channel instance will automatically expose the public methods declared on the class (minus the callbacks), so that these
can be reached as remote procedure calls via a subscription's `perform` method.

### Channel example 2: Receiving new web notifications

The appearance example was all about exposing server functionality to client-side invocation over the WebSocket connection.
But the great thing about WebSockets is that it's a two-way street. So now let's show an example where the server invokes
an action on the client.

This is a web notification channel that allows you to trigger client-side web notifications when you broadcast to the right
streams:

```ruby
# app/channels/web_notifications_channel.rb
class WebNotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "web_notifications_#{current_user.id}"
  end
end
```

```coffeescript
# Client-side, which assumes you've already requested the right to send web notifications
App.cable.subscriptions.create "WebNotificationsChannel",
  received: (data) ->
    new Notification data["title"], body: data["body"]
```

```ruby
# Somewhere in your app this is called, perhaps from a NewCommentJob
ActionCable.server.broadcast \
  "web_notifications_#{current_user.id}", { title: 'New things!', body: 'All the news that is fit to print' }
```

The `ActionCable.server.broadcast` call places a message in the Action Cable pubsub queue under a separate broadcasting name for each user. For a user with an ID of 1, the broadcasting name would be `web_notifications_1`.
The channel has been instructed to stream everything that arrives at `web_notifications_1` directly to the client by invoking the
`#received(data)` callback. The data is the hash sent as the second parameter to the server-side broadcast call, JSON encoded for the trip
across the wire, and unpacked for the data argument arriving to `#received`.


### Passing Parameters to Channel

You can pass parameters from the client side to the server side when creating a subscription. For example:

```ruby
# app/channels/chat_channel.rb
class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "chat_#{params[:room]}"
  end
end
```

If you pass an object as the first argument to `subscriptions.create`, that object will become the params hash in your cable channel. The keyword `channel` is required.

```coffeescript
# Client-side, which assumes you've already requested the right to send web notifications
App.cable.subscriptions.create { channel: "ChatChannel", room: "Best Room" },
  received: (data) ->
    @appendLine(data)

  appendLine: (data) ->
    html = @createLine(data)
    $("[data-chat-room='Best Room']").append(html)

  createLine: (data) ->
    """
    <article class="chat-line">
      <span class="speaker">#{data["sent_by"]}</span>
      <span class="body">#{data["body"]}</span>
    </article>
    """
```

```ruby
# Somewhere in your app this is called, perhaps from a NewCommentJob
ActionCable.server.broadcast \
  "chat_#{room}", { sent_by: 'Paul', body: 'This is a cool chat app.' }
```


### Rebroadcasting message

A common use case is to rebroadcast a message sent by one client to any other connected clients.

```ruby
# app/channels/chat_channel.rb
class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "chat_#{params[:room]}"
  end

  def receive(data)
    ActionCable.server.broadcast "chat_#{params[:room]}", data
  end
end
```

```coffeescript
# Client-side, which assumes you've already requested the right to send web notifications
App.chatChannel = App.cable.subscriptions.create { channel: "ChatChannel", room: "Best Room" },
  received: (data) ->
    # data => { sent_by: "Paul", body: "This is a cool chat app." }

App.chatChannel.send({ sent_by: "Paul", body: "This is a cool chat app." })
```

The rebroadcast will be received by all connected clients, _including_ the client that sent the message. Note that params are the same as they were when you subscribed to the channel.


### More complete examples

See the [rails/actioncable-examples](https://github.com/rails/actioncable-examples) repository for a full example of how to setup Action Cable in a Rails app, and how to add channels.

## Configuration

Action Cable has three required configurations: a subscription adapter, allowed request origins, and the cable server URL (which can optionally be set on the client side).

### Redis

By default, `ActionCable::Server::Base` will look for a configuration file in `Rails.root.join('config/cable.yml')`.
This file must specify an adapter and a URL for each Rails environment. It may use the following format:

```yaml
production: &production
  adapter: redis
  url: redis://10.10.3.153:6381
development: &development
  adapter: redis
  url: redis://localhost:6379
test: *development
```

You can also change the location of the Action Cable config file in a Rails initializer with something like:

```ruby
Rails.application.paths.add "config/cable", with: "somewhere/else/cable.yml"
```

### Allowed Request Origins

Action Cable will only accept requests from specific origins.

By default, only an origin matching the cable server itself will be permitted.
Additional origins can be specified using strings or regular expressions, provided in an array.

```ruby
Rails.application.config.action_cable.allowed_request_origins = ['http://rubyonrails.com', /http:\/\/ruby.*/]
```

When running in the development environment, this defaults to "http://localhost:3000".

To disable protection and allow requests from any origin:

```ruby
Rails.application.config.action_cable.disable_request_forgery_protection = true
```

To disable automatic access for same-origin requests, and strictly allow
only the configured origins:

```ruby
Rails.application.config.action_cable.allow_same_origin_as_host = false
```

### Consumer Configuration

Once you have decided how to run your cable server (see below), you must provide the server URL (or path) to your client-side setup.
There are two ways you can do this.

The first is to simply pass it in when creating your consumer. For a standalone server,
this would be something like: `App.cable = ActionCable.createConsumer("ws://example.com:28080")`, and for an in-app server,
something like: `App.cable = ActionCable.createConsumer("/cable")`.

The second option is to pass the server URL through the `action_cable_meta_tag` in your layout.
This uses a URL or path typically set via `config.action_cable.url` in the environment configuration files, or defaults to "/cable".

This method is especially useful if your WebSocket URL might change between environments. If you host your production server via https, you will need to use the wss scheme
for your Action Cable server, but development might remain http and use the ws scheme. You might use localhost in development and your
domain in production.

In any case, to vary the WebSocket URL between environments, add the following configuration to each environment:

```ruby
config.action_cable.url = "ws://example.com:28080"
```

Then add the following line to your layout before your JavaScript tag:

```erb
<%= action_cable_meta_tag %>
```

And finally, create your consumer like so:

```coffeescript
App.cable = ActionCable.createConsumer()
```

### Other Configurations

The other common option to configure is the log tags applied to the per-connection logger. Here's an example that uses the user account id if available, else "no-account" while tagging:

```ruby
config.action_cable.log_tags = [
  -> request { request.env['user_account_id'] || "no-account" },
  :action_cable,
  -> request { request.uuid }
]
```

For a full list of all configuration options, see the `ActionCable::Server::Configuration` class.

Also note that your server must provide at least the same number of database connections as you have workers. The default worker pool is set to 4, so that means you have to make at least that available. You can change that in `config/database.yml` through the `pool` attribute.


## Running the cable server

### Standalone
The cable server(s) is separated from your normal application server. It's still a Rack application, but it is its own Rack
application. The recommended basic setup is as follows:

```ruby
# cable/config.ru
require ::File.expand_path('../../config/environment', __FILE__)
Rails.application.eager_load!

run ActionCable.server
```

Then you start the server using a binstub in bin/cable ala:
```sh
#!/bin/bash
bundle exec puma -p 28080 cable/config.ru
```

The above will start a cable server on port 28080.

### In app

If you are using a server that supports the [Rack socket hijacking API](http://www.rubydoc.info/github/rack/rack/file/SPEC#Hijacking), Action Cable can run alongside your Rails application. For example, to listen for WebSocket requests on `/websocket`, specify that path to `config.action_cable.mount_path`:

```ruby
# config/application.rb
class Application < Rails::Application
  config.action_cable.mount_path = '/websocket'
end
```

For every instance of your server you create and for every worker your server spawns, you will also have a new instance of Action Cable, but the use of Redis keeps messages synced across connections.

### Notes

Beware that currently, the cable server will _not_ auto-reload any changes in the framework. As we've discussed, long-running cable connections mean long-running objects. We don't yet have a way of reloading the classes of those objects in a safe manner. So when you change your channels, or the model your channels use, you must restart the cable server.

We'll get all this abstracted properly when the framework is integrated into Rails.

The WebSocket server doesn't have access to the session, but it has access to the cookies. This can be used when you need to handle authentication. You can see one way of doing that with Devise in this [article](http://www.rubytutorial.io/actioncable-devise-authentication).

## Dependencies

Action Cable provides a subscription adapter interface to process its pubsub internals. By default, asynchronous, inline, PostgreSQL, evented Redis, and non-evented Redis adapters are included. The default adapter in new Rails applications is the asynchronous (`async`) adapter. To create your own adapter, you can look at `ActionCable::SubscriptionAdapter::Base` for all methods that must be implemented, and any of the adapters included within Action Cable as example implementations.

The Ruby side of things is built on top of [websocket-driver](https://github.com/faye/websocket-driver-ruby), [nio4r](https://github.com/celluloid/nio4r), and [concurrent-ruby](https://github.com/ruby-concurrency/concurrent-ruby).


## Deployment

Action Cable is powered by a combination of WebSockets and threads. All of the
connection management is handled internally by utilizing Ruby’s native thread
support, which means you can use all your regular Rails models with no problems
as long as you haven’t committed any thread-safety sins.

The Action Cable server does _not_ need to be a multi-threaded application server.
This is because Action Cable uses the [Rack socket hijacking API](http://www.rubydoc.info/github/rack/rack/file/SPEC#Hijacking)
to take over control of connections from the application server. Action Cable
then manages connections internally, in a multithreaded manner, regardless of
whether the application server is multi-threaded or not. So Action Cable works
with all the popular application servers -- Unicorn, Puma and Passenger.

Action Cable does not work with WEBrick, because WEBrick does not support the
Rack socket hijacking API.

## Frontend assets

Action Cable's frontend assets are distributed through two channels: the
official gem and npm package, both titled `actioncable`.

### Gem usage

Through the `actioncable` gem, Action Cable's frontend assets are
available through the Rails Asset Pipeline. Create a `cable.js` or
`cable.coffee` file (this is automatically done for you with Rails
generators), and then simply require the assets:

In JavaScript...

```javascript
//= require action_cable
```

... and in CoffeeScript:

```coffeescript
#= require action_cable
```

### npm usage

In addition to being available through the `actioncable` gem, Action Cable's
frontend JS assets are also bundled in an officially supported npm module,
intended for usage in standalone frontend applications that communicate with a
Rails application. A common use case for this could be if you have a decoupled
frontend application written in React, Ember.js, etc. and want to add real-time
WebSocket functionality.

### Installation

```
npm install actioncable --save
```

### Usage

The `ActionCable` constant is available as a `require`-able module, so
you only have to require the package to gain access to the API that is
provided.

In JavaScript...

```javascript
ActionCable = require('actioncable')

var cable = ActionCable.createConsumer('wss://RAILS-API-PATH.com/cable')

cable.subscriptions.create('AppearanceChannel', {
  // normal channel code goes here...
});
```

and in CoffeeScript...

```coffeescript
ActionCable = require('actioncable')

cable = ActionCable.createConsumer('wss://RAILS-API-PATH.com/cable')

cable.subscriptions.create 'AppearanceChannel',
    # normal channel code goes here...
```

## License

Action Cable is released under the MIT license:

* http://www.opensource.org/licenses/MIT


## Support

API documentation is at:

* http://api.rubyonrails.org

Bug reports can be filed for the Ruby on Rails project here:

* https://github.com/rails/rails/issues

Feature requests should be discussed on the rails-core mailing list here:

* https://groups.google.com/forum/?fromgroups#!forum/rubyonrails-core
