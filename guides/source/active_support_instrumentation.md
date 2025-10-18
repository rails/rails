**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Active Support Instrumentation
==============================

[Active Support](https://api.rubyonrails.org/classes/ActiveSupport.html) is a
core component of Ruby on Rails, offering a wide range of Ruby language
extensions and utility classes.

One of its key features is the Instrumentation API, which is described in
further detail in this guide. You will learn:

* About Instrumentation
* How to instrument your own events.
* How to subscribe to events.
* The instrumentation hooks available inside Rails.

--------------------------------------------------------------------------------

Introduction to Instrumentation
-------------------------------

The Instrumentation API provides a way to instrument code and subscribe to
events that occur in your application. Instrumentation means wrapping a block of
code so that, when it runs, an event is emitted with a name and optional
payload. Any subscribers listening for that event will then be notified and can
react, for example, they can log information, benchmark, or perform some other
action. This makes it possible to observe behavior within the Rails framework,
in your own code, or even in standalone Ruby scripts. There are a few parts that
are vital to understanding the Instrumentation API: hooks, events, and
subscribers.

### Hooks

Hooks help us observe behavior within the Rails framework; these hooks are
predefined points in the framework where an event is emitted. By subscribing to
an event from a hook, you can run your own code whenever that event occurs.

For example, there is [a hook](#sql-active-record) that is called every time
Active Record executes a SQL query on a database. This hook can be subscribed
to, and used to track the number of queries during a certain action. There's
[another hook](#process-action-action-controller) which is called when
processing an action of a controller. This hook can be subscribed to, and used
to track how long a specific action has taken. You can read more about hooks in
the [Rails framework hooks section](#rails-framework-hooks) later in this guide.

### Events

An event is generated when a hook is triggered or when you've [instrumented your
own event](#instrumenting-custom-events). It is a record of something that has
happened. You can use events to track changes in your application.

For example, when the
[`process_action.action_controller`](#process-action-action-controller) hook is
triggered, then an event is generated. This event has a name and optional data.
The name is `process_action.action_controller` and the data includes the
controller name, action name, and other information about the request.

You can read more about creating your own events and subscribing to events in
the  [Instrumenting Custom Events section](#instrumenting-custom-events) and
[Subscribing to an Event section](#subscribing-to-an-event) respectively.

### Subscribers

A subscriber is the object that is used to subscribe to events. It is used to
listen to events and perform some action when an event is emitted.

For example, if you want to subscribe to the `process_action.action_controller`
event and benchmark it, then you can create a subscriber that listens to that
event. The subscriber will then be able to perform other actions when the event
is emitted, such as logging the duration of the action.

A single event can have multiple subscribers. You can read more about
subscribers in the [Subscribing to an Event section](#subscribing-to-an-event).

Instrumenting Custom Events
---------------------------

You can instrument your own events, by calling
[`ActiveSupport::Notifications.instrument`](https://api.rubyonrails.org/classes/ActiveSupport/Notifications.html#method-c-instrument)
with the `name` of your custom event, a `payload` which is a hash containing
information about the event, and an optional block.

```ruby
ActiveSupport::Notifications.instrument "my.custom.event", this: "payload" do
  # do your custom stuff here
end
```

TIP: You should follow Rails conventions when defining your own events. The
format is: `event.library`. For a blogging application, pick an emitter name
like posts (or blog if that’s your domain), then instrument names like
`publish.posts`.

Example:

```ruby
ActiveSupport::Notifications.instrument "publish.posts", {title: "My Post", author: "John Doe" } do
  # Publish the post here
end
```

When given a block (like the example above), Active Support measures the block's
execution, i.e. the start time, end time, and duration, and then emits the event
with that data plus your payload. The event is emitted after the block
completes.

You can also instrument an event without a block:

```ruby
ActiveSupport::Notifications.instrument "my.custom.event", this: "data"
```

In this case, no code is measured. The event is emitted immediately with the
payload you provide to notify subscribers that something happened, without
executing or measuring a block of code.

Once you've emitted an event, you can subscribe to it as described at the end of
the [Subscribing to an Event section](#subscribing-to-an-event).

Subscribing to an Event
-----------------------

As mentioned [in the introduction](#introduction-to-instrumentation), an event
is generated when a hook is triggered [within the Rails
framework](#rails-framework-hooks) or when [you've instrumented your own
event](#instrumenting-custom-events). You can subscribe to these events by using
the
[`ActiveSupport::Notifications.subscribe`](https://api.rubyonrails.org/classes/ActiveSupport/Notifications.html#method-c-subscribe)
method.

To do this, call the `ActiveSupport::Notifications.subscribe` method with the
name of the event you want to subscribe to, and a block. This block will be
called when the event is emitted.

In the example below, the block takes a _single_ argument `event`, where `event`
is an instance of
[`ActiveSupport::Notifications::Event`](https://api.rubyonrails.org/classes/ActiveSupport/Notifications/Event.html).

```ruby
ActiveSupport::Notifications.subscribe "process_action.action_controller" do |event|
  Rails.logger.info "#{event.name}" # process_action.action_controller
  Rails.logger.info "#{event.duration}" # 10 (in milliseconds)
  Rails.logger.info "#{event.allocations}" # 1826
  Rails.logger.info "#{event.payload}" # {:extra=>information}
end
```

If you don't need all the data recorded by an `Event` object, you can specify a
block with the following arguments instead:

```ruby
ActiveSupport::Notifications.subscribe "process_action.action_controller" do |name, started, finished, unique_id, payload|
  Rails.logger.info "name: #{name}" # process_action.action_controller
  Rails.logger.info "started: #{started}" #   2025-10-13 10:00:40 -0700
  Rails.logger.info "finished: #{finished}"   # 2025-10-13 10:00:50 -0700
  Rails.logger.info "unique_id: #{unique_id}" # a3f2e9...
  Rails.logger.info "payload: #{payload}" # {:extra=>information}
end
```

If you are concerned about the accuracy of `started` and `finished` to compute a
precise elapsed time, then use
[`ActiveSupport::Notifications.monotonic_subscribe`](https://api.rubyonrails.org/classes/ActiveSupport/Notifications.html#method-c-monotonic_subscribe).
The given block will receive the same arguments as above, but the `started` and
`finished` values will have an accurate monotonic time instead of wall-clock
time.

```ruby
ActiveSupport::Notifications.monotonic_subscribe "process_action.action_controller" do |name, started, finished, unique_id, payload|
  duration = finished - started # 1560979.429234 - 1560978.425334
  Rails.logger.info "#{name} Received! (duration: #{duration})" # process_action.action_controller Received! (duration: 1.0039)
end
```

### Subscribing to a Custom Event

In the case of subscribing to a custom event, you can use the methods as
described above, but with the `name` of your custom event instead. For example:

```ruby
ActiveSupport::Notifications.subscribe "my.custom.event" do |event|
  Rails.logger.info "#{event.name}" # my.custom.event
end
```

### Subscribing to Multiple Events

You may also subscribe to events matching a regular expression. This enables you
to subscribe to multiple events at once. Here's how to subscribe to everything
from `ActionController`:

```ruby
ActiveSupport::Notifications.subscribe(/action_controller/) do |**args|
  Rails.logger.info "#{args}"
end
```

In your Rails log, you'll see one line for each ActionController event. Example:

```bash
INFO -- : {:name=>"start_processing.action_controller", :id=>"a3f2e9...", :payload=>{:controller=>"PostsController", :action=>"index", :params=>{"controller"=>"posts", "action"=>"index"}, :format=>:html, :method=>"GET", :path=>"/posts"}}
INFO -- : {:name=>"process_action.action_controller", :id=>"a3f2e9...", :payload=>{:controller=>"PostsController", :action=>"index", :status=>200, :view_runtime=>12.34, :db_runtime=>3.21}}
```

### Subscribing to a Single Event using Multiple Subscribers

You can subscribe to a single event using multiple subscribers. This is useful
if you want to subscribe to an event from multiple sources.

For example, you may want to subscribe to a `publish.posts` event from multiple
sources to kick off a background job to send an email to the post author, and to
also log the event.


Rails Framework Hooks
---------------------

Within the Ruby on Rails framework, there are a number of hooks provided for
common events.

Each event below lists the event name you can subscribe to, explains how the
event is triggered, and the corresponding example `event.payload` from the
subscribed event.

To subscribe to a specific event, use
[`ActiveSupport::Notifications.subscribe`](https://api.rubyonrails.org/classes/ActiveSupport/Notifications.html#method-c-subscribe).
For example:

```ruby
ActiveSupport::Notifications.subscribe "process_action.action_controller" do |event|
  # Do something with the event
  Rails.logger.info event.name         # "process_action.action_controller"
  Rails.logger.info event.duration     # 10 (in milliseconds)
  Rails.logger.info event.allocations  # 1826
  Rails.logger.info event.payload
  #   {
  #   controller: "PostsController",
  #   action: "index",
  #   params: {"action" => "index", "controller" => "posts"},
  #   headers: #<ActionDispatch::Http::Headers:0x...>,
  #   format: :html,
  #   method: "GET",
  #   path: "/posts",
  #   request: #<ActionDispatch::Request:0x...>,
  #   response: #<ActionDispatch::Response:0x...>,
  #   status: 200,
  #   view_runtime: 46.848,
  #   db_runtime: 0.157
  # }
end
```

NOTE: `event.payload` is a hash with the payload of the event. Below we describe
the keys, and examples values that you can expect to see in the payload.

Read more about subscribing to the event in [Subscribing to an
Event](#subscribing-to-an-event).

### Action Cable

#### `perform_action.action_cable`

The event is emitted when a channel action is invoked.

For example:

```ruby
# Client sends: { "action":"speak", "message":"Hi" }
class ChatChannel < ApplicationCable::Channel
  def speak(data) = Message.create!(text: data["message"])
end
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key      | Description               | Example               |
| ---------------- | ------------------------- | --------------------- |
| `:channel_class` | Name of the channel class | `"ChatChannel"`       |
| `:action`        | The action                | `"speak"`             |
| `:data`          | A hash of data            | `{ "message"=>"Hi" }` |

#### `transmit.action_cable`

The event is emitted when a message is transmitted from a channel.

For example:

```ruby
class ChatChannel < ApplicationCable::Channel
  def subscribed
    transmit(ok: true)
  end
end
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key      | Description               | Example          |
| ---------------- | ------------------------- | ---------------- |
| `:channel_class` | Name of the channel class | `"ChatChannel"`  |
| `:data`          | A hash of data            | `{ "ok"=>true }` |
| `:via`           | Via                       | `"websocket"`    |

#### `transmit_subscription_confirmation.action_cable`

The event is emitted when a subscription confirmation is sent to a client.

For example:

```ruby
# Successful subscription auto-confirms -> event fires
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key      | Description               | Example         |
| ---------------- | ------------------------- | --------------- |
| `:channel_class` | Name of the channel class | `"ChatChannel"` |

#### `transmit_subscription_rejection.action_cable`

The event is emitted when a subscription rejection is sent to a client.

For example:

```ruby
def subscribed
  reject
end
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key      | Description               | Example         |
| ---------------- | ------------------------- | --------------- |
| `:channel_class` | Name of the channel class | `"ChatChannel"` |

#### `broadcast.action_cable`

The event is emitted when a broadcast is published to a stream.

For example:

```ruby
ActionCable.server.broadcast("chat_room_1", text: "Hello")
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key     | Description        | Example                 |
| --------------- | ------------------ | ----------------------- |
| `:broadcasting` | Named broadcasting | `"chat_room_1"`         |
| `:message`      | A hash of message  | `{ "text"=>"Hello" }`   |
| `:coder`        | The coder          | `"ActiveSupport::JSON"` |

### Action Controller

#### `start_processing.action_controller`

The event is emitted when a controller begins handling a request, before the
action is invoked.

For example:

```ruby
class PostsController < ApplicationController
  # triggered before the action is invoked
  def new
    # ...
  end
end
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key   | Description                                               | Example                                   |
| ------------- | --------------------------------------------------------- | ----------------------------------------- |
| `:controller` | The controller name                                       | `"PostsController"`                       |
| `:action`     | The action                                                | `"new"`                                   |
| `:request`    | The [`ActionDispatch::Request`][] object                  | `#<ActionDispatch::Request ...>`          |
| `:params`     | Hash of request parameters without any filtered parameter | `{"controller"=>"posts","action"=>"new"}` |
| `:headers`    | Request headers                                           | `#<ActionDispatch::Http::Headers ...>`    |
| `:format`     | html/js/json/xml etc                                      | `:html`                                   |
| `:method`     | HTTP request verb                                         | `"GET"`                                   |
| `:path`       | Request path                                              | `"/posts/new"`                            |

#### `process_action.action_controller`

The event is emitted when a controller action finishes processing (after filters
and action execution, before the response is committed).

For example:

```ruby
class PostsController < ApplicationController
  def index
    @posts = Post.limit(10)
    render :index        # event fires as the action finishes, before commit
  end
end
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key     | Description                                               | Example                                     |
| --------------- | --------------------------------------------------------- | ------------------------------------------- |
| `:controller`   | The controller name                                       | `"PostsController"`                         |
| `:action`       | The action                                                | `"index"`                                   |
| `:params`       | Hash of request parameters without any filtered parameter | `{"controller"=>"posts","action"=>"index"}` |
| `:headers`      | Request headers                                           | `#<ActionDispatch::Http::Headers ...>`      |
| `:format`       | html/js/json/xml etc                                      | `:html`                                     |
| `:method`       | HTTP request verb                                         | `"GET"`                                     |
| `:path`         | Request path                                              | `"/posts"`                                  |
| `:request`      | The [`ActionDispatch::Request`][] object                  | `#<ActionDispatch::Request ...>`            |
| `:response`     | The [`ActionDispatch::Response`][] object                 | `#<ActionDispatch::Response ...>`           |
| `:status`       | HTTP status code                                          | `200`                                       |
| `:view_runtime` | Amount spent in view in ms                                | `46.848`                                    |
| `:db_runtime`   | Amount spent executing database queries in ms             | `0.157`                                     |

#### `send_file.action_controller`

The event is emitted when a controller streams or sends a file with `send_file`.

For example:

```ruby
send_file "/var/app/exports/report.csv",
  filename: "report.csv",
  disposition: "attachment"
```

The event payload (`event.payload`) includes the file path plus any options you
pass to send_file.

| Payload Key | Description               | Example                         |
| ----------- | ------------------------- | ------------------------------- |
| `:path`     | Complete path to the file | `"/var/app/exports/report.csv"` |

In this case, the payload will always contain the `:path` key, but will also
contain the `:filename`, and `:disposition` keys which are passed to the
`send_file` method.

#### `send_data.action_controller`

The event is emitted when a controller sends raw data with `send_data`.

For example:

```ruby
send_data "Hello, world!",
  filename: "report.txt",
  type: "text/plain",
  disposition: "attachment"
```

`ActionController` does not add any specific information to the payload. All
options that you pass into `send_data` are passed through to the payload. Hence,
in the example above, the payload will contain the keys `:filename`, `:type`,
and `:disposition`.

#### `redirect_to.action_controller`

The event is emitted when a redirect response is issued by a controller using
`redirect_to`.

For example:

```ruby
class PostsController < ApplicationController
  def old
    redirect_to posts_url
  end
end
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description                       | Example                             |
| ----------- | --------------------------------- | ----------------------------------- |
| `:status`   | HTTP response code                | `302`                               |
| `:location` | URL to redirect to                | `"http://localhost:3000/posts/new"` |
| `:request`  | The [`ActionDispatch::Request`][] | `#<ActionDispatch::Request ...>`    |

#### `halted_callback.action_controller`

The event is emitted when a before/around/after callback halts the action chain.

For example:

```ruby
class PostsController < ApplicationController
  before_action :require_login
end
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description                   | Example            |
| ----------- | ----------------------------- | ------------------ |
| `:filter`   | Filter that halted the action | `":require_login"` |

#### `unpermitted_parameters.action_controller`

The event is emitted when strong parameters filtering detects unpermitted keys.

For example:

```ruby
class UsersController < ApplicationController
  def create
    # params = { user: { name: "Ada", admin: true } }
    permitted = params.require(:user).permit(:name) # :admin is unpermitted
    User.create!(permitted)
  end
end
# => triggers unpermitted_parameters.action_controller
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description                                               | Example                                  |
| ----------- | --------------------------------------------------------- | ---------------------------------------- |
| `:keys`     | The unpermitted keys                                      | `["admin"]`                              |
| `:context`  | Hash with `:controller`, `:action`, `:params`, `:request` | `{ controller: "UsersController", ... }` |

#### `send_stream.action_controller`

The event is emitted when a controller streams data with `send_stream`.

For example:

```ruby
send_stream(filename: "subscribers.csv") do |stream|
  # ...
end
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key    | Description              | Example             |
| -------------- | ------------------------ | ------------------- |
| `:filename`    | The filename             | `"subscribers.csv"` |
| `:type`        | HTTP content type        | `"text/csv"`        |
| `:disposition` | HTTP content disposition | `"attachment"`      |

#### `rate_limit.action_controller`

The event is emitted when a request is throttled/limited by an Action Controller
rate limit.

For example:

```ruby
class PostsController < ApplicationController
  rate_limit to: 100, within: 1.minute
end
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key  | Description                              | Example                          |
| ------------ | ---------------------------------------- | -------------------------------- |
| `:request`   | The [`ActionDispatch::Request`][] object | `#<ActionDispatch::Request ...>` |
| `:count`     | Number of requests made                  | `101`                            |
| `:to`        | Maximum number of requests allowed       | `100`                            |
| `:within`    | Time window for the rate limit           | `60.seconds`                     |
| `:by`        | Identifier for the rate limit (e.g. IP)  | `"203.0.113.7"`                  |
| `:name`      | Name of the rate limit                   | `"api_read"`                     |
| `:scope`     | Scope of the rate limit                  | `"users#index"`                  |
| `:cache_key` | Cache key used for the rate limit        | `"rate:api_read:203.0.113.7"`    |

### Action Controller: Caching

#### `write_fragment.action_controller`

The event is emitted when a fragment is written to the cache.

For example:

```ruby
class DashboardsController < ApplicationController
  def show
    write_fragment("dashboards/#{params[:id]}", render_to_string(:show))
  end
end
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description      | Example                    |
| ----------- | ---------------- | -------------------------- |
| `:key`      | The complete key | `"posts/1-dashboard-view"` |

#### `read_fragment.action_controller`

The event is emitted when a fragment is read from the cache.

For example:

```ruby
class DashboardsController < ApplicationController
  def show
    if fragment = read_fragment("dashboards/#{params[:id]}")
      render html: fragment.html_safe and return
    end
    # ...
  end
end
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description      | Example                    |
| ----------- | ---------------- | -------------------------- |
| `:key`      | The complete key | `"posts/1-dashboard-view"` |

#### `expire_fragment.action_controller`

The event is emitted when a cached fragment is expired.

For example:

```ruby
expire_fragment("dashboards/#{params[:id]}")
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description      | Example                    |
| ----------- | ---------------- | -------------------------- |
| `:key`      | The complete key | `"posts/1-dashboard-view"` |

#### `exist_fragment?.action_controller`

The event is emitted when checking whether a fragment exists.

For example:

```ruby
fragment_exist?("dashboards/#{params[:id]}")
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description      | Example                    |
| ----------- | ---------------- | -------------------------- |
| `:key`      | The complete key | `"posts/1-dashboard-view"` |

### Action Dispatch

#### `process_middleware.action_dispatch`

The event is emitted when a Rack middleware is invoked in the stack.

For example:

```ruby
# config/application.rb
config.middleware.use Class.new {
  def initialize(app) = @app = app
  def call(env)
    # event fires when the middleware is invoked
    @app.call(env)
  end
}
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key   | Description            | Example           |
| ------------- | ---------------------- | ----------------- |
| `:middleware` | Name of the middleware | `"Rack::Runtime"` |

#### `redirect.action_dispatch`

The event is emitted when Action Dispatch builds a low-level redirect response.

For example:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  get "/old", to: redirect("/new")
end
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key        | Description                              | Example                          |
| ------------------ | ---------------------------------------- | ---------------------------------|
| `:status`          | HTTP response code                       | `302`                            |
| `:location`        | URL to redirect to                       | `"https://example.com/sign_in"`  |
| `:request`         | The [`ActionDispatch::Request`][] object | `#<ActionDispatch::Request ...>` |
| `:source_location` | Source location of redirect in routes    | `"config/routes.rb:10"`          |

#### `request.action_dispatch`

The event is emitted when a request object is initialized/processed at the
Action Dispatch layer.

For example:

```ruby
class PeekRequest
  def initialize(app) = @app = app
  def call(env)
    req = ActionDispatch::Request.new(env) # builds the request object
    @app.call(env)
  end
end
Rails.application.config.middleware.use PeekRequest
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description                       | Example                          |
| ----------- | --------------------------------- | -------------------------------- |
| `:request`  | The [`ActionDispatch::Request`][] | `#<ActionDispatch::Request ...>` |

### Action Mailbox

#### `process.action_mailbox`

The event is emitted when an inbound email is dispatched to a mailbox for
processing.

For example:

```ruby
# app/mailboxes/replies_mailbox.rb
class RepliesMailbox < ApplicationMailbox
  def process
    # handle inbound email...
  end
end
# An inbound email routed to RepliesMailbox -> triggers process.action_mailbox
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key      | Description                                                     | Example                                              |
| ---------------- | --------------------------------------------------------------- | ---------------------------------------------------- |
| `:mailbox`       | Instance of a Mailbox inheriting from [`ActionMailbox::Base`][] | `#<RepliesMailbox ...>`                              |
| `:inbound_email` | Hash describing the inbound email being processed               | `{ id: 1, message_id: "...", status: "processing" }` |

[`ActionMailbox::Base`]:
    https://api.rubyonrails.org/classes/ActionMailbox/Base.html

### Action Mailer

#### `deliver.action_mailer`

The event is emitted when a mail is delivered (after the message is generated
and delivery is attempted).

For example:

```ruby
UserMailer.welcome(current_user).deliver_now
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key           | Description                   | Example                |
| --------------------- | ----------------------------- | ---------------------- |
| `:mailer`             | Name of the mailer class      | `"Notification"`       |
| `:message_id`         | ID of the message (Mail gem)  | `"<abc@host>"`         |
| `:subject`            | Subject of the mail           | `"Rails Guides"`       |
| `:to`                 | To address(es)                | `["users@rails.com"]`  |
| `:from`               | From address                  | `["me@rails.com"]`     |
| `:bcc`                | BCC addresses                 | `[]`                   |
| `:cc`                 | CC addresses                  | `[]`                   |
| `:date`               | Date of the mail              | `Sat, 10 Mar 2012 ...` |
| `:mail`               | Encoded form of the mail      | `"(omitted)"`          |
| `:perform_deliveries` | Whether delivery is performed | `true`                 |

#### `process.action_mailer`

The event is emitted when a mailer action is invoked to build a message.

For example:

```ruby
UserMailer.welcome(current_user) # building the message triggers process.action_mailer
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description              | Example           |
| ----------- | ------------------------ | ----------------- |
| `:mailer`   | Name of the mailer class | `"Notification"`  |
| `:action`   | The action               | `"welcome_email"` |
| `:args`     | The arguments            | `[]`              |

### Action View

#### `render_template.action_view`

The event is emitted when a full template (with optional layout) is rendered.

For example:

```ruby
render :index, layout: "application"
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key   | Description                        | Example                                |
| ------------- | ---------------------------------- | -------------------------------------- |
| `:identifier` | Full path to template              | `".../app/views/posts/index.html.erb"` |
| `:layout`     | Applicable layout                  | `"layouts/application"`                |
| `:locals`     | Local variables passed to template | `{ foo: "bar" }`                       |

#### `render_partial.action_view`

The event is emitted when a partial is rendered.

For example:

```erb
<%= render "form", post: @post %>
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key   | Description                        | Example                                |
| ------------- | ---------------------------------- | -------------------------------------- |
| `:identifier` | Full path to template              | `".../app/views/posts/_form.html.erb"` |
| `:locals`     | Local variables passed to template | `{ foo: "bar" }`                       |

#### `render_collection.action_view`

The event is emitted when a collection of partials is rendered.

For example:

```erb
<%= render partial: "post", collection: @posts, cached: true %>
```

The event payload (`event.payload`) includes the keys below; some appear only in
certain conditions (noted).

| Payload Key   | Description                           | Example                                |
| ------------- | ------------------------------------- | -------------------------------------- |
| `:identifier` | Full path to template                 | `".../app/views/posts/_post.html.erb"` |
| `:count`      | Size of collection                    | `3`                                    |
| `:cache_hits` | Number of partials fetched from cache | `0`                                    |

`:cache_hits` appears only when rendered with `cached: true`.

#### `render_layout.action_view`

The event is emitted when a layout is rendered around content.

For example:

```ruby
render inline: "<p>Hello</p>", layout: "marketing"
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key   | Description           | Example                                        |
| ------------- | --------------------- | ---------------------------------------------- |
| `:identifier` | Full path to template | `".../app/views/layouts/application.html.erb"` |

[`ActionDispatch::Request`]:
    https://api.rubyonrails.org/classes/ActionDispatch/Request.html
[`ActionDispatch::Response`]:
    https://api.rubyonrails.org/classes/ActionDispatch/Response.html

### Active Job

```ruby
class MyJob < ApplicationJob
  queue_as :default
  retry_on Timeout::Error, wait: 30.seconds, attempts: 2

  def perform(arg)
    # work...
  end
end
```

#### `enqueue_at.active_job`

The event is emitted when a job is scheduled to run at a future time.

For example:

```ruby
MyJob.set(wait_until: 1.hour.from_now).perform_later("hello")
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description                     | Example                            |
| ----------- | ------------------------------- | ---------------------------------- |
| `:adapter`  | QueueAdapter processing the job | `#<ActiveJob::QueueAdapters::...>` |
| `:job`      | Job object                      | `#<MyJob ...>`                     |

#### `enqueue.active_job`

The event is emitted when a job is enqueued to run as soon as possible.

For example:

```ruby
MyJob.perform_later("now")
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description                     | Example        |
| ----------- | ------------------------------- | -------------- |
| `:adapter`  | QueueAdapter processing the job | `#<...>`       |
| `:job`      | Job object                      | `#<MyJob ...>` |

#### `enqueue_retry.active_job`

The event is emitted when a job is scheduled for retry due to an error.

For example:

```ruby
MyJob.perform_later("fail to retry")
# inside perform, raise Timeout::Error => Active Job schedules retry
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description                     | Example                 |
| ----------- | ------------------------------- | ----------------------- |
| `:job`      | Job object                      | `#<MyJob ...>`          |
| `:adapter`  | QueueAdapter processing the job | `#<...>`                |
| `:error`    | The error that caused the retry | `#<Timeout::Error ...>` |
| `:wait`     | The delay of the retry          | `30.seconds`            |

#### `enqueue_all.active_job`

The event is emitted when multiple jobs are enqueued together.

For example:

```ruby
jobs = [ MyJob.new, MyJob.new ]
ActiveJob::Base.enqueue_all(jobs) # when supported by the adapter
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description                     | Example                 |
| ----------- | ------------------------------- | ----------------------- |
| `:adapter`  | QueueAdapter processing the job | `#<...>`                |
| `:jobs`     | An array of Job objects         | `[ #<MyJob ...>, ... ]` |

#### `perform_start.active_job`

The event is emitted when job execution starts (on the worker).

For example:

```ruby
# Fired on the worker right before perform begins
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description                     | Example        |
| ----------- | ------------------------------- | -------------- |
| `:adapter`  | QueueAdapter processing the job | `#<...>`       |
| `:job`      | Job object                      | `#<MyJob ...>` |

#### `perform.active_job`

The event is emitted when job execution finishes (on the worker).

For example:

```ruby
# Fired after perform finishes (success or handled failure)
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key   | Description                             | Example        |
| ------------- | --------------------------------------- | -------------- |
| `:adapter`    | QueueAdapter processing the job         | `#<...>`       |
| `:job`        | Job object                              | `#<MyJob ...>` |
| `:db_runtime` | Amount spent executing DB queries in ms | `12.34`        |

#### `retry_stopped.active_job`

The event is emitted when the retry mechanism stops retrying a job.

For example:

```ruby
# After exhausting retries (per retry_on), the job stops retrying
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description                     | Example                 |
| ----------- | ------------------------------- | ----------------------- |
| `:adapter`  | QueueAdapter processing the job | `#<...>`                |
| `:job`      | Job object                      | `#<MyJob ...>`          |
| `:error`    | The error that caused the retry | `#<Timeout::Error ...>` |

#### `discard.active_job`

The event is emitted when a job is discarded (will no longer be retried).

For example:

```ruby
class MyJob < ApplicationJob
  discard_on StandardError
end
MyJob.perform_later("oops") # error -> discarded
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description                       | Example                |
| ----------- | --------------------------------- | ---------------------- |
| `:adapter`  | QueueAdapter processing the job   | `#<...>`               |
| `:job`      | Job object                        | `#<MyJob ...>`         |
| `:error`    | The error that caused the discard | `#<StandardError ...>` |

### Active Record

#### `sql.active_record`

The event is emitted when Active Record executes an SQL statement.

For example:

```ruby
Post.where(published: true).limit(5).to_a
```

The event payload (`event.payload`) typically includes the keys below, but
adapters/services may add more keys to the payload.

| Payload Key          | Description                                      | Example                                             |
| -------------------- | ------------------------------------------------ | --------------------------------------------------- |
| `:sql`               | SQL statement                                    | `"SELECT \"posts\".* FROM \"posts\""`               |
| `:name`              | Name of the operation                            | `"Post Load"`                                       |
| `:binds`             | Bind parameters                                  | `[ #<ActiveModel::Attribute::WithCastValue ...> ]`  |
| `:type_casted_binds` | Typecasted bind parameters                       | `[11]`                                              |
| `:async`             | `true` if query is loaded asynchronously         | `false`                                             |
| `:allow_retry`       | `true` if the query can be automatically retried | `true`                                              |
| `:connection`        | Connection object                                | `#<ActiveRecord::ConnectionAdapters::...>`          |
| `:transaction`       | Current transaction, if any                      | `#<ActiveRecord::ConnectionAdapters::...>` or `nil` |
| `:affected_rows`     | Number of rows affected by the query             | `0`                                                 |
| `:row_count`         | Number of rows returned by the query             | `5`                                                 |
| `:cached`            | `true` when result comes from the query cache    | `true`/`false`                                      |
| `:statement_name`    | SQL statement name (Postgres only)               | `nil`                                               |

#### `strict_loading_violation.active_record`

The event is emitted when a lazily loaded association is accessed on a model
with `strict_loading`, and
[`config.active_record.action_on_strict_loading_violation`][] is set to `:log`.

For example:

```ruby
user = User.strict_loading.first
user.posts.to_a  # lazy load => triggers strict_loading_violation (when config logs)
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key   | Description                                      | Example                           |
| ------------- | ------------------------------------------------ | --------------------------------- |
| `:owner`      | Model with `strict_loading` enabled              | `#<User id: 1 ...>`               |
| `:reflection` | Reflection of the association that tried to load | `#<ActiveRecord::Reflection ...>` |

[`config.active_record.action_on_strict_loading_violation`]:
    configuring.html#config-active-record-action-on-strict-loading-violation

#### `instantiation.active_record`

The event is emitted when Active Record instantiates model objects from query
results.

For example:

```ruby
User.all.to_a
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key     | Description                    | Example  |
| --------------- | ------------------------------ | -------- |
| `:record_count` | Number of records instantiated | `1`      |
| `:class_name`   | Record’s class                 | `"User"` |

#### `start_transaction.active_record`

The event is emitted when Active Record starts a database transaction (on first
DB interaction inside a `transaction` block).

NOTE:  Active Record does not create the actual database transaction until
needed.

For example:

```ruby
ActiveRecord::Base.transaction do
  # We are inside the block, but no event has been triggered yet.

  # The following line makes Active Record start the transaction.
  User.count  # Event fired here.
end
```

Ordinary nested calls do not create new transactions:

```ruby
ActiveRecord::Base.transaction do |t1|
  User.count # Fires an event for t1.
  ActiveRecord::Base.transaction do |t2|
    # The next line fires no event for t2, because the only
    # real database transaction in this example is t1.
    User.first.touch
  end
end
```

However, if `requires_new: true` is passed, you get an event for the nested
transaction too.

```ruby
ActiveRecord::Base.transaction do |t1|
  User.count # Fires an event for t1.
  ActiveRecord::Base.transaction(requires_new: true) do |t2|
    User.first.touch # Fires an event for t2.
  end
end
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key    | Description        | Example                                    |
| -------------- | ------------------ | ------------------------------------------ |
| `:transaction` | Transaction object | `#<ActiveRecord::ConnectionAdapters::...>` |
| `:connection`  | Connection object  | `#<ActiveRecord::ConnectionAdapters::...>` |

#### `transaction.active_record`

The event is emitted when a database transaction finishes. The state of the
transaction can be found in the `:outcome` key.

For example:

```ruby
ActiveRecord::Base.transaction do
  # work...
end # commit/rollback => triggers transaction.active_record with :outcome
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key    | Description                                          | Example                |
| -------------- | ---------------------------------------------------- | ---------------------- |
| `:transaction` | Transaction object                                   | `#<ActiveRecord::...>` |
| `:outcome`     | `:commit`, `:rollback`, `:restart`, or `:incomplete` | `:commit`              |
| `:connection`  | Connection object                                    | `#<ActiveRecord::...>` |

In practice, you cannot do much with the transaction object, but it may still be
helpful for tracing database activity. For example, by tracking
`transaction.uuid`.

#### `deprecated_association.active_record`

The event is emitted when a deprecated association is accessed, and the
configured deprecated associations mode is `:notify`.

For example:

```ruby
# config/initializers/active_record_deprecations.rb
ActiveRecord.deprecate_associations = :notify

# app/models/book.rb
class Book < ApplicationRecord
  has_many :authors, deprecated: "Use `writers` instead"
  has_many :writers, class_name: "Author"
end

Book.first.authors # triggers deprecated_association.active_record
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key   | Description                                | Example                                  |
| ------------- | ------------------------------------------ | ---------------------------------------- |
| `:reflection` | The reflection of the association          | `#<ActiveRecord::Reflection ...>`        |
| `:message`    | Descriptive message about the access       | `"authors is deprecated"`                |
| `:location`   | Application-level location of the access   | `#<Thread::Backtrace::Location ...>`     |
| `:backtrace`  | Present if the `:backtrace` option is true | `[ #<Thread::Backtrace::Location ...> ]` |

`:location` and `:backtrace` are computed using the Active Record backtrace
cleaner. In Rails applications, this is the same as `Rails.backtrace_cleaner.

### Active Storage

#### `preview.active_storage`

The event is emitted when a preview is generated for a blob.

For example:

```ruby
blob = ActiveStorage::Blob.find(params[:id])
blob.preview(resize_to_limit: [200, 200]).processed
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description  | Example    |
| ----------- | ------------ | ---------- |
| `:key`      | Secure token | `"abc123"` |

#### `transform.active_storage`

The event is emitted when a variant/representation transformation is performed.

For example:

```ruby
image = current_user.avatar.variant(resize_to_limit: [300, 300]).processed
```

The event payload (`event.payload`) has no additional standard keys documented.

#### `analyze.active_storage`

The event is emitted when a blob is analyzed to extract metadata.

For example:

```ruby
blob = ActiveStorage::Blob.find(params[:id])
blob.analyze
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description                     | Example     |
| ----------- | ------------------------------- | ----------- |
| `:analyzer` | Name of analyzer (e.g. ffprobe) | `"ffprobe"` |

### Active Storage: Storage Service

#### `service_upload.active_storage`

The event is emitted when a blob is uploaded to a storage service.

For example:

```ruby
current_user.avatar.attach(io: File.open("/path/pic.jpg"), filename: "pic.jpg")
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description            | Example     |
| ----------- | ---------------------- | ----------- |
| `:key`      | Secure token           | `"abc123"`  |
| `:service`  | Name of the service    | `"S3"`      |
| `:checksum` | Checksum for integrity | `"md5:..."` |

#### `service_streaming_download.active_storage`

The event is emitted when a blob is streamed from a storage service.

For example:

```ruby
send_data current_user.avatar.download, disposition: :inline
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description         | Example    |
| ----------- | ------------------- | ---------- |
| `:key`      | Secure token        | `"abc123"` |
| `:service`  | Name of the service | `"S3"`     |

#### `service_download_chunk.active_storage`

The event is emitted when a chunked download reads a byte range from a storage
service.

For example:

```ruby
current_user.avatar.service.download_chunk(current_user.avatar.key, 0..1_048_575)
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description          | Example       |
| ----------- | -------------------- | ------------- |
| `:key`      | Secure token         | `"abc123"`    |
| `:service`  | Name of the service  | `"S3"`        |
| `:range`    | Byte range attempted | `"0-1048575"` |

#### `service_download.active_storage`

The event is emitted when a blob is downloaded from a storage service.

For example:

```ruby
current_user.avatar.download
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description         | Example    |
| ----------- | ------------------- | ---------- |
| `:key`      | Secure token        | `"abc123"` |
| `:service`  | Name of the service | `"S3"`     |

#### `service_delete.active_storage`

The event is emitted when a blob is deleted from a storage service.

For example:

```ruby
current_user.avatar.purge
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description         | Example    |
| ----------- | ------------------- | ---------- |
| `:key`      | Secure token        | `"abc123"` |
| `:service`  | Name of the service | `"S3"`     |

#### `service_delete_prefixed.active_storage`

The event is emitted when all blobs with a given key prefix are deleted.

For example:

```ruby
ActiveStorage::Blob.service.delete_prefixed("tmp/")
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description     | Example  |
| ----------- | --------------- | -------- |
| `:prefix`   | Key prefix      | `"tmp/"` |
| `:service`  | Name of service | `"S3"`   |

#### `service_exist.active_storage`

The event is emitted when existence of a blob is checked in a storage service.

For example:

```ruby
ActiveStorage::Blob.service.exist?(blob.key)
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description             | Example    |
| ----------- | ----------------------- | ---------- |
| `:key`      | Secure token            | `"abc123"` |
| `:service`  | Name of the service     | `"S3"`     |
| `:exist`    | File/blob exists or not | `true`     |

#### `service_url.active_storage`

The event is emitted when a URL is generated for a blob/object.

For example:

```ruby
ActiveStorage::Blob.service.url(blob.key)
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description         | Example                  |
| ----------- | ------------------- | ------------------------ |
| `:key`      | Secure token        | `"abc123"`               |
| `:service`  | Name of the service | `"S3"`                   |
| `:url`      | Generated URL       | `"https://s3.../abc123"` |

#### `service_update_metadata.active_storage`

The event is emitted when object metadata is updated in the storage service
(Google Cloud Storage only).

For example:

```ruby
ActiveStorage::Blob.service.update_metadata(
  blob.key, content_type: "image/png", disposition: "inline"
)
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key     | Description                | Example       |
| --------------- | -------------------------- | ------------- |
| `:key`          | Secure token               | `"abc123"`    |
| `:service`      | Name of the service        | `"GCS"`       |
| `:content_type` | HTTP `Content-Type`        | `"image/png"` |
| `:disposition`  | HTTP `Content-Disposition` | `"inline"`    |

### Active Support: Caching

#### `cache_read.active_support`

The event is emitted when a read is performed against the cache store.

For example:

```ruby
Rails.cache.read("user:1:settings")
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key        | Description                         | Example                       |
| ------------------ | ----------------------------------- | ----------------------------- |
| `:key`             | Key used in the store               | `"user:1:settings"`           |
| `:store`           | Name of the store class             | `"ActiveSupport::Cache::..."` |
| `:hit`             | If this read is a hit               | `true`                        |
| `:super_operation` | `:fetch` if the read is via `fetch` | `:fetch`                      |

#### `cache_read_multi.active_support`

The event is emitted when multiple keys are read from the cache.

For example:

```ruby
Rails.cache.read_multi("u:1", "u:2")
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key        | Description                                                                    | Example                       |
| ------------------ | ------------------------------------------------------------------------------ | ----------------------------- |
| `:key`             | Keys used in the store                                                         | `["u:1","u:2"]`               |
| `:store`           | Name of the store class                                                        | `"ActiveSupport::Cache::..."` |
| `:hits`            | Keys of cache hits                                                             | `["u:1"]`                     |
| `:super_operation` | `:fetch_multi` if via [`fetch_multi`][ActiveSupport::Cache::Store#fetch_multi] | `:fetch_multi`                |

#### `cache_generate.active_support`

The event is emitted when a cached value is generated during
[`fetch`][ActiveSupport::Cache::Store#fetch] with a block.

For example:

```ruby
Rails.cache.fetch("expensive:calc") { do_expensive_work }
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description             | Example                                 |
| ----------- | ----------------------- | --------------------------------------- |
| `:key`      | Key used in the store   | `"expensive:calc"`                      |
| `:store`    | Name of the store class | `"ActiveSupport::Cache::MemCacheStore"` |

Options passed to `fetch` will be merged with the payload when writing to the
store.

#### `cache_fetch_hit.active_support`

The event is emitted when `fetch` with a block returns a cached value.

For example:

```ruby
Rails.cache.fetch("expensive:calc") { do_expensive_work } # cache hit
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description             | Example                                 |
| ----------- | ----------------------- | --------------------------------------- |
| `:key`      | Key used in the store   | `"expensive:calc"`                      |
| `:store`    | Name of the store class | `"ActiveSupport::Cache::MemCacheStore"` |

#### `cache_write.active_support`

The event is emitted when a value is written to the cache.

For example:

```ruby
Rails.cache.write("expensive:calc", 42)
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description             | Example                                 |
| ----------- | ----------------------- | --------------------------------------- |
| `:key`      | Key used in the store   | `"expensive:calc"`                      |
| `:store`    | Name of the store class | `"ActiveSupport::Cache::MemCacheStore"` |

Cache stores may add their own data as well.

#### `cache_write_multi.active_support`

The event is emitted when multiple values are written to the cache.

For example:

```ruby
Rails.cache.write_multi("a" => 1, "b" => 2)
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description                          | Example                       |
| ----------- | ------------------------------------ | ----------------------------- |
| `:key`      | Keys and values written to the store | `{ "a"=>1, "b"=>2 }`          |
| `:store`    | Name of the store class              | `"ActiveSupport::Cache::..."` |

#### `cache_increment.active_support`

The event is emitted when a counter is incremented in the cache.

For example:

```ruby
Rails.cache.increment("counter", 5)
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description             | Example                                   |
| ----------- | ----------------------- | ----------------------------------------- |
| `:key`      | Key used in the store   | `"bottles-of-beer"`                       |
| `:store`    | Name of the store class | `"ActiveSupport::Cache::RedisCacheStore"` |
| `:amount`   | Increment amount        | `99`                                      |

#### `cache_decrement.active_support`

The event is emitted when a counter is decremented in the cache.

For example:

```ruby
Rails.cache.decrement("counter", 1)
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description             | Example                                   |
| ----------- | ----------------------- | ----------------------------------------- |
| `:key`      | Key used in the store   | `"bottles-of-beer"`                       |
| `:store`    | Name of the store class | `"ActiveSupport::Cache::RedisCacheStore"` |
| `:amount`   | Decrement amount        | `1`                                       |

#### `cache_delete.active_support`

The event is emitted when a key is deleted from the cache.

For example:

```ruby
Rails.cache.delete("expensive:calc")
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description             | Example                                 |
| ----------- | ----------------------- | --------------------------------------- |
| `:key`      | Key used in the store   | `"expensive:calc"`                      |
| `:store`    | Name of the store class | `"ActiveSupport::Cache::MemCacheStore"` |

#### `cache_delete_multi.active_support`

The event is emitted when multiple keys are deleted from the cache.

For example:

```ruby
Rails.cache.delete_multi("a", "b", "c")
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description        | Example                       |
| ----------- | ------------------ | ----------------------------- |
| `:key`      | Keys used in store | `["a","b","c"]`               |
| `:store`    | Name of the store  | `"ActiveSupport::Cache::..."` |

#### `cache_delete_matched.active_support`

The event is emitted when keys matching a pattern are deleted (supported by
`RedisCacheStore`, `FileStore`, `MemoryStore`).

For example:

```ruby
Rails.cache.delete_matched("posts/*")
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description       | Example                                   |
| ----------- | ----------------- | ----------------------------------------- |
| `:key`      | Key pattern       | `"posts/*"`                               |
| `:store`    | Name of the store | `"ActiveSupport::Cache::RedisCacheStore"` |

#### `cache_cleanup.active_support`

The event is emitted when `MemoryStore` performs a full cleanup.

For example:

```ruby
Rails.cache.cleanup
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description                      | Example                               |
| ----------- | -------------------------------- | ------------------------------------- |
| `:store`    | Name of the store class          | `"ActiveSupport::Cache::MemoryStore"` |
| `:size`     | Number of entries before cleanup | `9001`                                |

#### `cache_prune.active_support`

The event is emitted when `MemoryStore` prunes entries to reduce size.

For example:

```ruby
Rails.cache.prune(5.megabytes)
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description             | Example                               |
| ----------- | ----------------------- | ------------------------------------- |
| `:store`    | Name of the store class | `"ActiveSupport::Cache::MemoryStore"` |
| `:key`      | Target size (in bytes)  | `5000`                                |
| `:from`     | Size (in bytes) before  | `9001`                                |

#### `cache_exist?.active_support`

The event is emitted when existence of a key is checked in the cache.

For example:

```ruby
Rails.cache.exist?("expensive:calc")
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key | Description             | Example                                 |
| ----------- | ----------------------- | --------------------------------------- |
| `:key`      | Key used in the store   | `"expensive:calc"`                      |
| `:store`    | Name of the store class | `"ActiveSupport::Cache::MemCacheStore"` |

[ActiveSupport::Cache::FileStore]:
    https://api.rubyonrails.org/classes/ActiveSupport/Cache/FileStore.html
[ActiveSupport::Cache::MemCacheStore]:
    https://api.rubyonrails.org/classes/ActiveSupport/Cache/MemCacheStore.html
[ActiveSupport::Cache::MemoryStore]:
    https://api.rubyonrails.org/classes/ActiveSupport/Cache/MemoryStore.html
[ActiveSupport::Cache::RedisCacheStore]:
    https://api.rubyonrails.org/classes/ActiveSupport/Cache/RedisCacheStore.html
[ActiveSupport::Cache::Store#fetch]:
    https://api.rubyonrails.org/classes/ActiveSupport/Cache/Store.html#method-i-fetch
[ActiveSupport::Cache::Store#fetch_multi]:
    https://api.rubyonrails.org/classes/ActiveSupport/Cache/Store.html#method-i-fetch_multi

### Active Support: Messages

#### `message_serializer_fallback.active_support`

The event is emitted when the configured primary message serializer fails and
Active Support falls back to a different serializer.

For example:

```ruby
ActiveSupport::MessageEncryptor.default_message_serializer = :json_allow_marshal
enc = ActiveSupport::MessageEncryptor.new(
  ActiveSupport::KeyGenerator.new("secret").generate_key("salt", 32)
)
enc.encrypt_and_sign(Object.new) # not JSON-serializable -> falls back
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key     | Description        | Example                                                |
| --------------- | ------------------ | ------------------------------------------------------ |
| `:serializer`   | Primary (intended) | `:json_allow_marshal`                                  |
| `:fallback`     | Fallback (actual)  | `:marshal`                                             |
| `:serialized`   | Serialized string  | `\x04\b{\x06I\"\nHello\x06:\x06ETI\"\nWorld\x06;\x00T` |
| `:deserialized` | Deserialized value | `{ "Hello"=>"World" }`                                 |

### Rails

#### `deprecation.rails`

The event is emitted when Rails emits a deprecation warning.

For example:

```ruby
ActiveSupport::Deprecation.warn("X is deprecated")
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key            | Description                                      | Example                     |
| ---------------------- | ------------------------------------------------ | --------------------------- |
| `:message`             | The deprecation warning                          | `"X is deprecated..."`      |
| `:callstack`           | Where the deprecation came from                  | `[ ".../file.rb:42", ... ]` |
| `:gem_name`            | Name of the gem reporting the deprecation        | `"rails"`                   |
| `:deprecation_horizon` | Version where the deprecated behavior is removed | `"8.0"`                     |

### Railties

#### `load_config_initializer.railties`

The event is emitted when an initializer file in `config/initializers` is loaded
during boot.

For example:

```ruby
# config/initializers/timezone.rb
Rails.application.config.time_zone = "Pretoria"
# Loaded during boot -> triggers load_config_initializer.railties
```

The event payload (`event.payload`) includes the following keys (with typical
example values).

| Payload Key    | Description                    | Example                             |
| -------------- | ------------------------------ | ----------------------------------- |
| `:initializer` | Path of the loaded initializer | `"config/initializers/timezone.rb"` |


Exceptions
----------

If an exception happens during any instrumentation, the payload will include
information about it.

| Key                 | Description                                                          |
| ------------------- | -------------------------------------------------------------- |
| `:exception`        | An array of two elements. Exception class name and the message |
| `:exception_object` | The exception object                                           |
