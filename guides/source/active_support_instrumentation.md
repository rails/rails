**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON http://guides.rubyonrails.org.**

Active Support Instrumentation
==============================

Active Support is a part of core Rails that provides Ruby language extensions, utilities and other things. One of the things it includes is an instrumentation API that can be used inside an application to measure certain actions that occur within Ruby code, such as that inside a Rails application or the framework itself. It is not limited to Rails, however. It can be used independently in other Ruby scripts if it is so desired.

In this guide, you will learn how to use the instrumentation API inside of Active Support to measure events inside of Rails and other Ruby code.

After reading this guide, you will know:

* What instrumentation can provide.
* The hooks inside the Rails framework for instrumentation.
* Adding a subscriber to a hook.
* Building a custom instrumentation implementation.

--------------------------------------------------------------------------------

Introduction to instrumentation
-------------------------------

The instrumentation API provided by Active Support allows developers to provide hooks which other developers may hook into. There are several of these within the [Rails framework](#rails-framework-hooks). With this API, developers can choose to be notified when certain events occur inside their application or another piece of Ruby code.

For example, there is a hook provided within Active Record that is called every time Active Record uses an SQL query on a database. This hook could be **subscribed** to, and used to track the number of queries during a certain action. There's another hook around the processing of an action of a controller. This could be used, for instance, to track how long a specific action has taken.

You are even able to create your own events inside your application which you can later subscribe to.

Rails framework hooks
---------------------

Within the Ruby on Rails framework, there are a number of hooks provided for common events. These are detailed below.

Action Controller
-----------------

### write_fragment.action_controller

| Key    | Value            |
| ------ | ---------------- |
| `:key` | The complete key |

```ruby
{
  key: 'posts/1-dashboard-view'
}
```

### read_fragment.action_controller

| Key    | Value            |
| ------ | ---------------- |
| `:key` | The complete key |

```ruby
{
  key: 'posts/1-dashboard-view'
}
```

### expire_fragment.action_controller

| Key    | Value            |
| ------ | ---------------- |
| `:key` | The complete key |

```ruby
{
  key: 'posts/1-dashboard-view'
}
```

### exist_fragment?.action_controller

| Key    | Value            |
| ------ | ---------------- |
| `:key` | The complete key |

```ruby
{
  key: 'posts/1-dashboard-view'
}
```

### write_page.action_controller

| Key     | Value             |
| ------- | ----------------- |
| `:path` | The complete path |

```ruby
{
  path: '/users/1'
}
```

### expire_page.action_controller

| Key     | Value             |
| ------- | ----------------- |
| `:path` | The complete path |

```ruby
{
  path: '/users/1'
}
```

### start_processing.action_controller

| Key           | Value                                                     |
| ------------- | --------------------------------------------------------- |
| `:controller` | The controller name                                       |
| `:action`     | The action                                                |
| `:params`     | Hash of request parameters without any filtered parameter |
| `:headers`    | Request headers                                           |
| `:format`     | html/js/json/xml etc                                      |
| `:method`     | HTTP request verb                                         |
| `:path`       | Request path                                              |

```ruby
{
  controller: "PostsController",
  action: "new",
  params: { "action" => "new", "controller" => "posts" },
  headers: #<ActionDispatch::Http::Headers:0x0055a67a519b88>,
  format: :html,
  method: "GET",
  path: "/posts/new"
}
```

### process_action.action_controller

| Key             | Value                                                     |
| --------------- | --------------------------------------------------------- |
| `:controller`   | The controller name                                       |
| `:action`       | The action                                                |
| `:params`       | Hash of request parameters without any filtered parameter |
| `:headers`      | Request headers                                           |
| `:format`       | html/js/json/xml etc                                      |
| `:method`       | HTTP request verb                                         |
| `:path`         | Request path                                              |
| `:status`       | HTTP status code                                          |
| `:view_runtime` | Amount spent in view in ms                                |
| `:db_runtime`   | Amount spent executing database queries in ms             |

```ruby
{
  controller: "PostsController",
  action: "index",
  params: {"action" => "index", "controller" => "posts"},
  headers: #<ActionDispatch::Http::Headers:0x0055a67a519b88>,
  format: :html,
  method: "GET",
  path: "/posts",
  status: 200,
  view_runtime: 46.848,
  db_runtime: 0.157
}
```

### send_file.action_controller

| Key     | Value                     |
| ------- | ------------------------- |
| `:path` | Complete path to the file |

INFO. Additional keys may be added by the caller.

### send_data.action_controller

`ActionController` does not had any specific information to the payload. All options are passed through to the payload.

### redirect_to.action_controller

| Key         | Value              |
| ----------- | ------------------ |
| `:status`   | HTTP response code |
| `:location` | URL to redirect to |

```ruby
{
  status: 302,
  location: "http://localhost:3000/posts/new"
}
```

### halted_callback.action_controller

| Key       | Value                         |
| --------- | ----------------------------- |
| `:filter` | Filter that halted the action |

```ruby
{
  filter: ":halting_filter"
}
```

Action View
-----------

### render_template.action_view

| Key           | Value                 |
| ------------- | --------------------- |
| `:identifier` | Full path to template |
| `:layout`     | Applicable layout     |

```ruby
{
  identifier: "/Users/adam/projects/notifications/app/views/posts/index.html.erb",
  layout: "layouts/application"
}
```

### render_partial.action_view

| Key           | Value                 |
| ------------- | --------------------- |
| `:identifier` | Full path to template |

```ruby
{
  identifier: "/Users/adam/projects/notifications/app/views/posts/_form.html.erb"
}
```

### render_collection.action_view

| Key           | Value                                 |
| ------------- | ------------------------------------- |
| `:identifier` | Full path to template                 |
| `:count`      | Size of collection                    |
| `:cache_hits` | Number of partials fetched from cache |

`:cache_hits` is only included if the collection is rendered with `cached: true`.

```ruby
{
  identifier: "/Users/adam/projects/notifications/app/views/posts/_post.html.erb",
  count: 3,
  cache_hits: 0
}
```

Active Record
------------

### sql.active_record

| Key              | Value                                    |
| ---------------- | ---------------------------------------- |
| `:sql`           | SQL statement                            |
| `:name`          | Name of the operation                    |
| `:connection_id` | `self.object_id`                         |
| `:binds`         | Bind parameters                          |
| `:cached`        | `true` is added when cached queries used |

INFO. The adapters will add their own data as well.

```ruby
{
  sql: "SELECT \"posts\".* FROM \"posts\" ",
  name: "Post Load",
  connection_id: 70307250813140,
  binds: []
}
```

### instantiation.active_record

| Key              | Value                                     |
| ---------------- | ----------------------------------------- |
| `:record_count`  | Number of records that instantiated       |
| `:class_name`    | Record's class                            |

```ruby
{
  record_count: 1,
  class_name: "User"
}
```

Action Mailer
-------------

### receive.action_mailer

| Key           | Value                                        |
| ------------- | -------------------------------------------- |
| `:mailer`     | Name of the mailer class                     |
| `:message_id` | ID of the message, generated by the Mail gem |
| `:subject`    | Subject of the mail                          |
| `:to`         | To address(es) of the mail                   |
| `:from`       | From address of the mail                     |
| `:bcc`        | BCC addresses of the mail                    |
| `:cc`         | CC addresses of the mail                     |
| `:date`       | Date of the mail                             |
| `:mail`       | The encoded form of the mail                 |

```ruby
{
  mailer: "Notification",
  message_id: "4f5b5491f1774_181b23fc3d4434d38138e5@mba.local.mail",
  subject: "Rails Guides",
  to: ["users@rails.com", "ddh@rails.com"],
  from: ["me@rails.com"],
  date: Sat, 10 Mar 2012 14:18:09 +0100,
  mail: "..." # omitted for brevity
}
```

### deliver.action_mailer

| Key           | Value                                        |
| ------------- | -------------------------------------------- |
| `:mailer`     | Name of the mailer class                     |
| `:message_id` | ID of the message, generated by the Mail gem |
| `:subject`    | Subject of the mail                          |
| `:to`         | To address(es) of the mail                   |
| `:from`       | From address of the mail                     |
| `:bcc`        | BCC addresses of the mail                    |
| `:cc`         | CC addresses of the mail                     |
| `:date`       | Date of the mail                             |
| `:mail`       | The encoded form of the mail                 |

```ruby
{
  mailer: "Notification",
  message_id: "4f5b5491f1774_181b23fc3d4434d38138e5@mba.local.mail",
  subject: "Rails Guides",
  to: ["users@rails.com", "ddh@rails.com"],
  from: ["me@rails.com"],
  date: Sat, 10 Mar 2012 14:18:09 +0100,
  mail: "..." # omitted for brevity
}
```

Active Support
--------------

### cache_read.active_support

| Key                | Value                                             |
| ------------------ | ------------------------------------------------- |
| `:key`             | Key used in the store                             |
| `:hit`             | If this read is a hit                             |
| `:super_operation` | :fetch is added when a read is used with `#fetch` |

### cache_generate.active_support

This event is only used when `#fetch` is called with a block.

| Key    | Value                 |
| ------ | --------------------- |
| `:key` | Key used in the store |

INFO. Options passed to fetch will be merged with the payload when writing to the store

```ruby
{
  key: 'name-of-complicated-computation'
}
```


### cache_fetch_hit.active_support

This event is only used when `#fetch` is called with a block.

| Key    | Value                 |
| ------ | --------------------- |
| `:key` | Key used in the store |

INFO. Options passed to fetch will be merged with the payload.

```ruby
{
  key: 'name-of-complicated-computation'
}
```

### cache_write.active_support

| Key    | Value                 |
| ------ | --------------------- |
| `:key` | Key used in the store |

INFO. Cache stores may add their own keys

```ruby
{
  key: 'name-of-complicated-computation'
}
```

### cache_delete.active_support

| Key    | Value                 |
| ------ | --------------------- |
| `:key` | Key used in the store |

```ruby
{
  key: 'name-of-complicated-computation'
}
```

### cache_exist?.active_support

| Key    | Value                 |
| ------ | --------------------- |
| `:key` | Key used in the store |

```ruby
{
  key: 'name-of-complicated-computation'
}
```

Active Job
--------

### enqueue_at.active_job

| Key          | Value                                  |
| ------------ | -------------------------------------- |
| `:adapter`   | QueueAdapter object processing the job |
| `:job`       | Job object                             |

### enqueue.active_job

| Key          | Value                                  |
| ------------ | -------------------------------------- |
| `:adapter`   | QueueAdapter object processing the job |
| `:job`       | Job object                             |

### perform_start.active_job

| Key          | Value                                  |
| ------------ | -------------------------------------- |
| `:adapter`   | QueueAdapter object processing the job |
| `:job`       | Job object                             |

### perform.active_job

| Key          | Value                                  |
| ------------ | -------------------------------------- |
| `:adapter`   | QueueAdapter object processing the job |
| `:job`       | Job object                             |


Railties
--------

### load_config_initializer.railties

| Key            | Value                                                 |
| -------------- | ----------------------------------------------------- |
| `:initializer` | Path to loaded initializer from `config/initializers` |

Rails
-----

### deprecation.rails

| Key          | Value                           |
| ------------ | ------------------------------- |
| `:message`   | The deprecation warning         |
| `:callstack` | Where the deprecation came from |

Subscribing to an event
-----------------------

Subscribing to an event is easy. Use `ActiveSupport::Notifications.subscribe` with a block to
listen to any notification.

The block receives the following arguments:

* The name of the event
* Time when it started
* Time when it finished
* A unique ID for this event
* The payload (described in previous sections)

```ruby
ActiveSupport::Notifications.subscribe "process_action.action_controller" do |name, started, finished, unique_id, data|
  # your own custom stuff
  Rails.logger.info "#{name} Received!"
end
```

Defining all those block arguments each time can be tedious. You can easily create an `ActiveSupport::Notifications::Event`
from block arguments like this:

```ruby
ActiveSupport::Notifications.subscribe "process_action.action_controller" do |*args|
  event = ActiveSupport::Notifications::Event.new *args

  event.name      # => "process_action.action_controller"
  event.duration  # => 10 (in milliseconds)
  event.payload   # => {:extra=>information}

  Rails.logger.info "#{event} Received!"
end
```

Most times you only care about the data itself. Here is a shortcut to just get the data.

```ruby
ActiveSupport::Notifications.subscribe "process_action.action_controller" do |*args|
  data = args.extract_options!
  data # { extra: :information }
end
```

You may also subscribe to events matching a regular expression. This enables you to subscribe to
multiple events at once. Here's you could subscribe to everything from `ActionController`.

```ruby
ActiveSupport::Notifications.subscribe /action_controller/ do |*args|
  # inspect all ActionController events
end
```

Creating custom events
----------------------

Adding your own events is easy as well. `ActiveSupport::Notifications` will take care of
all the heavy lifting for you. Simply call `instrument` with a `name`, `payload` and a block.
The notification will be sent after the block returns. `ActiveSupport` will generate the start and end times
as well as the unique ID. All data passed into the `instrument` call will make it into the payload.

Here's an example:

```ruby
ActiveSupport::Notifications.instrument "my.custom.event", this: :data do
  # do your custom stuff here
end
```

Now you can listen to this event with:

```ruby
ActiveSupport::Notifications.subscribe "my.custom.event" do |name, started, finished, unique_id, data|
  puts data.inspect # {:this=>:data}
end
```

You should follow Rails conventions when defining your own events. The format is: `event.library`.
If you application is sending Tweets, you should create an event named `tweet.twitter`.
