Rails on Rack
=============

This guide covers Rails integration with Rack and interfacing with other Rack components. By referring to this guide, you will be able to:

* Create Rails Metal applications
* Use Rack Middlewares in your Rails applications
* Understand Action Pack's internal Middleware stack
* Define a custom Middleware stack

--------------------------------------------------------------------------------

WARNING: This guide assumes a working knowledge of Rack protocol and Rack concepts such as middlewares, url maps and `Rack::Builder`.

Introduction to Rack
--------------------

bq. Rack provides a minimal, modular and adaptable interface for developing web applications in Ruby. By wrapping HTTP requests and responses in the simplest way possible, it unifies and distills the API for web servers, web frameworks, and software in between (the so-called middleware) into a single method call.

- [Rack API Documentation](http://rack.rubyforge.org/doc/)

Explaining Rack is not really in the scope of this guide. In case you are not familiar with Rack's basics, you should check out the [Resources](#resources) section below.

Rails on Rack
-------------

### Rails Application's Rack Object

`ApplicationName::Application` is the primary Rack application object of a Rails application. Any Rack compliant web server should be using `ApplicationName::Application` object to serve a Rails application.

### `rails server`

`rails server` does the basic job of creating a `Rack::Server` object and starting the webserver.

Here's how `rails server` creates an instance of `Rack::Server`

```ruby
Rails::Server.new.tap { |server|
  require APP_PATH
  Dir.chdir(Rails.application.root)
  server.start
}
```

The `Rails::Server` inherits from `Rack::Server` and calls the `Rack::Server#start` method this way:

```ruby
class Server < ::Rack::Server
  def start
    ...
    super
  end
end
```

Here's how it loads the middlewares:

```ruby
def middleware
  middlewares = []
  middlewares << [Rails::Rack::Debugger]  if options[:debugger]
  middlewares << [::Rack::ContentLength]
  Hash.new(middlewares)
end
```

`Rails::Rack::Debugger` is primarily useful only in the development environment. The following table explains the usage of the loaded middlewares:

| Middleware              | Purpose                                                                           |
| ----------------------- | --------------------------------------------------------------------------------- |
| `Rails::Rack::Debugger` | Starts Debugger                                                                   |
| `Rack::ContentLength`   | Counts the number of bytes in the response and set the HTTP Content-Length header |

### `rackup`

To use `rackup` instead of Rails' `rails server`, you can put the following inside `config.ru` of your Rails application's root directory:

```ruby
# Rails.root/config.ru
require "config/environment"

use Rack::Debugger
use Rack::ContentLength
run ApplicationName::Application
```

And start the server:

```bash
$ rackup config.ru
```

To find out more about different `rackup` options:

```bash
$ rackup --help
```

Action Dispatcher Middleware Stack
----------------------------------

Many of Action Dispatchers's internal components are implemented as Rack middlewares. `Rails::Application` uses `ActionDispatch::MiddlewareStack` to combine various internal and external middlewares to form a complete Rails Rack application.

NOTE: `ActionDispatch::MiddlewareStack` is Rails' equivalent of `Rack::Builder`, but built for better flexibility and more features to meet Rails' requirements.

### Inspecting Middleware Stack

Rails has a handy rake task for inspecting the middleware stack in use:

```bash
$ rake middleware
```

For a freshly generated Rails application, this might produce something like:

```ruby
use ActionDispatch::Static
use Rack::Lock
use #<ActiveSupport::Cache::Strategy::LocalCache::Middleware:0x000000029a0838>
use Rack::Runtime
use Rack::MethodOverride
use ActionDispatch::RequestId
use Rails::Rack::Logger
use ActionDispatch::ShowExceptions
use ActionDispatch::DebugExceptions
use ActionDispatch::RemoteIp
use ActionDispatch::Reloader
use ActionDispatch::Callbacks
use ActiveRecord::ConnectionAdapters::ConnectionManagement
use ActiveRecord::QueryCache
use ActionDispatch::Cookies
use ActionDispatch::Session::CookieStore
use ActionDispatch::Flash
use ActionDispatch::ParamsParser
use ActionDispatch::Head
use Rack::ConditionalGet
use Rack::ETag
use ActionDispatch::BestStandardsSupport
run ApplicationName::Application.routes
```

Purpose of each of this middlewares is explained in the [Internal Middlewares](#internal-middleware-stack) section.

### Configuring Middleware Stack

Rails provides a simple configuration interface `config.middleware` for adding, removing and modifying the middlewares in the middleware stack via `application.rb` or the environment specific configuration file `environments/<environment>.rb`.

#### Adding a Middleware

You can add a new middleware to the middleware stack using any of the following methods:

* `config.middleware.use(new_middleware, args)` - Adds the new middleware at the bottom of the middleware stack.

* `config.middleware.insert_before(existing_middleware, new_middleware, args)` - Adds the new middleware before the specified existing middleware in the middleware stack.

* `config.middleware.insert_after(existing_middleware, new_middleware, args)` - Adds the new middleware after the specified existing middleware in the middleware stack.

```ruby
# config/application.rb

# Push Rack::BounceFavicon at the bottom
config.middleware.use Rack::BounceFavicon

# Add Lifo::Cache after ActiveRecord::QueryCache.
# Pass { page_cache: false } argument to Lifo::Cache.
config.middleware.insert_after ActiveRecord::QueryCache, Lifo::Cache, page_cache: false
```

#### Swapping a Middleware

You can swap an existing middleware in the middleware stack using `config.middleware.swap`.

```ruby
# config/application.rb

# Replace ActionDispatch::ShowExceptions with Lifo::ShowExceptions
config.middleware.swap ActionDispatch::ShowExceptions, Lifo::ShowExceptions
```

#### Middleware Stack is an Enumerable

The middleware stack behaves just like a normal `Enumerable`. You can use any `Enumerable` methods to manipulate or interrogate the stack. The middleware stack also implements some `Array` methods including `[]`, `unshift` and `delete`. Methods described in the section above are just convenience methods.

Append following lines to your application configuration:

```ruby
# config/application.rb
config.middleware.delete "Rack::Lock"
```

And now if you inspect the middleware stack, you'll find that `Rack::Lock` will not be part of it.

```bash
$ rake middleware
(in /Users/lifo/Rails/blog)
use ActionDispatch::Static
use #<ActiveSupport::Cache::Strategy::LocalCache::Middleware:0x00000001c304c8>
use Rack::Runtime
...
run Blog::Application.routes
```

If you want to remove session related middleware, do the following:

```ruby
# config/application.rb
config.middleware.delete "ActionDispatch::Cookies"
config.middleware.delete "ActionDispatch::Session::CookieStore"
config.middleware.delete "ActionDispatch::Flash"
```

And to remove browser related middleware,

```ruby
# config/application.rb
config.middleware.delete "ActionDispatch::BestStandardsSupport"
config.middleware.delete "Rack::MethodOverride"
```

### Internal Middleware Stack

Much of Action Controller's functionality is implemented as Middlewares. The following list explains the purpose of each of them:

 **`ActionDispatch::Static`**

* Used to serve static assets. Disabled if `config.serve_static_assets` is true.

 **`Rack::Lock`**

* Sets `env["rack.multithread"]` flag to `true` and wraps the application within a Mutex.

 **`ActiveSupport::Cache::Strategy::LocalCache::Middleware`**

* Used for memory caching. This cache is not thread safe.

 **`Rack::Runtime`**

* Sets an X-Runtime header, containing the time (in seconds) taken to execute the request.

 **`Rack::MethodOverride`**

* Allows the method to be overridden if `params[:_method]` is set. This is the middleware which supports the PUT and DELETE HTTP method types.

 **`ActionDispatch::RequestId`**

* Makes a unique `X-Request-Id` header available to the response and enables the `ActionDispatch::Request#uuid` method.

 **`Rails::Rack::Logger`**

* Notifies the logs that the request has began. After request is complete, flushes all the logs.

 **`ActionDispatch::ShowExceptions`**

* Rescues any exception returned by the application and calls an exceptions app that will wrap it in a format for the end user.

 **`ActionDispatch::DebugExceptions`**

* Responsible for logging exceptions and showing a debugging page in case the request is local.

 **`ActionDispatch::RemoteIp`**

* Checks for IP spoofing attacks.

 **`ActionDispatch::Reloader`**

* Provides prepare and cleanup callbacks, intended to assist with code reloading during development.

 **`ActionDispatch::Callbacks`**

* Runs the prepare callbacks before serving the request.

 **`ActiveRecord::ConnectionAdapters::ConnectionManagement`**

* Cleans active connections after each request, unless the `rack.test` key in the request environment is set to `true`.

 **`ActiveRecord::QueryCache`**

* Enables the Active Record query cache.

 **`ActionDispatch::Cookies`**

* Sets cookies for the request.

 **`ActionDispatch::Session::CookieStore`**

* Responsible for storing the session in cookies.

 **`ActionDispatch::Flash`**

* Sets up the flash keys. Only available if `config.action_controller.session_store` is set to a value.

 **`ActionDispatch::ParamsParser`**

* Parses out parameters from the request into `params`.

 **`ActionDispatch::Head`**

* Converts HEAD requests to `GET` requests and serves them as so.

 **`Rack::ConditionalGet`**

* Adds support for "Conditional `GET`" so that server responds with nothing if page wasn't changed.

 **`Rack::ETag`**

* Adds ETag header on all String bodies. ETags are used to validate cache.

 **`ActionDispatch::BestStandardsSupport`**

* Enables “best standards support” so that IE8 renders some elements correctly.

TIP: It's possible to use any of the above middlewares in your custom Rack stack.

### Using Rack Builder

The following shows how to replace use `Rack::Builder` instead of the Rails supplied `MiddlewareStack`.

<strong>Clear the existing Rails middleware stack</strong>

```ruby
# config/application.rb
config.middleware.clear
```

<br />
<strong>Add a `config.ru` file to `Rails.root`</strong>

```ruby
# config.ru
use MyOwnStackFromScratch
run ApplicationName::Application
```

Resources
---------

### Learning Rack

* [Official Rack Website](http://rack.github.com)
* [Introducing Rack](http://chneukirchen.org/blog/archive/2007/02/introducing-rack.html)
* [Ruby on Rack #1 - Hello Rack!](http://m.onkey.org/ruby-on-rack-1-hello-rack)
* [Ruby on Rack #2 - The Builder](http://m.onkey.org/ruby-on-rack-2-the-builder)

### Understanding Middlewares

* [Railscast on Rack Middlewares](http://railscasts.com/episodes/151-rack-middleware)
