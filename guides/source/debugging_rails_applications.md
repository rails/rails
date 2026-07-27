**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Debugging Rails Applications
============================

This guide covers the tools and techniques for debugging Rails applications.

After reading this guide, you will know:

- How Rails' logging machinery works.
- How to use Ruby's `debug` gem.
- The Rails helper methods which aid with debugging.
- How to inject a Ruby console in your view.

--------------------------------------------------------------------------------

Introduction
------------

[Debugging](https://en.wikipedia.org/wiki/Debugging) is the process of finding
the cause, and potential solutions or workarounds to software defects.

There are several strategies that can be used depending on the nature of the
bug. Using a debugger, you can step through the code line-by-line to ensure
statements execute correctly and verify the application's state. Inspecting logs
can show which database queries are made, which views are rendered, and how long
different statements take to execute. If your application is using too much
memory, you can use instrumentation tools to check how your application
allocates memory.

In this guide, we'll discuss some common tools, techniques, and approaches to
debugging.

Debugging Using the Rails Logger
--------------------------------

Writing to the logs is a useful technique to trace the application while it is
running. The most basic way to use logs as a debugging tool is to add `puts`
statements in your code:

```ruby
class Search
  def initialize(params)
    @id = SecureRandom.hex(10)
    @params = params
  end

  def run
    puts "Starting search (#{@id}) at #{Time.zone.now}"
    # ...
    puts "Finshed search (#{@id}) at #{Time.zone.now}"
  end
end
```

`puts` writes statements to [`STDOUT`][] only. It offers no configuration
options to enable or disable certain log statements, or write to multiple
destinations. In a production setting, more control over logging is required. As
such, Rails provides its own logger
([`ActiveSupport::Logger`](https://api.rubyonrails.org/classes/ActiveSupport/Logger.html))
which offers several features to control logging behavior.

Access the Rails logger using `Rails.logger`. In development and test
environments, it writes logs to the file `log/<environment>.log`. In
development, it also writes to `STDOUT`, and in production it writes **ONLY** to
[`STDOUT`][] by default. Log destinations for each environment
[can be configured](#log-destinations).

Here's an example of writing messages using the Rails logger:

```ruby
class Search
  def initialize(params)
    @id = SecureRandom.hex(10)
    @params = params
  end

  def run
    Rails.logger.debug { "Starting search (#{@id}) at #{Time.zone.now}" }
    # ...
    Rails.logger.debug { "Finshed search (#{@id}) at #{Time.zone.now}" }
  end
end
```

In the next sections, we'll dig deeper into the features of the Rails logger.

### Log Levels

Every message logged by the Rails logger must be assigned a _level_. The
available log levels and their corresponding integer values are:

|            |     |
| ---------- | --- |
| `:debug`   | 0   |
| `:info`    | 1   |
| `:warn`    | 2   |
| `:error`   | 3   |
| `:fatal`   | 4   |
| `:unknown` | 5   |

A message is only written to the output if its level is equal to or higher than
the configured log level. `Rails.logger.level` returns the current log level.

The default Rails log level is `:debug` in development and `:info` in
production. You can set the log level for an environment in the application
config:

```ruby
# config/environments/<environment>.rb

config.log_level = :warn
```

Logging has a [small performance overhead](#impact-of-logs-on-performance). Use
log levels to control the verbosity of your logs.

### Logging Messages

To write a log message, call `logger.(debug|info|warn|error|fatal)` method from
anywhere in your app:

```ruby
logger.debug  { "Person attributes: #{@person.attributes.inspect}" }
logger.info   { "Processing the request..." }
logger.fatal  { "Terminating application, raised unrecoverable error!!!" }
```

Where `logger` isn't directly available, such as in a plain Ruby class that
doesn't inherit from any Rails classes (sometimes called a PORO, for **P**lain
**O**ld **R**uby **O**bject), use `Rails.logger`:

```ruby
class Search
  def initialize(params)
    @params = params
  end

  def run
    Rails.logger.info { "Running search with params: #{@params}" }
    # ...
  end
end
```

TIP: Always pass a block to `logger#<level>` instead of a string. This way, the
message will only be evaluated if its log level is active. See the
[Impact of Logs on Performance](#impact-of-logs-on-performance) section for more
information.

Here's an example of a method instrumented with extra logging:

```ruby
class PostsController < ApplicationController
  # ...

  def create
    @post = Post.new(post_params)
    logger.debug { "New post instantiated: #{@post.attributes.inspect}" }

    if @post.save
      logger.debug { "The post was saved, redirecting ..." }
      redirect_to @post, notice: 'Your post was created.'
    else
      logger.debug { "Post invalid: #{@post.errors.full_messages.inspect}" }
      render :new, status: :unprocessable_content
    end
  end

  # ...
end
```

```#4,11
Started POST "/posts" for 127.0.0.1 at 2026-03-30 18:19:42 +0100
Processing by PostsController#create as HTML
  Parameters: {"post" => {"title" => "Debugging Rails", "body" => "Debugging using application logs..."}}
New post instantiated: {"id" => nil, "title" => "Debugging Rails", "body" => "Debugging using application logs...", "created_at" => nil, "updated_at" => nil}
  TRANSACTION (0.2ms)  BEGIN immediate TRANSACTION /*action='create',application='RailsGuidesDemo',controller='posts'*/
  ↳ app/controllers/posts_controller.rb:12:in 'PostsController#create'
  Post Create (2.0ms)  INSERT INTO "posts" ("title", "body", "created_at", "updated_at") VALUES ('Debugging Rails', 'Debugging using application logs...', '2026-03-30 17:19:42.522214', '2026-03-30 17:19:42.522214') RETURNING "id" /*action='create',application='RailsGuidesDemo',controller='posts'*/
  ↳ app/controllers/posts_controller.rb:12:in 'PostsController#create'
  TRANSACTION (0.2ms)  COMMIT TRANSACTION /*action='create',application='RailsGuidesDemo',controller='posts'*/
  ↳ app/controllers/posts_controller.rb:12:in 'PostsController#create'
The post was saved, redirecting ...
Redirected to http://localhost:3000/posts/1
↳ app/controllers/posts_controller.rb:14:in 'PostsController#create'
Completed 302 Found in 10ms (ActiveRecord: 2.4ms (1 query, 0 cached) | GC: 0.0ms)
```

Adding granular logging like this makes it easier to track down unexpected
behavior in your application.

### Log Destinations

Rails can write logs to multiple destinations. This is facilitated using
[`ActiveSupport::BroadcastLogger`][] which wraps one or more loggers (known as
`broadcasts`). When a message is logged, it is propogated to each logger.
`Rails.logger` will return an instance of [`ActiveSupport::BroadcastLogger`][].

```irb
(dev):001> Rails.logger.class
=> ActiveSupport::BroadcastLogger
```

The default logger is an instance of [`ActiveSupport::Logger`][] which
`include`s [`ActiveSupport::TaggedLogging`][] to enable
[stamping log messages with tags](#tagged-logging). This object can be accessed
using `Rails.logger.broadcasts.first`:

```irb
(dev):001> Rails.logger.broadcasts.first.class
=> ActiveSupport::Logger
```

When running the Rails server in development (using `bin/rails server`), an
additional logger which writes to `STDOUT` is also added. This way, logs are
visible in the console, as well as written to the `log/development.log` file.

Invoking the Rails console (using `bin/rails console`) also adds a second logger
which writes to [`STDERR`][]. This ensures log output doesn't interfere with the
REPL (Read-Eval-Print-Loop) which requires control of [`STDIN`][] and
[`STDOUT`][].

NOTE: These secondary loggers are also instances of [`ActiveSupport::Logger`],
but do not `include` [`ActiveSupport::TaggedLogging`][].

[`ActiveSupport::Logger`]:
  https://api.rubyonrails.org/classes/ActiveSupport/Logger.html
[`ActiveSupport::TaggedLogging`]:
  https://api.rubyonrails.org/classes/ActiveSupport/TaggedLogging.html
[`ActiveSupport::BroadcastLogger`]:
  https://api.rubyonrails.org/classes/ActiveSupport/BroadcastLogger.html
[`STDOUT`]:
  https://en.wikipedia.org/wiki/Standard_streams#Standard_output_(stdout)
[`STDIN`]: https://en.wikipedia.org/wiki/Standard_streams#Standard_input_(stdin)
[`STDERR`]:
  https://en.wikipedia.org/wiki/Standard_streams#Standard_error_(stderr)

### Impact of Logs on Performance

Logging has small impact on the performance of your Rails app, particularly when
logging to disk.

The greater the number of strings written to the log, the greater the
performance penalty. Use an appropriate log level in production to ensure a
balance between performance overhead and quantity of logged information.

Always pass a block to the logger, rather than a string.

```ruby
# DO
logger.debug { "Post: #{@post.inspect}" }

# DON'T
logger.debug "Post: #{@post.inspect}"
```

When you pass a string to the logger, Ruby evaluates it regardless of log level.
This means the (somewhat heavy) `String` object has to be instantiated and the
variables interpolated even if the message won't be logged based on the current
level. Blocks, on the other hand, are lazily evaluated only when the current log
level includes the message.

These are micro-optimizations. Performance savings are only noticeable with
large amounts of logging, however, it is recommended as a best-practice.

### Tagged Logging

In complex applications, the ability to filter logs based on certain rules is a
useful tool. The `tagged` method can be used to add _stamps_ to your log
messages, which can then be used for filtering.

```ruby
logger.tagged("BCX").info { "Stuff" }
# "[BCX] Stuff"

logger.tagged("BCX", "Jason").info { "Stuff" }
# "[BCX] [Jason] Stuff"

logger.tagged("BCX") { logger.tagged("Jason").info { "Stuff" } }
# "[BCX] [Jason] Stuff"
```

NOTE: Tags are only added to log messages written to the log file, or to
[`STDOUT`][] in production. They are not visible in the console.

Advanced Logging
----------------

There are a few advanced configuration options and techniques you can use to
maximize the utility of logs when debugging.

### Verbose Query Logs

The `verbose_query_logs` option enables logging of the source location from
where each SQL query is triggered. This is useful to inspect how many SQL
queries a request is triggering, and fix any code triggering excessive queries.

It's enabled by default in development.

```ruby
# config/environments/development.rb

config.active_record.verbose_query_logs = true
```

Consider an example where a `Post` model `belongs_to` an `Author` model. The
below controller and view would generate the following logs when it is rendered:

```ruby
class PostsController < ApplicationController
  def index
    @posts = Post.all
  end
end
```

```html+erb
<h1>Posts</h1>
<ul>
  <%= @posts.each do |post| %>
    <li>
      <hgroup>
        <h2><%= post.title %></h2>
        <p><%= post.author.name %></p>
      </hgroup>
    </li>
  <% end %>
</ul>
```

```#7,9,11,13
Started GET "/posts" for 127.0.0.1 at 2026-03-31 17:01:02 +0100
  ActiveRecord::SchemaMigration Load (0.1ms)  SELECT "schema_migrations"."version" FROM "schema_migrations" ORDER BY "schema_migrations"."version" ASC /*application='RailsGuidesDemo'*/
Processing by PostsController#index as HTML
  Rendering layout layouts/application.html.erb
  Rendering posts/index.html.erb within layouts/application
  Post Load (0.5ms)  SELECT "posts".* FROM "posts" /*action='index',application='RailsGuidesDemo',controller='posts'*/
  ↳ app/views/posts/index.html.erb:4
  Author Load (0.0ms)  SELECT "authors".* FROM "authors" WHERE "authors"."id" = 1 LIMIT 1 /*action='index',application='RailsGuidesDemo',controller='posts'*/
  ↳ app/views/posts/index.html.erb:8
  CACHE Author Load (0.0ms)  SELECT "authors".* FROM "authors" WHERE "authors"."id" = 1 LIMIT 1
  ↳ app/views/posts/index.html.erb:8
  CACHE Author Load (0.0ms)  SELECT "authors".* FROM "authors" WHERE "authors"."id" = 1 LIMIT 1
  ↳ app/views/posts/index.html.erb:8
  Rendered posts/index.html.erb within layouts/application (Duration: 8.5ms | GC: 0.0ms)
  Rendered layout layouts/application.html.erb (Duration: 12.9ms | GC: 0.0ms)
Completed 200 OK in 24ms (Views: 13.0ms | ActiveRecord: 1.2ms (4 queries, 2 cached) | GC: 0.1ms)
```

The highlighted lines above are controlled by the `verbose_query_logs` option.
In this case, it demonstrates an N+1 query and its source file and line. We can
fix it by eager loading the `Author` records: `Post.includes(:author).all`

WARNING: Avoid using this setting in production. It invokes Ruby's
`Kernel#caller` method which tends to allocate a lot of memory in order to
generate stacktraces of method calls. Use [SQL Query Logs](#sql-query-logs)
instead.

### SQL Query Logs

SQL statements can be decorated with a comment containing tags with runtime
information, such as the name of the controller or job that triggered the query.
This can aid with tracing troublesome queries back to their source.

This option is enabled by default in development.

```ruby
# config/environments/development.rb

config.active_record.query_log_tags_enabled = true
```

WARNING: Enabling Query tags automatically disables
[prepared statements](https://en.wikipedia.org/wiki/Prepared_statement) by
default, because each query has a high chance of being unique, making prepared
statements a useless overhead.

Rails logs the name of the application, along with the name and action of the
controller or the name of the job. It is formatted for
[SQLCommenter](https://open-telemetry.github.io/opentelemetry-sqlcommenter/).

```
Post Load (0.5ms)  SELECT "posts".* FROM "posts" /*action='index',application='RailsGuidesDemo',controller='posts'*/
```

The log can be customized using `config.active_record.query_log_tags`. Consult
the
[API documentation](https://api.rubyonrails.org/classes/ActiveRecord/QueryLogs.html)
for details.

### Verbose Enqueue Logs

`verbose_enqueue_logs` is a configuration option for
[Active Job](active_job_basics.html) which logs the source location of the line
which enqueues a job. This option is enabled by default in development.

```ruby
# config/environments/development.rb
config.active_job.verbose_enqueue_logs = true
```

Consider a `Post` model which has a `notify` method that enqueues a
`SendNotificationJob`. The highlighed line below will only be logged with
`verbose_enqueue_logs` enabled:

```#4
(dev):001> Post.first.notify
  Post Load (0.1ms)  SELECT "posts".* FROM "posts" ORDER BY "posts"."id" ASC LIMIT 1 /*application='RailsGuidesDemo'*/
Enqueued SendNotificationJob (Job ID: 586340a5-5186-40ee-b5a3-21d173dced70) to Async(default) with arguments: {source: #<GlobalID:0x000000012ee5e960 @uri=#<URI::GID gid://rails-guides-demo/Post/1>>}
↳ app/models/post.rb:6:in 'Post#notify'
```

WARNING: Avoid using this setting in production. It invokes Ruby's
`Kernel#caller` method which tends to allocate a lot of memory in order to
generate stacktraces of method calls.

### Verbose Redirect Logs

Using the `verbose_redirect_logs` configuration option, you can control whether
the source location of the
[`redirect_to`](https://api.rubyonrails.org/classes/ActionController/Redirecting.html#method-i-redirect_to)
invocation is logged when a request is redirected. It's enabled by default in
development.

```ruby
# config/environments/development.rb
config.action_dispatch.verbose_redirect_logs = true
```

The highlighted line below is only logged when this option is enabled.

```#2
Redirected to http://localhost:3000/posts/1
↳ app/controllers/posts_controller.rb:32:in `block (2 levels) in create'
```

WARNING: Avoid using this setting in production. It invokes Ruby's
`Kernel#caller` method which tends to allocate a lot of memory in order to
generate stacktraces of method calls.

### Custom Loggers

The logger
[can be customized](https://guides.rubyonrails.org/configuring.html#config-logger)
to use another utility such as `Log4r`:

```ruby
# config/environments/production.rb

config.logger = Log4r::Logger.new("Application Log")
```

Using the `debug` Gem
---------------------

A debugger is used to pause program execution, and then manually control further
execution while running commands to inspect the application's state. Ruby's
native debugger is provided by the [`debug`](https://github.com/ruby/debug) gem,
and is installed in Rails apps by default. The gem is not available in the
production environment.

NOTE: `debug` is excluded when using
[alternate Ruby implementations](https://www.ruby-lang.org/en/about/#other-implementations-of-ruby)
such as JRuby or TruffleRuby. It's only included when running CRuby (sometimes
known as MRI).

This section contains a brief overview of key debugger features. Consult
[the documentation](https://github.com/ruby/debug?tab=readme-ov-file) for
detailed usage information.

### Entering the Debugger

Add a breakpoint in your code using `debugger` or one of its aliases:
`binding.break` and `binding.b`.

```ruby#4
class PostsController < ApplicationController
  def index
    @posts = Post.all
    debugger
  end
  # ...
end
```

When the app evaluates the `debugger` statement, execution will pause, and you
can access the debugger in your console:

```
Processing by PostsController#index as HTML
[1, 6] in ~/projects/rails-guides-demo/app/controllers/posts_controller.rb
     1| class PostsController < ApplicationController
     2|   def index
     3|     @posts = Post.all
=>   4|     debugger
     5|   end
     6| end
=>#0  PostsController#index at ~/projects/rails-guides-demo/app/controllers/posts_controller.rb:4
  #1  ActionController::BasicImplicitRender#send_action(method="index", args=[]) at ~/.rbenv/versions/3.4.2/lib/ruby/gems/3.4.0/gems/actionpack-8.1.2/lib/action_controller/metal/basic_implicit_render.rb:8
  # and 78 frames (use `bt' command for all frames)
(rdbg)
```

Within this prompt, you can run debugger commands to inspect the state of your
application. Continue program execution using `continue` (or `c`), or quit the
debugger and terminate your program using `quit` (or `q`).

When inside the debugger, you can run Ruby code just like IRB or the Rails
console.

```
(ruby) @posts
  Post Load (1.7ms)  SELECT "posts".* FROM "posts" /* loading for pp */ LIMIT 11 /*action='index',application='RailsGuidesDemo',controller='posts'*/
  ↳ app/controllers/posts_controller.rb:4:in 'PostsController#index'
[#<Post:0x00000001225d2be0 id: 1 ...>,
 #<Post:0x00000001225d2aa0 id: 2 ...>]
(rdbg) self
#<PostsController:0x00000000006330>
(rdbg)
```

### Debugger Commands

Besides direct evaluation, the debugger supports a plethora of commands to
collect information and control program flow. Some examples are:

- `help` (or `h`) - Show help for all commands.
- `step` (or `s`) - Step into the current line.
- `next` (or `n`) - Resume program until the next line.
- `backtrace` (or `bt`) - Show the backtrace with additional related
  information.
- `break` (or `b`) - List or modify breakpoints.

TIP: When a Ruby expression clashes with a debugger command, evaluate it using
`p` or `eval`. For example, if you had a variable called `step`, you'd evaluate
it by running: `p step`. You can also use `pp` which will _pretty print_ the
output.

#### Control Flow

When inside the debugger, you can control program execution. For example, you
can continue execution for a set number of lines before the program pauses once
again with the interactive debugger prompt.

Some useful commands are:

```shell
# Step into the current line
(rdbg) step

# Continue to the next line
(rdbg) next

# Continue for 5 lines
(rdbg) next 5
```

[The `debug` gem documentation](https://github.com/ruby/debug?tab=readme-ov-file#control-flow)
lists all available control flow commands.

#### `backtrace`

The `backtrace` command lists all the frames on the stack:

```
=>#0  PostsController#index at ~/projects/rails-guides-demo/app/controllers/posts_controller.rb:4
  #1  ActionController::BasicImplicitRender#send_action(method="index", args=[]) at ~/.rbenv/versions/3.4.2/lib/ruby/gems/3.4.0/gems/actionpack-8.1.2/lib/action_controller/metal/basic_implicit_render.rb:8
  #2  AbstractController::Base#process_action at ~/.rbenv/versions/3.4.2/lib/ruby/gems/3.4.0/gems/actionpack-8.1.2/lib/abstract_controller/base.rb:221
  #3  ActionController::Rendering#process_action at ~/.rbenv/versions/3.4.2/lib/ruby/gems/3.4.0/gems/actionpack-8.1.2/lib/action_controller/metal/rendering.rb:199
  #4  block in AbstractController::Callbacks#process_action at ~/.rbenv/versions/3.4.2/lib/ruby/gems/3.4.0/gems/actionpack-8.1.2/lib/abstract_controller/callbacks.rb:267
  #5  block in ActiveSupport::Callbacks#run_callbacks at ~/.rbenv/versions/3.4.2/lib/ruby/gems/3.4.0/gems/activesupport-8.1.2/lib/active_support/callbacks.rb:121
  #6  Turbo.with_request_id(request_id=nil) at ~/.rbenv/versions/3.4.2/lib/ruby/gems/3.4.0/gems/turbo-rails-2.0.23/lib/turbo-rails.rb:24
  ..... and more
```

Every frame includes:

- The frame identifier
- Call location
- Additional information (such as block or method arguments)

While this is useful, there are far too many frames and they're mostly from
within Rails and other libraries. You can specify how many frames are printed
out by supplying a number to `backtrace`:

```shell
(rdbg) backtrace 11
```

A regex can be used to filter frames by its identifier or location:

```shell
(rdbg) backtrace /Posts/
```

```shell
(rdbg) backtrace /actionpack/
```

These options can also be used together:

```shell
(rdbg) backtrace 11 /actionpack/
```

#### `break`

Dynamically add and remove breakpoints while inside the debugger using `break`
(or `b`).

```shell
# List all breakpoints
(rdbg) break

# Set a breakpoint on a specific line of the current file
(rdbg) break 7

# Set a breakpoint on a line in another file
(rdbg) break app/controllers/books_controller.rb:12

# Set a breakpoint on a method in specific class
(rdbg) break BooksController#index
```

NOTE: When setting a breakpoint in another file, you need to specify its
relative path from your project's root. In the development environment,
constants are [lazily auto-loaded](autoloading_and_reloading_constants.html)
when referenced. Hence, a breakpoint in another file that hasn't been loaded yet
will show as `(pending)` until that file is referenced and automatically loaded,
at which point the breakpoint will become active.

Remove breakpoints using `delete` (or `del`):

```shell
# Delete all breakpoints
(rdbg) del

# Delete the breakpoint using its ID
(rdbg) del 21
```

#### `catch`

Add a breakpoint where an exception is raised.

```shell
(rdbg) catch ActiveRecord::RecordInvalid
```

#### `watch`

Add a breakpoint where an instance variable is mutated.

```shell
(rdbg) watch @posts
```

TIP: The debugger supports several more commands, and more options even within
the commands demonstrated. Consult
[the documentation](https://github.com/ruby/debug?tab=readme-ov-file#debug-command-on-the-debug-console)
for a complete manual.

### Program Your Debugging Workflow

The `debugger` statement supports `do:` and `pre:` keywords to add automation to
your debugging workflow.

`do:` pauses the program, runs the supplied value as a debugging command, and
then continues the program. Use this when you want to run a specific debugger
command without stopping the program.

The below example runs `info` and adds a breakpoint when `@posts` is modified,
then continues the program.

```ruby
class PostsController < ApplicationController
  def index
    @posts = Post.all
    debugger(do: "info \n watch @posts")
  end
end
```

`pre:` runs the supplied debugging command and keeps the program suspended so
you can use the interactive console. This is useful for automatically printing
relevant information such as the backtrace when the breakpoint is hit.

```ruby
class PostsController < ApplicationController
  def index
    @posts = Post.all
    debugger(pre: "backtrace 10")
  end
end
```

### Remote Debugging

A Rails server in development might be run alongside other programs such as a
jobs executor, or a CSS/JavaScript watcher (provided by `cssbundling-rails` or
`jsbundling-rails`). This is usually done using
[foreman](https://github.com/ddollar/foreman) via a `Procfile` invoked by
running `bin/dev`.

Debugging a program requires it to be running within a
[terminal](<https://en.wikipedia.org/wiki/Tty_(Unix)>). When foreman is used to
run multiple programs, it forks them as child processes and _pipes_ their input
and output into the parent process. As such the Rails server process isn't
running within a terminal and cannot be used for interactive debugging.

To remedy this, the auto-generated `Procfile.dev` sets the environment variable
`RUBY_DEBUG_OPEN=true` when starting the Rails server to enable _remote
debugging_.

```
$ bin/dev

14:11:34 web.1  | DEBUGGER: Debugger can attach via UNIX domain socket (/var/folders/z2/z6q9dxmd4mb9v_8khdtgsll00000gn/T/rdbg-501/rdbg-24515)
14:11:34 web.1  | DEBUGGER: wait for debugger connection...
```

The debugger now needs to be externally attached to the server process, rather
than run within it. Run `rdbg -a` in a new terminal window to attach the
debugger to your Rails process and start a session.

```
$ rdbg -a
DEBUGGER (client): Connected. PID:24515, $0:bin/rails

[1, 10] in ~/projects/rails-guides-demo/app/controllers/posts_controller.rb
     1| class PostsController < ApplicationController
     2|   def index
     3|     @posts = Post.all
=>   4|     debugger
     5|   end
     6| end
=>#0  PostsController#index at ~/projects/rails-guides-demo/app/controllers/posts_controller.rb:4
  #1  ActionController::BasicImplicitRender#send_action(method="index", args=[]) at ~/.rbenv/versions/3.4.2/lib/ruby/gems/3.4.0/gems/actionpack-8.1.2/lib/action_controller/metal/basic_implicit_render.rb:8
  # and 78 frames (use `bt' command for all frames)
(rdbg:remote)
```

Debugging in the View
---------------------

Sometimes it's useful to dump debug output right into the view, so it can be
inspected in the browser.

### The `debug` helper

The `debug` helper method renders a `<pre>` tag containing a YAML dump of the
supplied object.

For example, the below view code:

```html+erb
<%= debug @post %>

<h1><%= @post.title %></h1>
```

will render the following HTML:

```html
<pre class="debug_dump">
  --- !ruby/object:Post
  concise_attributes:
  - !ruby/object:ActiveModel::Attribute::FromDatabase
    name: id
    value_before_type_cast: 1
  - !ruby/object:ActiveModel::Attribute::FromDatabase
    name: title
    value_before_type_cast: Debugging Rails with View Helpers
  - !ruby/object:ActiveModel::Attribute::FromDatabase
    name: body
    value_before_type_cast: "...";
  - !ruby/object:ActiveModel::Attribute::FromDatabase
    name: created_at
    value_before_type_cast: "2026-03-30 15:04:27.776801";
  - !ruby/object:ActiveModel::Attribute::FromDatabase
    name: updated_at
    value_before_type_cast: "2026-03-30 15:04:27.776801";
  new_record: false
  active_record_yaml_version: 2
</pre>

<h1>Debugging Rails with View Helpers</h1>
```

### `inspect`ing Objects

The
[`inspect`](https://docs.ruby-lang.org/en/master/Object.html#method-i-inspect)
method is available on all Ruby objects except
[`BasicObject`](https://docs.ruby-lang.org/en/master/BasicObject.html). It
provides a human-readable representation of the object, and hence can be useful
to render in a view for debugging.

```html+erb
<%= @post.inspect %>

<h1><%= @post.title></h1>
```

renders:

```
#<Post id: 1, title: "Debugging Rails with View Helpers", body: "...";, created_at: "2026-03-30 15:04:27.776801000 +0000", updated_at: "2026-03-30 15:04:27.776801000 +0000">

<h1>Debugging Rails with View Helpers</h1>
```

NOTE: The `inspect` method can be overridden just like any other method. As
such, its output may differ significantly depending on the object.

### Web-based Ruby Console

The [`web-console`](https://github.com/rails/web-console) gem allows you to
inject an interactive Ruby console within your view. It's installed in Rails
apps for the development environment.

Add a `console` directive in your controller or view.

```ruby
class PostsController < ApplicationController
  def index
    @posts = Post.all
    console
  end
end
```

or

```html+erb
<% console %>

<h1>Posts</h1>
```

Navigate to `/posts` in your browser and you'll see a console at the bottom of
the screen. This is an interative prompt where you can evaluate Ruby expressions
to inspect the current state of your application.

NOTE: Only one console can be rendered per request. `web-console` will raise an
error on a second `console` invocation.

See the gem's
[Readme](https://github.com/rails/web-console?tab=readme-ov-file#web-console-)
for advanced usage and configuration options.

WARNING: Since `web-console` evaluates plain Ruby code remotely on the server,
never use it in production.

Debugging Memory Leaks
----------------------

All Ruby applications can leak memory — either within the Ruby itself or lower
down in C code. This is a broad topic so this guide will not go into detail on
this subject.

A general approach for finding Ruby memory leaks is to use
[rbtrace](https://github.com/tmm1/rbtrace), to extract a heap dump and analyze
it with a heap analyzer.
