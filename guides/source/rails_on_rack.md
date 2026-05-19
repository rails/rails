**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Rails on Rack
=============

This guide covers Rails' integration with [Rack](https://en.wikipedia.org/wiki/Rack_(web_server_interface)). After reading this guide, you will know:

* What Rack is and why Rails uses it.
* How Rails uses Rack middleware to build an application stack.
* Action Pack's internal middleware stack.
* How to configure and change the middleware stack.
* The underlying Rack API exposed by Rails controllers.

--------------------------------------------------------------------------------

Introduction to Rack
--------------------

Rack provides a modular interface for developing web applications in Ruby. By wrapping HTTP requests and responses using a conventional structure, it unifies the API for web servers, web frameworks, and software in between (known as middleware) into a single method call.

This allows Rack compliant web servers like [Puma](https://puma.io) or [Falcon](https://socketry.github.io/falcon/) to be interchangeably used with any Rack based web framework such as Rails.

Before diving into how Rails integrates with Rack, let's look at Rack itself.

### A Basic Rack Application

A Rack app is an object which implements a `call` method. It is passed an [`env`](https://github.com/rack/rack/blob/main/SPEC.rdoc#the-request-environment) hash, known as the Rack environment.

Here's an example of a barebones Rack app:

```ruby
class App
  def call(env)
    [200, { "content-type" => "text/plain" }, ["Hello World"]]
  end
end

run App.new
```

When an HTTP request is made, the Rack-compliant web server parses it to create the `env` hash, and calls the application with `env`. The `call` method must return an array with exactly three elements, representing the HTTP response:

1. The HTTP response code (`200` in the above example).
2. A hash containing any HTTP response headers we wish to send.
3. An enumerable object that yields strings, representing the response body.

Rack applications are generally run using the web server's command line program, with the entry point for the application being stored in a `config.ru` file:

```bash
$ cat > config.ru << APP
rack_app = lambda do |env|
  [200, { "content-type" => "text/plain" }, ["Hello World"]]
end
run rack_app
APP
$ gem install puma
$ puma
```

Your app should be available at <http://localhost:9292>.

```bash
$ curl localhost:9292
Hello World
```

### Rack Middleware

Rack applications can be wrapped using _middleware_ which may operate upon a request before it reaches the main application, and again after the application has returned a response to the request. Middleware is usually used for tasks like logging, caching, authentication, and measuring performance.

A Rack middleware must have a `new` method that accepts the Rack app and any arguments used to configure the middleware. The `new` method must return a Rack application that responds to `call`. Typically, Rack middleware are classes, and each instance of the middleware wraps access to the related application:

```ruby
class MyMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    # Operations before the request hits the main application
    # -------------------------------------------------------

    # Propgate the request down the middleware stack
    status, headers, body = @app.call(env)

    # ---------------------------------------
    # Operations after the request comes back

    # Propogate the response up the middleware stack
    [status, headers, body]
  end
end
```

Middleware can short-circuit the stack by skipping `@app.call` completely and returning a reponse by itself. This means the request never hits the main application or the remaining middleware in the stack. A middleware to authenticate a request might use this technique.

```ruby
class AuthenticateRequest
  def initialize(app)
    @app = app
  end

  def call(env)
    if authenticated?(env["HTTP_AUTHORIZATION"])
      @app.call(env)
    else
      [401, { "content-type" => "text/plain" }, ["Authentication failed"]]
    end
  end

  def authenticated?(token)
    # ...
  end
end
```

Middleware is added to a Rack app with `use`:

```ruby
class AuthenticateRequest
  # ...
end

class App
  def call(env)
    [200, { "content-type" => "text/plain" }, ["Hello World"]]
  end
end

use AuthenticateRequest
run App.new
```

This DSL to construct Rack applications is provided by [`Rack::Builder`][]. For further information about Rack, consult the [Rack specification](https://rack.github.io/rack/main/SPEC_rdoc.html) and [Rack Website](https://rack.github.io/rack/).

[`Rack::Builder`]: https://rack.github.io/rack/3.2/Rack/Builder.html

Rails on Rack
-------------

### The Primary Rack Object

`Rails.application` is the *primary Rack application object* of a Rails
application. A Rack compliant web server should use the `Rails.application` object to serve a Rails application.

### Starting the Rails Server

Rails subclasses `Rackup::Server` to create `Rails::Server`. `bin/rails server` instantiates a `Rails::Server` object and starts the web server.

```ruby
Rails::Server.new.tap do |server|
  require APP_PATH
  Dir.chdir(Rails.application.root)
  server.start
end
```

See the [initialization guide](initialization.html#rails-server-start) for further information on how the server starts up.


Action Dispatch Middleware Stack
--------------------------------

`ActionDispatch::MiddlewareStack` is Rails' equivalent of [`Rack::Builder`][]. It's built with more flexibility and features to meet Rails' requirements.

`Rails::Application` uses `ActionDispatch::MiddlewareStack` to combine internal and external middleware to build the stack which forms a complete Rack application using Rails.

### Inspecting the Middleware Stack

View the middleware stack by running:

```bash
$ bin/rails middleware
```

Here's an example from a freshly generated Rails app:

```ruby
use ActionDispatch::HostAuthorization
use Rack::Sendfile
use ActionDispatch::Static
use Propshaft::Server
use ActionDispatch::Executor
use ActionDispatch::ServerTiming
use ActiveSupport::Cache::Strategy::LocalCache::Middleware
use Rack::Runtime
use Rack::MethodOverride
use ActionDispatch::RequestId
use ActionDispatch::RemoteIp
use Propshaft::QuietAssets
use Rails::Rack::Logger
use ActionDispatch::ShowExceptions
use WebConsole::Middleware
use ActionDispatch::DebugExceptions
use ActionDispatch::ActionableExceptions
use ActionDispatch::Reloader
use ActionDispatch::Callbacks
use ActiveRecord::Migration::CheckPending
use ActionDispatch::Cookies
use ActionDispatch::Session::CookieStore
use ActionDispatch::Flash
use ActionDispatch::ContentSecurityPolicy::Middleware
use Rack::Head
use Rack::ConditionalGet
use Rack::ETag
use Rack::TempfileReaper
run MyApp::Application.routes
```

The [Internal Middleware Stack](#internal-middleware-stack) section below summarizes the default middleware components depicted above.

### Configuring the Middleware Stack

Rails provides a configuration interface [`config.middleware`](https://api.rubyonrails.org/classes/Rails/Configuration/MiddlewareStackProxy.html) for adding, removing, and modifying the middleware stack via `application.rb` or the environment specific configuration file `environments/<environment>.rb`.

[`config.middleware`]: configuring.html#config-middleware

#### Adding Middleware

There are three methods to add new middleware to the stack.

* `config.middleware.use(new_middleware, args)`: Adds the new middleware at the bottom of the middleware stack.

* `config.middleware.insert_before(existing_middleware, new_middleware, args)`: Adds the new middleware before the specified existing middleware in the middleware stack.

* `config.middleware.insert_after(existing_middleware, new_middleware, args)`: Adds the new middleware after the specified existing middleware in the middleware stack.

Example usage:

```ruby
# config/application.rb

# Push `Rack::BounceFavicon` at the bottom
config.middleware.use Rack::BounceFavicon

# Add `Lifo::Cache` after `ActionDispatch::Executor`.
# Pass { page_cache: false } argument to Lifo::Cache.
config.middleware.insert_after ActionDispatch::Executor, Lifo::Cache, page_cache: false
```

#### Swapping Middleware

Swap middleware using `config.middleware.swap`.

```ruby
# config/application.rb

# Replace `ActionDispatch::ShowExceptions` with `Lifo::ShowExceptions`
config.middleware.swap ActionDispatch::ShowExceptions, Lifo::ShowExceptions
```

#### Moving Middleware

Move existing middleware components in the stack using `config.middleware.move_before` or `config.middleware.move_after`.

```ruby
# config/application.rb

# Move ActionDispatch::ShowExceptions to before Lifo::ShowExceptions
config.middleware.move_before Lifo::ShowExceptions, ActionDispatch::ShowExceptions
```

```ruby
# config/application.rb

# Move ActionDispatch::ShowExceptions to after Lifo::ShowExceptions
config.middleware.move_after Lifo::ShowExceptions, ActionDispatch::ShowExceptions
```

#### Deleting Middleware

Delete middleware using `config.middleware.delete`.

```ruby
# config/application.rb
config.middleware.delete Rack::Runtime
```

Using `delete!` will raise an error if the middleware component doesn't exist.

```ruby
# config/application.rb

config.middleware.delete! Some::NonExistentMiddleware
```

### Reloading the Middleware Stack

The middleware stack is loaded once and isn't monitored for changes. Restart your server after making changes to your middleware stack.

### Internal Middleware Stack

Much of Action Controller's functionality is implemented as middleware. The following list explains the purpose of each of them:

#### `ActionDispatch::ActionableExceptions`

[`ActionDispatch::ActionableExceptions`][] provides a way to dispatch actions from Rails' error pages if the request is local.

[`ActionDispatch::ActionableExceptions`]: https://api.rubyonrails.org/files/actionpack/lib/action_dispatch/middleware/actionable_exceptions_rb.html

#### `ActionDispatch::Callbacks`

[`ActionDispatch::Callbacks`][] provides callbacks to be executed before and after dispatching the request.

[`ActionDispatch::Callbacks`]: https://api.rubyonrails.org/classes/ActionDispatch/Callbacks.html

#### `ActionDispatch::ContentSecurityPolicy::Middleware`

[`ActionDispatch::ContentSecurityPolicy::Middleware`][] provides a DSL to configure a `Content-Security-Policy` header. See [Securing Rails Applications](security.html#content-security-policy-header) for further information.

[`ActionDispatch::ContentSecurityPolicy::Middleware`]: https://api.rubyonrails.org/classes/ActionDispatch/ContentSecurityPolicy/Middleware.html

#### `ActionDispatch::Cookies`

[`ActionDispatch::Cookies`][] reads cookie data from the request and writes cookie data on the response.

[`ActionDispatch::Cookies`]: https://api.rubyonrails.org/classes/ActionDispatch/Cookies.html

#### `ActionDispatch::DebugExceptions`

[`ActionDispatch::DebugExceptions`][] is responsible for logging exceptions and showing a debugging page if the request is local.

[`ActionDispatch::DebugExceptions`]: https://api.rubyonrails.org/classes/ActionDispatch/DebugExceptions.html

#### `ActionDispatch::Executor`

[`ActionDispatch::Executor`][] ensures thread safe code reloading during development.

[`ActionDispatch::Executor`]: https://api.rubyonrails.org/classes/ActionDispatch/Executor.html

#### `ActionDispatch::Flash`

[`ActionDispatch::Flash`][] sets up the flash keys. Only available if [`config.session_store`][] is set to a value.

[`ActionDispatch::Flash`]: https://api.rubyonrails.org/classes/ActionDispatch/Flash.html
[`config.session_store`]: configuring.html#config-session-store

#### `ActionDispatch::HostAuthorization`

[`ActionDispatch::HostAuthorization`][] prevents DNS rebinding attacks by restricting the hosts to which a request can be sent. See the [configuration guide](configuring.html#actiondispatch-hostauthorization) for configuration instructions.

[`ActionDispatch::HostAuthorization`]: https://api.rubyonrails.org/classes/ActionDispatch/HostAuthorization.html

#### `ActionDispatch::Reloader`

[`ActionDispatch::Reloader`][] provides prepare and cleanup callbacks, intended to assist with code reloading during development.

[`ActionDispatch::Reloader`]: https://api.rubyonrails.org/classes/ActionDispatch/Reloader.html

#### `ActionDispatch::RemoteIp`

[`ActionDispatch::RemoteIp`][] checks for IP spoofing attacks.

[`ActionDispatch::RemoteIp`]: https://api.rubyonrails.org/classes/ActionDispatch/RemoteIp.html

#### `ActionDispatch::RequestId`

[`ActionDispatch::RequestId`][] makes a unique `X-Request-Id` header available to the request and enables the `ActionDispatch::Request#request_id` method.

The unique request id can be used to trace a request end-to-end and would typically end up being part of log files from multiple pieces of the stack.

[`ActionDispatch::RequestId`]: https://api.rubyonrails.org/classes/ActionDispatch/RequestId.html

#### `ActionDispatch::ServerTiming`

[`ActionDispatch::ServerTiming`][] sets a [`Server-Timing`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Server-Timing) header containing performance metrics for the request.

[`ActionDispatch::ServerTiming`]: https://api.rubyonrails.org/classes/ActionDispatch/ServerTiming.html

#### `ActionDispatch::Session::CookieStore`

[`ActionDispatch::Session::CookieStore`][] is responsible for storing the session in cookies.

[`ActionDispatch::Session::CookieStore`]: https://api.rubyonrails.org/classes/ActionDispatch/Session/CookieStore.html

#### `ActionDispatch::ShowExceptions`

[`ActionDispatch::ShowExceptions`][] rescues any exception returned by the application and calls an exceptions app that will wrap it in a format for the end user.

[`ActionDispatch::ShowExceptions`]: https://api.rubyonrails.org/classes/ActionDispatch/ShowExceptions.html

#### `ActionDispatch::Static`

[`ActionDispatch::Static`][] serves static files from the `public` folder. Disabled when [`config.public_file_server.enabled`][] is `false`.

[`ActionDispatch::Static`]: https://api.rubyonrails.org/classes/ActionDispatch/Static.html
[`config.public_file_server.enabled`]: configuring.html#config-public-file-server-enabled

#### `ActiveRecord::Migration::CheckPending`

[`ActiveRecord::Migration::CheckPending`][] checks pending migrations and raises `ActiveRecord::PendingMigrationError` if any migrations are pending if [`config.action_dispatch.x_sendfile_header`][] is set to `:page_load`.

[`config.action_dispatch.x_sendfile_header`]: configuring.html#config-action-record-migration-error

[`ActiveRecord::Migration::CheckPending`]: https://api.rubyonrails.org/classes/ActiveRecord/Migration/CheckPending.html

#### `ActiveSupport::Cache::Strategy::LocalCache::Middleware`

[`ActiveSupport::Cache::Strategy::LocalCache::Middleware`][] is the middleware for the in-memory local cache. This cache is not thread safe and is intended only for serving as a temporary memory cache for a single thread.

[`ActiveSupport::Cache::Strategy::LocalCache::Middleware`]: https://api.rubyonrails.org/classes/ActiveSupport/Cache/Strategy/LocalCache.html

#### `Propshaft::QuietAssets`

[`Propshaft::QuietAssets`][] suppresses logger output for asset requests.

[`Propshaft::QuietAssets`]: https://github.com/rails/propshaft/blob/main/lib/propshaft/quiet_assets.rb

#### `Rack::ConditionalGet`

[`Rack::ConditionalGet`][] enables "Conditional `GET`" requests using if-none-match and if-modified-since. If the requested page wasn't changed returns a 304 Not Modified and an empty body.

[`Rack::ConditionalGet`]: https://rack.github.io/rack/3.2/Rack/ConditionalGet.html

#### `Rack::ETag`

[`Rack::ETag`][] adds an `ETag` header on all String bodies. ETags are used to validate the cache to faciliate "Conditional `GET`" requests as described above. See the [Caching with Rails](caching_with_rails.html#conditional-get-support) for further information.

[`Rack::ETag`]: https://rack.github.io/rack/3.2/Rack/ETag.html

#### `Rack::Head`

[`Rack::Head`][] returns an empty body for all `HEAD` requests. It leaves all other requests unchanged.

[`Rack::Head`]: https://rack.github.io/rack/3.2/Rack/Head.html

#### `Rack::Lock`

[`Rack::Lock`][] locks every request inside a mutex, so that every request will effectively be executed synchronously.

[`Rack::Lock`]: https://rack.github.io/rack/3.2/Rack/Lock.html

#### `Rack::MethodOverride`

[`Rack::MethodOverride`][] allows the method to be overridden if `params[:_method]` is set. This is how Rails supports `PUT`, `PATCH`, and `DELETE` HTTP methods since they are not browser native.

[`Rack::MethodOverride`]: https://rack.github.io/rack/3.2/Rack/MethodOverride.html

#### `Rack::Runtime`

[`Rack::Runtime`][] sets an `X-Runtime` header, containing the time (in seconds) taken to execute the request.

[`Rack::Runtime`]: https://rack.github.io/rack/3.2/Rack/Runtime.html

#### `Rack::Sendfile`

[`Rack::Sendfile`] sets a server specific `X-Sendfile` header. This is useful for accelerated file sending if you use a reverse proxy server like Apache or Nginx. For example it can be set to 'X-Sendfile' for Apache. Configure this via [`config.action_dispatch.x_sendfile_header`][] option.

[`Rack::Sendfile`]: https://rack.github.io/rack/3.2/Rack/Sendfile.html
[`config.action_dispatch.x_sendfile_header`]: configuring.html#config-action-dispatch-x-sendfile-header

#### `Rack::TempfileReaper`

[`Rack::TempfileReaper`][] cleans up tempfiles used to buffer multipart requests.

[`Rack::TempfileReaper`]: https://rack.github.io/rack/3.2/Rack/TempfileReaper.html

#### `Rails::Rack::Logger`

[`Rails::Rack::Logger`][] notifies the logs that the request has begun. After the request is complete, flushes all the logs.

[`Rails::Rack::Logger`]: https://api.rubyonrails.org/classes/Rails/Rack/Logger.html

TIP: You can use any of the above middleware in a custom Rack stack.

Custom Middleware
-----------------

You can create your own middleware and include it in your Rails app.

### Creating Middleware

Custom middleware files should be placed in the `lib/` folder and `require`d manually since middleware is not auto-reloaded.

The below example reads the `locale` value from the URL params and stores it in the Rack `env`. It then deletes it from the query parameters so it isn't included in the `params` hash keeping it decluttered when the request hits the controller.

```ruby
# lib/middleware/extract_locale.rb

module RackMiddleware
  class ExtractLocale
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      if request.params["locale"].present?
        env["myapp.locale"] = env["action_dispatch.request.query_parameters"]["locale"]

        env["action_dispatch.request.query_parameters"].delete("locale")
        env["action_dispatch.request.parameters"].delete("locale")
      end

      @app.call(env)
    end
  end
end
```

Rails doesn't create the `lib/middleware/` folder by default, so you'll need to create it yourself. Excluding it from the autoload path is recommended to prevent auto-loading issues.

```ruby#7
# config/application.rb

module MyApp
  class Application < Rails::Application
    # ...

    config.autoload_lib(ignore: %w[assets tasks middleware])

    # ...
  end
end
```

### Adding Custom Middleware to the Stack

Custom middleware can be added in `application.rb`

```ruby
# config/application.rb

# ...

require_relative "../lib/middleware/extract_locale"

module MyApp
  class Application < Rails::Application
    # ...

    config.middleware.use RackMiddleware::ExtractLocale

    # ...
  end
end
```

or within a standalone initializer.

```ruby
# config/initializers/extract_locale.rb

require "#{Rails.root.join("lib", "middleware", "extract_locale")}"

Rails.application.config.middleware.use RackMiddleware::ExtractLocale
```

Accessing Rack Internals in Rails
---------------------------------

The underlying Rack API can be used within Rails controllers.

### Accessing the Rack `env`

The Rack `env` hash is available in Rails controllers using `request.env`.

```ruby
class HomeController
  def index
    user_agent = request.env["HTTP_USER_AGENT"]

    # ...
  end
end
```

### Writing a Rack Response

A Rack response can be written in a Rails controller as:

```ruby
class HomeController
  def index
    self.response = [200, {}, ["I'm Home!"]]
  end
end
```

### Routing to a Rack App

You can route requests to a Rack App in your `config/routes.rb`. See the [routing guide](routing.html#routing-to-rack-applications) for further details.
