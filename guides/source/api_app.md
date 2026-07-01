**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Using Rails for API-only Applications
=====================================

In this guide you will learn:

* Why you should use Rails to build an API.
* How to configure Rails without any browser features.
* Rendering JSON and XML responses.
* The Rack middleware stack in API applications.
* The Action Controller modules excluded from API applications.

--------------------------------------------------------------------------------

What is an API Application?
---------------------------

An API application speaks a data-interchange format such as JSON or XML, rather than HTML
which is used to paint a user interface. Its purpose is to integrate with another
piece of software, as opposed to being used by a human.

While Rails [provides a mechanism to build an API](action_view_overview.html#jbuilder) alongside your
full-stack application, a Rails application that only speaks JSON (or another similar format)
can be a useful configuration. The same Rails API could service the JavaScript frontend in the
browser, as well as the native mobile apps and other integrations.

[Basecamp](https://github.com/basecamp/bc3-api) is a good example of the former approach where HTML is used
for web browsers, but a JSON API is also provided for external software integrations. [X](https://x.com) uses the latter
approach in its web application which is built using a frontend that consumes JSON resources
from an internal API.

This guide covers Rails' support for building an API application without any
HTML rendering or browser-related features.

Why Use Rails for APIs?
-----------------------

When using Rails as an API, we replace a view layer that generates HTML with one
that generates JSON, XML, or a similar data-interchage format. Nothing else changes.

Rails still provides a feature-rich environment to develop server applications
with its security features, MVC architecture, and resourceful routing. Tools such as
[Active Record][], [Active Job][], [Active Storage][], [Action Mailer][],
and [native caching][] are all still available in API applications.

Most of Rails' features are still relevant even when building an API-only application.

[Active Record]: active_record_basics.html
[Active Job]: active_job_basics.html
[Active Storage]: active_storage_overview.html
[Action Mailer]: action_mailer_basics.html
[native caching]: caching_with_rails.html

Using Rails for API-only Applications
-------------------------------------

Rails can be configured to be used only as an API, which will exclude the HTML rendering
and browser-related features. Some features can be added back in as required.

### Creating a New API Application

You can generate a new API-only Rails app using:

```bash
$ rails new my_api_app --api
```

This will:

- Set `ApplicationController` to inherit from [`ActionController::API`][] instead of [`ActionController::Base`][], which [excludes the modules](#api-controller-modules) for browser-related functionality.
- Configure the generators to skip generating views, helpers, and assets when you scaffold a new resource.
- Exclude [Rack middleware](https://guides.rubyonrails.org/rails_on_rack.html) related to browser applications, such as support for cookies.

[`ActionController::API`]: https://api.rubyonrails.org/classes/ActionController/API.html
[`ActionController::Base`]: https://api.rubyonrails.org/classes/ActionController/Base.html

### Scaffolding API Resources

The `bin/rails generate scaffold` command will skip HTML views for API applications:

```bash
$ bin/rails g scaffold Group name:string
```

This will create the `GroupsController` demonstrated below along with an empty `Group` model.

```ruby
# app/controllers/groups_controller.rb

class GroupsController < ApplicationController
  before_action :set_group, only: %i[ show update destroy ]

  # GET /groups
  def index
    @groups = Group.all

    render json: @groups
  end

  # GET /groups/1
  def show
    render json: @group
  end

  # POST /groups
  def create
    @group = Group.new(group_params)

    if @group.save
      render json: @group, status: :created, location: @group
    else
      render json: @group.errors, status: :unprocessable_content
    end
  end

  # PATCH/PUT /groups/1
  def update
    if @group.update(group_params)
      render json: @group
    else
      render json: @group.errors, status: :unprocessable_content
    end
  end

  # DELETE /groups/1
  def destroy
    @group.destroy!
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_group
      @group = Group.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def group_params
      params.expect(group: [:name])
    end
end
```

The controller is set up to render JSON by default. Any objects passed to `render json:` will be converted to JSON using `to_json`.

Assuming we have two `Group`s in our database named _Rails Founders_ and _Rails Contributors_, the `/groups` endpoint will generate the following JSON response.

```bash
$ curl -s localhost:3000/groups | jq
[
  {
    "id": 1,
    "name": "Rails Founders",
    "created_at": "2026-03-24T13:39:22.357Z",
    "updated_at": "2026-03-24T13:39:22.357Z"
  },
  {
    "id": 2,
    "name": "Rails Contributors",
    "created_at": "2026-03-24T13:39:25.386Z",
    "updated_at": "2026-03-24T13:39:25.386Z"
  }
]
```

NOTE: The above example, and more examples further down use the `jq` command line utility to format JSON output. If it isn't installed on your system, consult the [download page](https://jqlang.org/download/) to for instructions.

### Building JSON using JBuilder

For more fine-grained control over the JSON structure, or to build complex JSON objects,
you can use the [JBuilder](https://github.com/rails/jbuilder) gem. It isn't installed by
default — you'll need to uncomment it in your `Gemfile` and run `bundle install`.

JBuilder provides a handy DSL for building JSON objects, and requires a view file:

```ruby
# app/views/groups/index.json.jbuilder

json.array! @groups do |group|
  json.name(group.name)
end
```

Using this technique, we still have a view layer, only simpler than if it was HTML — and we still get the benefits of MVC separation.

NOTE: When the `jbuilder` gem is present in your Gemfile, `bin/rails generate scaffold` will automatically create `.json.jbuilder` views along with the controller and model.

Ensure the controller's index action implicitly renders the JBuilder template, and doesn't call `render`:

```ruby
def index
  @groups = Group.all
end
```

The `/groups` endpoint will now only return the group names:

```bash
$ curl -s localhost:3000/groups | jq
[
  {
    "name": "Rails Founders"
  },
  {
    "name": "Rails Contributors"
  }
]
```

TIP: You can optionally add `render formats: :json` in your controller action to render JBuilder responses if you wish to be more explicit.

### XML Responses

While JSON is the default, Rails API applications can also render XML. Rails includes the [`builder`](https://github.com/rails/builder) gem which provides a DSL to build XML data structures.

```ruby
# app/views/groups/index.xml.builder

xml.groups do
  @groups.each do |group|
    xml.group do
      xml.name group.name
    end
  end
end
```

You'll also need to add two modules to your Application Controller. These are [excluded by default](#api-controller-modules) for API applications. The `jbuilder` gem automatically adds them back in, but `builder` does not.

```ruby
class ApplicationController < ActionController::API
  include ActionView::Rendering
  include ActionController::ImplicitRender
end
```

Ensure your controller action is rendering implicitly (alternatively, you can use `render formats: :xml`):

```ruby
def index
  @groups = Group.all
end
```

```ruby
def index
  @groups = Group.all
  render formats: :xml
end
```

The `/groups` endpoint will now render XML!

```bash
$ curl -s localhost:3000/groups
<groups>
  <group>
    <name>Rails Founders</name>
  </group>
  <group>
    <name>Rails Contributors</name>
  </group>
</groups>
```

NOTE: If `ActionView::Rendering` is not included, attempting to render a template of any format will silently return a `204 No Content` response. It will not raise an error.

#### ERB

If you don't wish to use `builder`, you can use ERB to write your XML views.

```html+erb
<%# app/views/groups/index.xml.erb -%>

<groups>
  <% @groups.each do |group| %>
  <group>
    <name><%= group.name %></name>
  </group>
  <% end %>
</groups>
```

### Reconfiguring an Existing Application

Reconfigure an existing fully-featured Rails application to function as API-only by
setting `config.api_only`:

```ruby
# config/application.rb

# ...
module MyRailsApp
  class Application < Rails::Application
    # ...
    config.api_only = true
  end
end
```

This will also change [`config.debug_exception_response_format`][] to `:api`. To preserve rendering
errors as HTML pages, set it to `:default` in your `config/environments/development.rb`.

Change your `ApplicationController`'s super-class:

```ruby
class ApplicationController < ActionController::API
end
```

That's everything you need to do to reconfigure your app to work solely as an API.

[`config.debug_exception_response_format`]: configuring.html#config-debug-exception-response-format

Rack Middleware in API Applications
-----------------------------------

A Rails API application builds the following middleware stack by default:

```ruby
use ActionDispatch::HostAuthorization
use Rack::Sendfile
use ActionDispatch::Static
use ActionDispatch::Executor
use ActionDispatch::ServerTiming
use ActiveSupport::Cache::Strategy::LocalCache::Middleware
use Rack::Runtime
use ActionDispatch::RequestId
use ActionDispatch::RemoteIp
use Rails::Rack::Logger
use ActionDispatch::ShowExceptions
use ActionDispatch::DebugExceptions
use ActionDispatch::ActionableExceptions
use ActionDispatch::Reloader
use ActionDispatch::Callbacks
use ActiveRecord::Migration::CheckPending
use Rack::Head
use Rack::ConditionalGet
use Rack::ETag
run MyApp::Application.routes
```

Browser-specific middleware such as `ActionDispatch::Cookies`, `ActionDispatch::Flash`, and `ActionDispatch::ContentSecurityPolicy::Middleware` are excluded for API applications.

They can be manually added back in if you wish. For further information on Rack middleware, see the [Rails on Rack guide](rails_on_rack.html#internal-middleware-stack).

### Session Middleware

The Rack middleware for [Rails sessions](action_controller_overview.html#session) is excluded by default for API applications. To add it back in, you need to manually [configure your session store](configuring.html#config-session-store) before adding the middleware to the stack, then pass `session_options` when including the store's middleware.

```ruby
# config/initializers/session_store.rb

Rails.application.config.tap do |config|
  # Configure the session to use cookies
  config.session_store :cookie_store, key: "_my_app_session"

  # Required for all session management regardless of the session store
  config.middleware.use ActionDispatch::Cookies

  # Add the middleware for the cookie store to the stack
  config.middleware.use \
    config.session_store, config.session_options
end
```

You can set up other session stores such as `ActionDispatch::Session::CacheStore` or `ActionDispatch::Session::MemCacheStore` using the same technique.

API Controller Modules
----------------------

The base class for API-only controllers, [`ActionController::API`][], includes a subset of the
modules included [`ActionController::Base`][] which is used in full-stack Rails applications.

### Included Modules

Some of the included modules are:

|   |   |
|---|---|
| [`ActionController::UrlFor`][] | Makes `url_for` and similar helpers available. |
| [`ActionController::Redirecting`][] | Support for `redirect_to`. |
| [`ActionController::ApiRendering`][] | Basic support for rendering. |
| [`ActionController::Renderers::All`][] | Support for `:json`, `:xml` and similar renderers. |
| [`ActionController::ConditionalGet`][] | Support for `stale?`. |
| [`ActionController::StrongParameters`][] | Support for parameters filtering in combination with Active Model mass assignment. |
| [`ActionController::Caching`][] | Enables controller-level caching techniques such as Russian Doll caching |
| [`ActionController::DataStreaming`][] | Support for `send_file` and `send_data`. |
| [`ActionController::Instrumentation`][] | Support for the instrumentation hooks defined by Action Controller (see [the instrumentation guide](active_support_instrumentation.html#action-controller) for more information regarding this). |
| [`ActionController::ParamsWrapper`][] | Wraps the parameters hash into a nested hash, so that you don't have to specify root elements sending POST requests for instance.
| [`ActionController::Head`][] | Support for returning a response with no content, only headers. |

View the full list of included modules in your Rails console:

```irb
irb> ActionController::API.ancestors.select { it.name.include? "Controller" }
```

Further information on each module is available in the [API documentation](https://api.rubyonrails.org/).

[`ActionController::UrlFor`]: https://api.rubyonrails.org/classes/ActionController/UrlFor.html
[`ActionController::Redirecting`]: https://api.rubyonrails.org/classes/ActionController/Redirecting.html
[`ActionController::ApiRendering`]: https://api.rubyonrails.org/classes/ActionController/ApiRendering.html
[`ActionController::Renderers::All`]: https://api.rubyonrails.org/classes/ActionController/Renderers/All.html
[`ActionController::ConditionalGet`]: https://api.rubyonrails.org/classes/ActionController/ConditionalGet.html
[`ActionController::StrongParameters`]: https://api.rubyonrails.org/classes/ActionController/StrongParameters.html
[`ActionController::Caching`]: https://api.rubyonrails.org/classes/ActionController/Caching.html
[`ActionController::DataStreaming`]: https://api.rubyonrails.org/classes/ActionController/DataStreaming.html
[`ActionController::Instrumentation`]: https://api.rubyonrails.org/classes/ActionController/Instrumentation.html
[`ActionController::ParamsWrapper`]: https://api.rubyonrails.org/classes/ActionController/ParamsWrapper.html
[`ActionController::Head`]: https://api.rubyonrails.org/classes/ActionController/Head.html

### Excluded Modules

View the modules excluded from [`ActionController::API`][], but included in [`ActionController::Base`][] in your
Rails console:

```irb
irb> ActionController::Base.ancestors - ActionController::API.ancestors
```

Any excluded modules can be `include`d manually in your `ApplicationController`:

```ruby
class ApplicationController < ActionController::API
  include AbstractController::Translation
end
```

Some useful modules you may wish to include are:

|   |   |
|---|---|
| [`ActionController::MimeResponds`][] | Use `respond_to` in controllers for multi-format responses |
| [`AbstractController::Translation`][] | Support for the `l` and `t` localization and translation methods |
| [`ActionController::HttpAuthentication::Basic::ControllerMethods`][] | Basic HTTP Authentication |
| [`ActionController::HttpAuthentication::Digest::ControllerMethods`][] | Authentication using HTTP digests |
| [`ActionController::HttpAuthentication::Token::ControllerMethods`][] | Athentication using tokens |
| [`ActionView::Layouts`][] | Support for layouts when rendering. This might be useful with JBuilder |
| [`ActionController::Cookies`][] | Support for cookies, which includes support for signed and encrypted cookies. This requires the `ActionDispatch::Cookies` Rack middleware. |

[`ActionController::MimeResponds`]: https://api.rubyonrails.org/classes/ActionController/MimeResponds.html
[`AbstractController::Translation`]: https://api.rubyonrails.org/classes/AbstractController/Translation.html
[`ActionController::HttpAuthentication::Basic::ControllerMethods`]: https://api.rubyonrails.org/classes/ActionController/HttpAuthentication/Basic/ControllerMethods.html
[`ActionController::HttpAuthentication::Digest::ControllerMethods`]: https://api.rubyonrails.org/classes/ActionController/HttpAuthentication/Digest/ControllerMethods.html
[`ActionController::HttpAuthentication::Token::ControllerMethods`]: https://api.rubyonrails.org/classes/ActionController/HttpAuthentication/Token/ControllerMethods.html
[`ActionView::Layouts`]: https://api.rubyonrails.org/classes/ActionView/Layouts.html
[`ActionController::Cookies`]: https://api.rubyonrails.org/classes/ActionController/Cookies.html
