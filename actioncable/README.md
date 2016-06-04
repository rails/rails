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
    $(document).on "page:change.appearance", =>
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
