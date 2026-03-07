**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Rails on Rack
=============

This guide covers Rails' integration with [Rack](https://en.wikipedia.org/wiki/Rack_(web_server_interface)). After reading this guide, you will know:

* How Rails uses Rack middleware to build an application stack.
* Action Pack's internal middleware stack.
* How to configure and change the middleware stack.
* How to insert your own middleware into the stack.
* The underlying Rack API exposed by Rails controllers.

--------------------------------------------------------------------------------

NOTE: This guide assumes an understanding of the Rack specification and associated concepts such as a Rack application, middleware stack, and `Rack::Builder`. See the [Resources](#resources) section below for further information.

Introduction to Rack
--------------------

Rack provides a minimal, modular, and adaptable interface for developing web applications in Ruby. By wrapping HTTP requests and responses using a conventional structure, it unifies the API for web servers, web frameworks, and software in between (the so-called middleware) into a single method call.

This allows Rack compliant web servers like [Puma](https://puma.io) or [Falcon](https://socketry.github.io/falcon/) to be interchangeably used with any Rack based web framework such as Rails.

Rails on Rack
-------------

### The Primary Rack Object

`Rails.application` is the *primary Rack application object* of a Rails
application. A Rack compliant web server should use `Rails.application` object to serve a Rails application.

### Starting the Rails Server

Rails subclasses `Rack::Server` to create `Rails::Server`. `bin/rails server` instantiates a `Rails::Server` object and starts the web server.

```ruby
Rails::Server.new.tap do |server|
  require APP_PATH
  Dir.chdir(Rails.application.root)
  server.start
end
```

See the [initilization guide](initialization.html#rails-server-start) for further information on how the server starts up.


Action Dispatcher Middleware Stack
----------------------------------

`ActionDispatch::MiddlewareStack` is Rails' equivalent of `Rack::Builder`. It's built with more flexibility and features to meet Rails' requirements.

`Rails::Application` uses `ActionDispatch::MiddlewareStack` to combine internal and external middleware to build the stack which forms a complete Rack application using Rails.

### Inspecting the Middleware Stack

View the middleware stack in use by running:

```bash
$ bin/rails middleware
```

Here's an example from a freshly generated Rails 8 app:

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

The [Internal Middleware Stack](#internal-middleware-stack) section below summarizes the default middleware components depicated above.

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

#### [`ActionDispatch::HostAuthorization`][]

Prevents DNS rebinding attacks by restricting the hosts to which a request can be sent. See the [configuration guide](configuring.html#actiondispatch-hostauthorization) for configuration instructions.

[`ActionDispatch::HostAuthorization`]: https://api.rubyonrails.org/classes/ActionDispatch/HostAuthorization.html

#### [`Rack::Sendfile`][]

Sets server specific `X-Sendfile header`. Configure this via [`config.action_dispatch.x_sendfile_header`][] option.

[`Rack::Sendfile`]: https://rack.github.io/rack/3.2/Rack/Sendfile.html
[`config.action_dispatch.x_sendfile_header`]: configuring.html#config-action-dispatch-x-sendfile-header

#### [`ActionDispatch::Static`][]

Serves static files from the `public` folder. Disabled when [`config.public_file_server.enabled`][] is `false`.

[`ActionDispatch::Static`]: https://api.rubyonrails.org/classes/ActionDispatch/Static.html
[`config.public_file_server.enabled`]: configuring.html#config-public-file-server-enabled

#### [`Rack::Lock`][]

Sets `env["rack.multithread"]` to `false` and wraps the application within a mutex.

[`Rack::Lock`]: https://rack.github.io/rack/3.2/Rack/Lock.html

#### [`ActionDispatch::Executor`][]

Ensures thread safe code reloading during development.

[`ActionDispatch::Executor`]: https://api.rubyonrails.org/classes/ActionDispatch/Executor.html

#### [`ActionDispatch::ServerTiming`][]

Sets a [`Server-Timing`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Server-Timing) header containing performance metrics for the request.

[`ActionDispatch::ServerTiming`]: https://api.rubyonrails.org/classes/ActionDispatch/ServerTiming.html

#### [`ActiveSupport::Cache::Strategy::LocalCache::Middleware`][]

An in-memory cache. This cache is not thread safe.

[`ActiveSupport::Cache::Strategy::LocalCache::Middleware`]: https://api.rubyonrails.org/classes/ActiveSupport/Cache/Strategy/LocalCache.html

#### [`Rack::Runtime`][]

Sets an `X-Runtime` header, containing the time (in seconds) taken to execute the request.

[`Rack::Runtime`]: https://rack.github.io/rack/3.2/Rack/Runtime.html

#### [`Rack::MethodOverride`][]

Allows the method to be overridden if `params[:_method]` is set. This is how Rails supports `PUT`, `PATCH`, and `DELETE` HTTP methods since they are not browser native.

[`Rack::MethodOverride`]: https://rack.github.io/rack/3.2/Rack/MethodOverride.html

#### [`ActionDispatch::RequestId`][]

Makes a unique `X-Request-Id` header available to the response and enables the `ActionDispatch::Request#request_id` method.

[`ActionDispatch::RequestId`]: https://api.rubyonrails.org/classes/ActionDispatch/RequestId.html

#### [`ActionDispatch::RemoteIp`][]

Checks for IP spoofing attacks.

[`ActionDispatch::RemoteIp`]: https://api.rubyonrails.org/classes/ActionDispatch/RemoteIp.html

#### [`Propshaft::QuietAssets`][]

Suppresses logger output for asset requests.

[`Propshaft::QuietAssets`]: https://github.com/rails/propshaft/blob/main/lib/propshaft/quiet_assets.rb

#### [`Rails::Rack::Logger`][]

Notifies the logs that the request has begun. After the request is complete, flushes all the logs.

[`Rails::Rack::Logger`]: https://api.rubyonrails.org/classes/Rails/Rack/Logger.html

#### [`ActionDispatch::ShowExceptions`][]

Rescues any exception returned by the application and calls an exceptions app that will wrap it in a format for the end user.

[`ActionDispatch::ShowExceptions`]: https://api.rubyonrails.org/classes/ActionDispatch/ShowExceptions.html

#### [`ActionDispatch::DebugExceptions`][]

Responsible for logging exceptions and showing a debugging page if the request is local.

[`ActionDispatch::DebugExceptions`]: https://api.rubyonrails.org/classes/ActionDispatch/DebugExceptions.html

#### [`ActionDispatch::ActionableExceptions`][]

Provides a way to dispatch actions from Rails' error pages.

[`ActionDispatch::ActionableExceptions`]: https://api.rubyonrails.org/files/actionpack/lib/action_dispatch/middleware/actionable_exceptions_rb.html

#### [`ActionDispatch::Reloader`][]

Provides prepare and cleanup callbacks, intended to assist with code reloading during development.

[`ActionDispatch::Reloader`]: https://api.rubyonrails.org/classes/ActionDispatch/Reloader.html

#### [`ActionDispatch::Callbacks`][]

Provides callbacks to be executed before and after dispatching the request.

[`ActionDispatch::Callbacks`]: https://api.rubyonrails.org/classes/ActionDispatch/Callbacks.html

#### [`ActiveRecord::Migration::CheckPending`][]

Checks pending migrations and raises `ActiveRecord::PendingMigrationError` if any migrations are pending.

[`ActiveRecord::Migration::CheckPending`]: https://api.rubyonrails.org/classes/ActiveRecord/Migration/CheckPending.html

#### [`ActionDispatch::Cookies`][]

Sets cookies for the request.

[`ActionDispatch::Cookies`]: https://api.rubyonrails.org/classes/ActionDispatch/Cookies.html

#### [`ActionDispatch::Session::CookieStore`][]

Responsible for storing the session in cookies.

[`ActionDispatch::Session::CookieStore`]: https://api.rubyonrails.org/classes/ActionDispatch/Session/CookieStore.html

#### [`ActionDispatch::Flash`][]

Sets up the flash keys. Only available if [`config.session_store`][] is set to a value.

[`ActionDispatch::Flash`]: https://api.rubyonrails.org/classes/ActionDispatch/Flash.html
[`config.session_store`]: configuring.html#config-session-store

#### [`ActionDispatch::ContentSecurityPolicy::Middleware`][]

Provides a DSL to configure a `Content-Security-Policy` header. See [Securing Rails Applications](security.html#content-security-policy-header) for further information.

[`ActionDispatch::ContentSecurityPolicy::Middleware`]: https://api.rubyonrails.org/classes/ActionDispatch/ContentSecurityPolicy/Middleware.html

#### [`Rack::Head`][]

Returns an empty body for all `HEAD` requests. It leaves all other requests unchanged.

[`Rack::Head`]: https://rack.github.io/rack/3.2/Rack/Head.html

#### [`Rack::ConditionalGet`][]

Adds support for "Conditional `GET`" so that server responds with nothing if the page wasn't changed.

[`Rack::ConditionalGet`]: https://rack.github.io/rack/3.2/Rack/ConditionalGet.html

#### [`Rack::ETag`][]

Adds an `ETag` header on all String bodies. ETags are used to validate the cache to faciliate "Conditional `GET`" requests as described above. See the [Caching with Rails](caching_with_rails.html#conditional-get-support) for further information.

[`Rack::ETag`]: https://rack.github.io/rack/3.2/Rack/ETag.html

#### [`Rack::TempfileReaper`][]

Cleans up tempfiles used to buffer multipart requests.

[`Rack::TempfileReaper`]: https://rack.github.io/rack/3.2/Rack/TempfileReaper.html

TIP: You can use any of the above middleware in a custom Rack stack.

Custom Middleware
-----------------

Your Rails app can implement and include custom middleware as per your requirements.

Custom middleware files should be placed in the `lib/` folder and `require`d manually since middleware is not auto-reloaded.

### Creating middleware

Creating a new `lib/middleware/` folder and excluding it from the autoload path is recommended.

```ruby
# config/application.rb

module MyApp
  class Application < Rails::Application
    # ...

    config.autoload_lib(ignore: %w[assets tasks middleware])

    # ...
  end
end
```

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

### Adding custom middleware to the stack

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

Advanced usage
--------------

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

### Writing a Rack response

A Rack response can be written in a Rails controller as:

```ruby
class HomeController
  def index
    self.response = [200, {}, ["I'm Home!"]]
  end
end
```

Resources
---------

* [Official Rack Website](https://rack.github.io/rack/)
* [Rack specification](https://rack.github.io/rack/main/SPEC_rdoc.html)
* [A deep dive into Rack for Ruby](https://binarysolo.blog/a-deep-dive-into-rack-for-ruby/)
