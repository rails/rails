**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Debugging Rails Applications
============================

This guide introduces techniques for debugging Ruby on Rails applications.

After reading this guide, you will know:

* The purpose of debugging.
* How to track down problems and issues in your application that your tests aren't identifying.
* The different ways of debugging.
* How to analyze the stack trace.

--------------------------------------------------------------------------------

View Helpers for Debugging
--------------------------

One common task is to inspect the contents of a variable. Rails provides three different ways to do this:

* `debug`
* `to_yaml`
* `inspect`

### `debug`

The `debug` helper will return a \<pre> tag that renders the object using the YAML format. This will generate human-readable data from any object. For example, if you have this code in a view:

```html+erb
<%= debug @article %>
<p>
  <b>Title:</b>
  <%= @article.title %>
</p>
```

You'll see something like this:

```yaml
--- !ruby/object Article
attributes:
  updated_at: 2008-09-05 22:55:47
  body: It's a very helpful guide for debugging your Rails app.
  title: Rails debugging guide
  published: t
  id: "1"
  created_at: 2008-09-05 22:55:47
attributes_cache: {}


Title: Rails debugging guide
```

### `to_yaml`

Alternatively, calling `to_yaml` on any object converts it to YAML. You can pass this converted object into the `simple_format` helper method to format the output. This is how `debug` does its magic.

```html+erb
<%= simple_format @article.to_yaml %>
<p>
  <b>Title:</b>
  <%= @article.title %>
</p>
```

The above code will render something like this:

```yaml
--- !ruby/object Article
attributes:
updated_at: 2008-09-05 22:55:47
body: It's a very helpful guide for debugging your Rails app.
title: Rails debugging guide
published: t
id: "1"
created_at: 2008-09-05 22:55:47
attributes_cache: {}

Title: Rails debugging guide
```

### `inspect`

Another useful method for displaying object values is `inspect`, especially when working with arrays or hashes. This will print the object value as a string. For example:

```html+erb
<%= [1, 2, 3, 4, 5].inspect %>
<p>
  <b>Title:</b>
  <%= @article.title %>
</p>
```

Will render:

```
[1, 2, 3, 4, 5]

Title: Rails debugging guide
```

The Logger
----------

It can also be useful to save information to log files at runtime. Rails maintains a separate log file for each runtime environment.

### What is the Logger?

Rails makes use of the `ActiveSupport::Logger` class to write log information. Other loggers, such as `Log4r`, may also be substituted.

You can specify an alternative logger in `config/application.rb` or any other environment file, for example:

```ruby
config.logger = Logger.new(STDOUT)
config.logger = Log4r::Logger.new("Application Log")
```

Or in the `Initializer` section, add _any_ of the following

```ruby
Rails.logger = Logger.new(STDOUT)
Rails.logger = Log4r::Logger.new("Application Log")
```

TIP: By default, each log is created under `Rails.root/log/` and the log file is named after the environment in which the application is running.

### Log Levels

When something is logged, it's printed into the corresponding log if the log
level of the message is equal to or higher than the configured log level. If you
want to know the current log level, you can call the `Rails.logger.level`
method.

The available log levels are: `:debug`, `:info`, `:warn`, `:error`, `:fatal`,
and `:unknown`, corresponding to the log level numbers from 0 up to 5,
respectively. To change the default log level, use

```ruby
config.log_level = :warn # In any environment initializer, or
Rails.logger.level = 0 # at any time
```

This is useful when you want to log under development or staging without flooding your production log with unnecessary information.

TIP: The default Rails log level is `debug` in all environments.

### Sending Messages

To write in the current log use the `logger.(debug|info|warn|error|fatal|unknown)` method from within a controller, model, or mailer:

```ruby
logger.debug "Person attributes hash: #{@person.attributes.inspect}"
logger.info "Processing the request..."
logger.fatal "Terminating application, raised unrecoverable error!!!"
```

Here's an example of a method instrumented with extra logging:

```ruby
class ArticlesController < ApplicationController
  # ...

  def create
    @article = Article.new(article_params)
    logger.debug "New article: #{@article.attributes.inspect}"
    logger.debug "Article should be valid: #{@article.valid?}"

    if @article.save
      logger.debug "The article was saved and now the user is going to be redirected..."
      redirect_to @article, notice: 'Article was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # ...

  private
    def article_params
      params.require(:article).permit(:title, :body, :published)
    end
end
```

Here's an example of the log generated when this controller action is executed:

```
Started POST "/articles" for 127.0.0.1 at 2018-10-18 20:09:23 -0400
Processing by ArticlesController#create as HTML
  Parameters: {"utf8"=>"✓", "authenticity_token"=>"XLveDrKzF1SwaiNRPTaMtkrsTzedtebPPkmxEFIU0ordLjICSnXsSNfrdMa4ccyBjuGwnnEiQhEoMN6H1Gtz3A==", "article"=>{"title"=>"Debugging Rails", "body"=>"I'm learning how to print in logs.", "published"=>"0"}, "commit"=>"Create Article"}
New article: {"id"=>nil, "title"=>"Debugging Rails", "body"=>"I'm learning how to print in logs.", "published"=>false, "created_at"=>nil, "updated_at"=>nil}
Article should be valid: true
   (0.0ms)  begin transaction
  ↳ app/controllers/articles_controller.rb:31
  Article Create (0.5ms)  INSERT INTO "articles" ("title", "body", "published", "created_at", "updated_at") VALUES (?, ?, ?, ?, ?)  [["title", "Debugging Rails"], ["body", "I'm learning how to print in logs."], ["published", 0], ["created_at", "2018-10-19 00:09:23.216549"], ["updated_at", "2018-10-19 00:09:23.216549"]]
  ↳ app/controllers/articles_controller.rb:31
   (2.3ms)  commit transaction
  ↳ app/controllers/articles_controller.rb:31
The article was saved and now the user is going to be redirected...
Redirected to http://localhost:3000/articles/1
Completed 302 Found in 4ms (ActiveRecord: 0.8ms)
```

Adding extra logging like this makes it easy to search for unexpected or unusual behavior in your logs. If you add extra logging, be sure to make sensible use of log levels to avoid filling your production logs with useless trivia.

### Verbose Query Logs

When looking at database query output in logs, it may not be immediately clear why multiple database queries are triggered when a single method is called:

```
irb(main):001:0> Article.pamplemousse
  Article Load (0.4ms)  SELECT "articles".* FROM "articles"
  Comment Load (0.2ms)  SELECT "comments".* FROM "comments" WHERE "comments"."article_id" = ?  [["article_id", 1]]
  Comment Load (0.1ms)  SELECT "comments".* FROM "comments" WHERE "comments"."article_id" = ?  [["article_id", 2]]
  Comment Load (0.1ms)  SELECT "comments".* FROM "comments" WHERE "comments"."article_id" = ?  [["article_id", 3]]
=> #<Comment id: 2, author: "1", body: "Well, actually...", article_id: 1, created_at: "2018-10-19 00:56:10", updated_at: "2018-10-19 00:56:10">
```

After running `ActiveRecord::Base.verbose_query_logs = true` in the `bin/rails console` session to enable verbose query logs and running the method again, it becomes obvious what single line of code is generating all these discrete database calls:

```
irb(main):003:0> Article.pamplemousse
  Article Load (0.2ms)  SELECT "articles".* FROM "articles"
  ↳ app/models/article.rb:5
  Comment Load (0.1ms)  SELECT "comments".* FROM "comments" WHERE "comments"."article_id" = ?  [["article_id", 1]]
  ↳ app/models/article.rb:6
  Comment Load (0.1ms)  SELECT "comments".* FROM "comments" WHERE "comments"."article_id" = ?  [["article_id", 2]]
  ↳ app/models/article.rb:6
  Comment Load (0.1ms)  SELECT "comments".* FROM "comments" WHERE "comments"."article_id" = ?  [["article_id", 3]]
  ↳ app/models/article.rb:6
=> #<Comment id: 2, author: "1", body: "Well, actually...", article_id: 1, created_at: "2018-10-19 00:56:10", updated_at: "2018-10-19 00:56:10">
```

Below each database statement you can see arrows pointing to the specific source filename (and line number) of the method that resulted in a database call. This can help you identify and address performance problems caused by N+1 queries: single database queries that generates multiple additional queries.

Verbose query logs are enabled by default in the development environment logs after Rails 5.2.

WARNING: We recommend against using this setting in production environments. It relies on Ruby's `Kernel#caller` method which tends to allocate a lot of memory in order to generate stacktraces of method calls.

### Tagged Logging

When running multi-user, multi-account applications, it's often useful
to be able to filter the logs using some custom rules. `TaggedLogging`
in Active Support helps you do exactly that by stamping log lines with subdomains, request ids, and anything else to aid debugging such applications.

```ruby
logger = ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))
logger.tagged("BCX") { logger.info "Stuff" }                            # Logs "[BCX] Stuff"
logger.tagged("BCX", "Jason") { logger.info "Stuff" }                   # Logs "[BCX] [Jason] Stuff"
logger.tagged("BCX") { logger.tagged("Jason") { logger.info "Stuff" } } # Logs "[BCX] [Jason] Stuff"
```

### Impact of Logs on Performance

Logging will always have a small impact on the performance of your Rails app,
particularly when logging to disk. Additionally, there are a few subtleties:

Using the `:debug` level will have a greater performance penalty than `:fatal`,
as a far greater number of strings are being evaluated and written to the
log output (e.g. disk).

Another potential pitfall is too many calls to `Logger` in your code:

```ruby
logger.debug "Person attributes hash: #{@person.attributes.inspect}"
```

In the above example, there will be a performance impact even if the allowed
output level doesn't include debug. The reason is that Ruby has to evaluate
these strings, which includes instantiating the somewhat heavy `String` object
and interpolating the variables.

Therefore, it's recommended to pass blocks to the logger methods, as these are
only evaluated if the output level is the same as — or included in — the allowed level
(i.e. lazy loading). The same code rewritten would be:

```ruby
logger.debug {"Person attributes hash: #{@person.attributes.inspect}"}
```

The contents of the block, and therefore the string interpolation, are only
evaluated if debug is enabled. This performance savings are only really
noticeable with large amounts of logging, but it's a good practice to employ.

INFO: This section was written by [Jon Cairns at a StackOverflow answer](https://stackoverflow.com/questions/16546730/logging-in-rails-is-there-any-performance-hit/16546935#16546935)
and it is licensed under [cc by-sa 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

Debugging with the `debug` gem
------------------------------

When your code is behaving in unexpected ways, you can try printing to logs or
the console to diagnose the problem. Unfortunately, there are times when this
sort of error tracking is not effective in finding the root cause of a problem.
When you actually need to journey into your running source code, the debugger
is your best companion.

The debugger can also help you if you want to learn about the Rails source code
but don't know where to start. Just debug any request to your application and
use this guide to learn how to move from the code you have written into the
underlying Rails code.

Rails 7 includes the `debug` gem in the `Gemfile` of new applications generated
by CRuby. By default, it is ready in the `development` and `test` environments.
Please check its [documentation](https://github.com/ruby/debug) for usage.

Debugging with the `web-console` gem
------------------------------------

Web Console is a bit like `debug`, but it runs in the browser. In any page you
are developing, you can request a console in the context of a view or a
controller. The console would be rendered next to your HTML content.

### Console

Inside any controller action or view, you can invoke the console by
calling the `console` method.

For example, in a controller:

```ruby
class PostsController < ApplicationController
  def new
    console
    @post = Post.new
  end
end
```

Or in a view:

```html+erb
<% console %>

<h2>New Post</h2>
```

This will render a console inside your view. You don't need to care about the
location of the `console` call; it won't be rendered on the spot of its
invocation but next to your HTML content.

The console executes pure Ruby code: You can define and instantiate
custom classes, create new models, and inspect variables.

NOTE: Only one console can be rendered per request. Otherwise `web-console`
will raise an error on the second `console` invocation.

### Inspecting Variables

You can invoke `instance_variables` to list all the instance variables
available in your context. If you want to list all the local variables, you can
do that with `local_variables`.

### Settings

* `config.web_console.allowed_ips`: Authorized list of IPv4 or IPv6
addresses and networks (defaults: `127.0.0.1/8, ::1`).
* `config.web_console.whiny_requests`: Log a message when a console rendering
is prevented (defaults: `true`).

Since `web-console` evaluates plain Ruby code remotely on the server, don't try
to use it in production.

Debugging Memory Leaks
----------------------

A Ruby application (on Rails or not), can leak memory — either in the Ruby code
or at the C code level.

In this section, you will learn how to find and fix such leaks by using tools
such as Valgrind.

### Valgrind

[Valgrind](http://valgrind.org/) is an application for detecting C-based memory
leaks and race conditions.

There are Valgrind tools that can automatically detect many memory management
and threading bugs, and profile your programs in detail. For example, if a C
extension in the interpreter calls `malloc()` but doesn't properly call
`free()`, this memory won't be available until the app terminates.

For further information on how to install Valgrind and use with Ruby, refer to
[Valgrind and Ruby](https://blog.evanweaver.com/2008/02/05/valgrind-and-ruby/)
by Evan Weaver.

### Find a Memory Leak

There is an excellent article about detecting and fixing memory leaks at Derailed, [which you can read here](https://github.com/schneems/derailed_benchmarks#is-my-app-leaking-memory).


Plugins for Debugging
---------------------

There are some Rails plugins to help you to find errors and debug your
application. Here is a list of useful plugins for debugging:

* [Query Trace](https://github.com/ruckus/active-record-query-trace/tree/master) Adds query
origin tracing to your logs.
* [Exception Notifier](https://github.com/smartinez87/exception_notification/tree/master)
Provides a mailer object and a default set of templates for sending email
notifications when errors occur in a Rails application.
* [Better Errors](https://github.com/charliesome/better_errors) Replaces the
standard Rails error page with a new one containing more contextual information,
like source code and variable inspection.
* [RailsPanel](https://github.com/dejan/rails_panel) Chrome extension for Rails
development that will end your tailing of development.log. Have all information
about your Rails app requests in the browser — in the Developer Tools panel.
Provides insight to db/rendering/total times, parameter list, rendered views and
more.
* [Pry](https://github.com/pry/pry) An IRB alternative and runtime developer console.

References
----------

* [web-console Homepage](https://github.com/rails/web-console)
