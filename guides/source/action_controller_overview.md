**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Action Controller Overview
==========================

In this guide, you will learn how controllers work and how they fit into the request cycle in your application.

After reading this guide, you will know how to:

* Follow the flow of a request through a controller.
* Render HTTP responses as well as redirect responses.
* Work with action callbacks to execute code during request processing.
* Access and securely filter parameters passed to your controller.
* Store data in the cookie, the session, and the flash.
* Use the Request and Response Objects.

--------------------------------------------------------------------------------

Action Controller Basics
------------------------

Action Controller is the **C** in the Model View Controller
([MVC](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93controller))
pattern. The [router](routing.html) matches a controller to an
incoming request, which is responsible for processing the request and
generating the response.

For most conventional
[RESTful](https://en.wikipedia.org/wiki/Representational_state_transfer)
applications, the controller will receive the request, fetch or save data from a
model, and render a view to create HTML output.

A controller sits between models and views. The controller
makes model data available to the view, so that the view can display that data
to the user. The controller also receives user input from the view and saves or
updates model data accordingly.

### Structure of a Controller

A controller is a Ruby class which inherits from `ApplicationController` and has
methods just like any other class. Public methods in a controller are also known as
_actions_, as they are responsible for rendering responses.

```ruby
# app/controllers/products_controller.rb

class ProductsController < ApplicationController
  def index
  end
end
```

As per Rails conventions, controllers should define up to 7 conventional CRUD actions as demonstrated below. This convention is used by the [Router DSL](routing.html#crud-verbs-and-actions) to configure resourceful routes to the controller. Other actions may be defined and routed to, but these are outside Rails conventions. Further details are available in the [Routing guide](routing.html).

```ruby
# config/routes.rb

Rails.application.routes.draw do
  # A resourceful route to the `ProductsController`
  resources :products
end
```

```ruby
# app/controllers/products_controller.rb

class ProductsController < ApplicationController
  # GET /products
  def index
    # Display all products
  end

  # GET /products/new
  def new
    # Render a form to create a new product
  end

  # POST /products
  def create
    # Handle the submission form rendered in `new`
    # and create the product in the database
  end

  # GET /products/:id
  def show
    # Show the product
  end

  # GET /products/:id/edit
  def edit
    # Render a form to edit the product
  end

  # PATCH /products/:id
  def update
    # Handle the submission form rendered in `edit`
    # and update the product in the database
  end

  # DELETE /product/:id
  def destroy
    # Delete the product
  end
end
```

Once the [router matches](routing.html) an incoming request a controller and
action, Rails creates an instance of that controller class and calls the
method with the same name as the action.

NOTE: The `new` method in the above controller is an instance method, called on an instance of `ProductsController`. This should not be confused with the `new` class method used to instantiate objects (`ProductsController.new`).

### Naming Conventions

Rails favors pluralizing the resource in the controller's name. For example,
`ProductsController` is preferred over `ProductController` and
`SiteAdminsController` over `SiteAdminController` or `SitesAdminsController`.
However, the plural names are not strictly required — for example, `ApplicationController`.

Following this naming convention will allow you to
use [resourceful routes](routing.html#crud-verbs-and-actions) without
needing to qualify each with [additional options](routing.html#specifying-a-controller-to-use).
The convention also makes named route helpers consistent throughout your application.

The controller naming convention is different from models. While plural names
are preferred for controller names, the singular form is preferred for [model
names](active_record_basics.html#naming-conventions) (e.g. `Account` vs.
`Accounts`).

Controller actions should be _public_, as only _public_ methods are callable as
actions. Helper methods within controllers which are _not_ intended to be actions
should be declared `private` or `protected`.

WARNING: Ensure that you do not override methods defined by `ActionController::Base`
when creating actions. Accidentally redefining them could result in `SystemStackError`.
If you limit your controllers to the 7 CRUD actions, this won't be an issue.

NOTE: If you must use a reserved method as an action name, one workaround is to
use a custom route to map the reserved method name to your non-reserved action
method.

### Rendering Responses

Consider the below route and controller.

```ruby
# config/routes.rb

Rails.application.routes.draw do
  # A resourceful route to the `ProductsController`
  resources :products
end
```

```ruby
class ProductsController < ApplicationController
  def index
  end
end
```

When a user navigates to `/products`, Rails will create an instance
of `ProductsController` and call its `index` method.
If the `index` method is empty, Rails will automatically render
`app/views/products/index.html.erb`.

You can explicity define the template to render using the `render` method:

```ruby
class ProductsController < ApplicationController
  def index
    # Renders `app/views/products/feed.html.erb`
    render "feed"
  end
end
```

WARNING: Calling `render` does not `return` from the current scope. Statements after the method call will still be executed. Ensure you do not call `render` more than once in any given action, as it will raise an `AbstractController::DoubleRenderError`.

To enable rendering of additional formats, not just HTML, use a `respond_to` block. This will choose the correct template based on the `Accept` header in the HTTP request:

```ruby
class ProductsController < ApplicationController
  def index
    respond_to do |format|
      format.html   # renders `app/views/products/index.html.erb`
      format.xml    # renders `app/views/products/index.xml.erb`
    end
  end
end
```

See the [Layouts and Rendering guide](layouts_and_rendering.html#rendering-responses) for futher details on rendering responses.

In the `index` method, the controller would typically create an array of the
`Product` model instances, and make it available as an instance variable called `@products`
in the view:

```ruby
def index
  @products = Product.all
end
```

NOTE: All controllers inherit from `ApplicationController`, which in turn
inherits from
[`ActionController::Base`](https://api.rubyonrails.org/classes/ActionController/Base.html).
For [API only](https://guides.rubyonrails.org/api_app.html) applications `ApplicationController` inherits from
[`ActionController::API`](https://edgeapi.rubyonrails.org/classes/ActionController/API.html).

### Redirecting Requests

Instead of rendering a fully-formed response, such as an HTML document, you might want to redirect the user to a different path. An [HTTP redirection status code](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status#redirection_messages) can be used for this. Rails' [`redirect_to`][] method uses `302 Found` by default.

```ruby
redirect_to photos_url
```

This will send a `302` HTTP response to the browser with `photos_url` in the `Location` header. The browser will then make a new `GET` request to the `photos_url`.

```
HTTP/1.1 302 Found
referrer-policy: strict-origin-when-cross-origin
location: http://localhost:3000/photos
content-type: text/html; charset=utf-8
cache-control: no-cache
connection: close
content-length: 0
```

NOTE: It's worth being aware that `redirect_to` doesn't move execution to a different method within the same request. It sends an HTTP response and then the browser makes a new request to the redirected location which won't have any context from the previous request.

Alternatively, you can use [`redirect_back`][] to return the user to the page they just came from.
The location is pulled from the `HTTP_REFERER` header which is not guaranteed
to be set by the browser, so you must provide a `fallback_location`.

```ruby
redirect_back(fallback_location: root_path)
# or
redirect_back_or_to root_path
```

WARNING: Similar to `render`, `redirect_to` and `redirect_back` do not automatically `return` from the current scope, instead they simply set the HTTP response. Statements occurring after them will still be executed.

[`redirect_to`]: https://api.rubyonrails.org/classes/ActionController/Redirecting.html#method-i-redirect_to
[`redirect_back`]: https://api.rubyonrails.org/classes/ActionController/Redirecting.html#method-i-redirect_back

Use the [`status:`](layouts_and_rendering.html#status) option to use a different HTTP response code. Both numeric and symbolic values are valid.

```ruby
redirect_to photos_path, status: :see_other
```

NOTE: When redirecting using `302 Found`, the client may not always make a `GET` request to the `Location`. JavaScript's `fetch` method will make a `GET` request after redirection from a `GET` or `POST` request. But, if the initial request is another method, for example `PUT`, it will use the same method when requesting the redirected location. This is not a problem in Rails because all [form submissions use `POST`](https://guides.rubyonrails.org/form_helpers.html#forms-with-patch-put-or-delete-methods), even when using [Turbo](http://turbo.hotwired.dev). <br><br> When making requests in custom JavaScript, redirect using [`303 See Other`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/303) to ensure a `GET` request to the redirected location, or [`307 Temporary Redirect`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/307) to preserve the original HTTP verb.

### Header-Only Responses

The [`head`][] method can be used to send responses with only headers to the browser. This is usually in response to an [HTTP `HEAD`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Methods/HEAD) request.

The `head` method accepts a number or symbol representing an HTTP status code.

```ruby
head :bad_request
# or
head 400
```

This would produce the following HTTP response:

```http
HTTP/1.1 400 Bad Request
connection: close
transfer-encoding: chunked
content-type: text/html; charset=utf-8
set-cookie: _blog_session=...snip...; path=/; HttpOnly
cache-control: no-cache
```

You can add additional HTTP headers if you wish.

```ruby
head :created, location: photo_path(@photo)
```

Which would produce:

```http
HTTP/1.1 201 Created
connection: close
transfer-encoding: chunked
location: /photos/1
content-type: text/html; charset=utf-8
set-cookie: _blog_session=...snip...; path=/; HttpOnly
cache-control: no-cache
```

[`head`]: https://api.rubyonrails.org/classes/ActionController/Head.html#method-i-head

Controller Callbacks
--------------------

Controller callbacks are methods that are defined to automatically run before
or after a controller action. Callbacks may be defined in the `ApplicationController`
if they need to be run across the application, or within specific controllers only.

### `before_action`

Callback methods registered via [`before_action`][] run _before_ a controller
action. They may halt the request cycle meaning the controller action itself is never called.

A common use case for `before_action` is to ensure that a user is logged in:

```ruby
class ApplicationController < ActionController::Base
  before_action :require_login

  private
    def require_login
      unless Current.user.present?
        redirect_to new_login_url # halts request cycle
      end
    end
end
```

When a `before_action` callback renders or redirects (like in the example above),
the controller action is not run. If there are additional callbacks
registered to run, they will be cancelled.

In this example, the `before_action` is defined in `ApplicationController` meaning
it will be run before all actions across the applications. This also means the user
will need to be logged into access the login page, which doesn't make sense.

In such cases, use [`skip_before_action`][] to allow specified controller
actions to skip a given `before_action`:

```ruby
class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]
end
```

Now, the `SessionsController`'s `new` and `create` actions will work without
requiring the user to be logged in.

The `:only` option skips the callback only for the listed actions. There is also
an `:except` option which works the other way. These options can be used when
registering action callbacks to run them only for specific actions.

NOTE: If you register the same action callback multiple times with different
options, the last action callback definition will overwrite the previous ones.

[`before_action`]: https://api.rubyonrails.org/classes/AbstractController/Callbacks/ClassMethods.html#method-i-before_action
[`skip_before_action`]: https://api.rubyonrails.org/classes/AbstractController/Callbacks/ClassMethods.html#method-i-skip_before_action

### `after_action` and `around_action`

You can also define action callbacks to run _after_ a controller action has been
executed with [`after_action`][], or to run both before and after with
[`around_action`][].

The `after_action` callbacks are similar to `before_action` callbacks, but
because the controller action has already been run they have access to the
response data that's about to be sent to the client.

NOTE: `after_action` callbacks are executed only after a successful controller
action, and not if an exception is raised in the request cycle.

The `around_action` callbacks are useful when you want to execute code before
and after a controller action, allowing you to encapsulate functionality that
affects the action's execution. They are responsible for running their
associated actions by `yield`ing.

For example, imagine you want to monitor the performance of specific actions.
You could use an `around_action` to measure how long each action takes to
complete and log this information:

```ruby
class ApplicationController < ActionController::Base
  around_action :measure_execution_time

  private
    def measure_execution_time
      start_time = Time.now
      yield  # This executes the action
      end_time = Time.now

      duration = end_time - start_time
      Rails.logger.info "Action #{action_name} from controller #{controller_name} took #{duration.round(2)} seconds to execute."
    end
end
```

TIP: Action callbacks receive `controller_name` and `action_name` as parameters
you can use, as shown in the example above.

The `around_action` callback also wraps rendering. In the example above, view
rendering will be included in the `duration`. The code after the `yield` in an
`around_action` is run even when there is an exception in the associated action
and there is an `ensure` block in the callback.

This is different from `after_action` callbacks where an exception in the action cancels any `after_action` callbacks.

[`after_action`]: https://api.rubyonrails.org/classes/AbstractController/Callbacks/ClassMethods.html#method-i-after_action
[`around_action`]: https://api.rubyonrails.org/classes/AbstractController/Callbacks/ClassMethods.html#method-i-around_action

### Advanced Techniques to Register Callbacks

In addition to registering a method name using `before_action`, `after_action`, or `around_action`, there are two other ways to register callbacks.

#### Using a Block

A block can be supplied to the `*_action` methods. It receives the controller as an argument. The `require_login` action callback from above could be rewritten to use a block:

```ruby
class ApplicationController < ActionController::Base
  before_action do |controller|
    unless Current.user.present?
      redirect_to new_login_url
    end
  end
end
```

Specifically for `around_action`, the block also yields in the `action`:

```ruby
around_action { |_controller, action| time(&action) }
```

#### Using an Object

An object, usually a class, can be used to register callbacks. The object must implement a
method with the same name as the action callback.

For the `before_action` callback, the class must implement a `before` method, and so on. Also,
the `around` method must `yield` to execute the action.

This can be useful in cases that are more complex. As an example, you could rewrite
the `around_action` callback to measure execution time with a class:

```ruby
class ApplicationController < ActionController::Base
  around_action ActionDurationCallback
end

class ActionDurationCallback
  def self.around(controller)
    start_time = Time.now
    yield # This executes the action
    end_time = Time.now

    duration = end_time - start_time
    Rails.logger.info "Action #{controller.action_name} from controller #{controller.controller_name} took #{duration.round(2)} seconds to execute."
  end
end
```

In the above example, the `ActionDurationCallback`'s method is not run in the scope
of the controller but gets `controller` as an argument.

Request Parameters
------------------

Data sent by the incoming request is available in your controller using the
[`params`][] method which returns an [`ActionController::Parameters`][] object.

There are two types of parameter data:

- Query string parameters which are sent as part of the URL (for example, after
  the `?` in `http://example.com/accounts?filter=free`).
- Request body parameters in non-`GET` requests, usually from an HTML form.

Rails does not make a distinction between query string parameters and request body
parameters — both are available in the `params` object in your controller. For
example:

```ruby
class ProductsController < ApplicationController
  # This action receives query string parameters from an HTTP GET request
  # at the URL "/products?filter=books"
  def index
    if params[:filter] == "books"
      @products = Product.books
    else
      @products = Product.all
    end
  end

  # This action receives parameters from a POST request to "/products" URL with
  # form data in the request body.
  def create
    @product = Product.new(params[:product])
    if @product.save
      redirect_to @product
    else
      render "new", status: :unprocessable_content
    end
  end
end
```

NOTE: [`ActionController::Parameters`][] does not inherit from Hash, but it is mostly similar in behavior. Unlike a Hash, symbolic and string keys, such as `:foo` and `"foo"`, are considered to be the same.

[`params`]:
    https://api.rubyonrails.org/classes/ActionController/StrongParameters.html#method-i-params
[`ActionController::Parameters`]:
    https://api.rubyonrails.org/classes/ActionController/Parameters.html

### Parameter Value Types

Values in an [`ActionController::Parameters`][] object must be a permitted scalar value defined in `ActionController::Parameters::PERMITTED_SCALAR_TYPES`.

```ruby
ActionController::Parameters::PERMITTED_SCALAR_TYPES
# => [String, Symbol, NilClass, Numeric, TrueClass, FalseClass, Date, Time, StringIO, IO, ActionDispatch::Http::UploadedFile, Rack::Test::UploadedFile]
```

The object can contain nested hashes and arrays, but values within those must also contain a permitted scalar.

To send an array of values, append an empty pair of square brackets `[]` to the key name:

```
GET /users?ids[]=1&ids[]=2&ids[]=3
```

NOTE: The actual URL in this example will be encoded as
`/users?ids%5b%5d=1&ids%5b%5d=2&ids%5b%5d=3` as the `[` and `]` characters are
not allowed in URLs. Most of the time you don't have to worry about this because
the browser will encode it for you, and Rails will decode it automatically, but
if you ever find yourself having to send those requests to the server manually
you should keep this in mind.

The value of `params[:ids]` will be the array `["1", "2", "3"]`. Parameter values
are always strings, Rails does not attempt to guess or cast the type.

NOTE: Values such as `[nil]` or `[nil, nil, ...]` in `params` are replaced with
`[]` for security reasons by default. See [Security
Guide](security.html#unsafe-query-generation) for more information.

To send a hash, you include the key name inside the brackets:

```html
<form accept-charset="UTF-8" action="/users" method="post">
  <input type="text" name="user[name]" value="Acme" />
  <input type="text" name="user[phone]" value="12345" />
  <input type="text" name="user[address][postcode]" value="12345" />
  <input type="text" name="user[address][city]" value="Carrot City" />
</form>
```

When this form is submitted, the value of `params[:user]` will be:

```ruby
{
  "name" => "Acme",
  "phone" => "12345",
  "address" => {
    "postcode" => "12345",
    "city" => "Carrot City"
  }
}
```

Note the nested hash in `params[:user][:address]`.

Rails provides helpers to construct HTML forms that adhere to Rails conventions. Refer
to the [Form Helpers guide](form_helpers.html) for further information.

### Composite Key Parameters

[Composite key parameters](active_record_composite_primary_keys.html) contain
multiple values in one parameter separated by a delimiter (such as an underscore).
Therefore, you will need to extract each value so that you can pass them to
Active Record. You can use the [`extract_value`][] method to do that.

Consider the below controller and route:

```ruby#4
class ProductsController < ApplicationController
  def show
    # Extract the composite ID value from URL parameters.
    id = params.extract_value(:id)
    @product = Product.find(id)
  end
end
```

```ruby
get "/products/:id", to: "products#show"
```

When a user requests the URL `/products/4_2`, the controller will extract the
composite key value `["4", "2"]` and pass it to `Product.find`. The [`extract_value`][]
method may be used to extract arrays out of any delimited parameters.

[`extract_value`]: https://api.rubyonrails.org/classes/ActionController/Parameters.html#method-i-extract_value

### JSON Parameters

If your application exposes an API, you will likely accept parameters in JSON
format. If the `content-type` header of your request is set to
`application/json`, Rails will automatically load your parameters into the
`params` hash, which you can access as you would normally.

So for example, if you are sending this JSON content:

```json
{ "user": { "name": "acme", "address": "123 Carrot Street" } }
```

Your controller will receive:

```ruby
{ "user" => { "name" => "acme", "address" => "123 Carrot Street" } }
```

#### Parameter Wrapping

Rails will automatically wrap parameters within a key denoting the corresponding resource,
and also add the controller name to JSON parameters.

For example, consider the below JSON object:

```json
{ "name": "acme", "address": "123 Carrot Street" }
```

If we send the above data to `create` action of the `UsersController`,
the JSON data will be wrapped within the `:user` key as:

```ruby
{
  controller: "users",
  action: "create",
  name: "acme",
  address: "123 Carrot Street",
  user: {
    name: "acme", address: "123 Carrot Street"
  }
}
```

NOTE: Rails adds a clone of the parameters to the hash within the key corresponding
to the resource's name. As a result, both the original version
of the parameters and the "wrapped" version of the parameters will exist in the
params object.

NOTE: While the action and controller names are available in the params object,
it is recommended to use the methods [`controller_name`][] and [`action_name`][] instead to access these values.

Parameter wrapping is enabled by default, but can be disabled using a configuration option:

```ruby
# config/application.rb

config.action_controller.wrap_parameters_by_default = false
```

You can also customize the name of the key or specific parameters you want to
wrap, see the [API documentation](https://api.rubyonrails.org/classes/ActionController/ParamsWrapper.html)
for more.

[`controller_name`]:
    https://api.rubyonrails.org/classes/ActionController/Metal.html#method-i-controller_name
[`action_name`]:
    https://api.rubyonrails.org/classes/AbstractController/Base.html#method-i-action_name

### Routing Parameters

Parameters specified as part of a route declaration in the `routes.rb` file are
also made available in the `params` hash. For example, we can add a route that
captures the `:category` parameter for a product:

```ruby
get "/products/:category", to: "products#index", foo: "bar"
```

When a user navigates to `/products/electronics` URL, `params[:category]` will be set to
"electronics". When this route is used, `params[:foo]` will also be set to "bar", as
if it were passed in the query string.

Any other parameters defined by the route declaration, such as `:id`, will also
be available.

### Global Default Parameters

You can set global default parameters when generating URLs by defining a `default_url_options` method in your controller.

```ruby
class ApplicationController < ActionController::Base
  def default_url_options
    { locale: I18n.locale }
  end
end
```

The specified defaults will be used as a starting point when generating URLs.
They can be overridden by the options passed to [`url_for`][] or any path helper
such as `products_path`. The above example will automatically add the locale to every URL.

```ruby
products_path # => "/products?locale=en"
```

You can still override this default if needed:

```ruby
products_path(locale: :fr) # => "/products?locale=fr"
```

NOTE: All Rails path helpers call `url_for` under the hood.

If you define `default_url_options` in `ApplicationController`, as in the
example above, these defaults will be used for all URL generation. The method
can also be defined in a specific controller, in which case it only applies to
URLs generated for that controller.

In a given request, the method is not actually called for every single generated
URL. For performance reasons the returned hash is cached per request.

[`url_for`]: https://api.rubyonrails.org/classes/ActionView/RoutingUrlFor.html#method-i-url_for

### Securing Submitted Parameters

[Action Controller Strong Parameters](https://api.rubyonrails.org/classes/ActionController/StrongParameters.html) ensures parameters cannot be used in Active Model mass assignments until they have been explicitly permitted.

This requires you to specify the allowed attributes for any given model and declare them in the controller. This is a security practice to prevent users from accidentally or maliciously updating sensitive model attributes.

Consider the below controller and action:

```ruby
class PeopleController < ActionController::Base
  def create
    @person = Person.create(params[:person])
    # ...
  end
end
```

We create a `Person` record using the parameters passed in the `:person` key, without explicitly defining which parameters are permitted. A `Person` may have a boolean attribute which specifies whether or not they're an _admin_. A malicious user could modify the HTML form to send this value and make themselves an admin without permission. As such, all parameters used in mass assignment must be explicitly allowed, and the above example will raise a `ActiveModel::ForbiddenAttributesError`.

#### Permitting Parameter Attributes

Each attribute must be manually permitted using its key. Nested hashes and arrays within attributes are allowed, and depending on the method used, nested keys may also need to be specified.

The [`expect`][], [`permit`][], and [`require`][] methods are commonly used to specify permitted attributes.

##### `expect`

The [`expect`][] method is the safest and most explicit way to permit parameters. If the request doesn't contain all expected parameters, `ActionController::ParameterMissing` will be raised and a `400 Bad Request` HTTP response will be returned.

```ruby#5
class UsersController < ApplicationController
  # ...

  def update
    id = params.expect(:id)
  end

  # ...
end
```

When handling Rails forms, use [`expect`][] to ensure that the root key is present and define the permitted attributes.

```ruby#5
class UsersController < ApplicationController
  # ...
  private
    def user_params
      params.expect(user: [:username, :password])
    end
end
```

[`expect`][] is strict with types. Supplying a single key will return a scalar, and multiple keys will return an array of those values.

```ruby
params = ActionController::Parameters.new(name: "John Doe")
params.expect(:name)
# => "John Doe"

params = ActionController::Parameters.new(name: "John Doe", title: "Mr")
params.expect(:name, :title)
# => ["John Doe", "Mr"]
```

Nested hashes and arrays must be specified, including any nested keys, or they will be filtered out.

```ruby
params = ActionController::Parameters.new(user: { name: "John Doe" })
params.expect(:user)
# => param is missing or the value is empty or invalid: user (ActionController::ParameterMissing)
params.expect(user: [:name])
# => #<ActionController::Parameters {"name" => "John Doe"} permitted: true>

params = ActionController::Parameters.new(ids: ["1", "2", "3"])
params.expect(:ids)
# => param is missing or the value is empty or invalid: ids (ActionController::ParameterMissing)
params.expect(ids: [])
# => ["1", "2", "3"]

params = ActionController::Parameters.new(
  users: [{ name: "John Doe" }, { name: "Jane Doe" }]
)
params.expect(users: [])
# => param is missing or the value is empty or invalid: users (ActionController::ParameterMissing)
params.expect(users: [:name])
# => param is missing or the value is empty or invalid: users (ActionController::ParameterMissing)
params.expect(users: [[:name]])
# => [#<ActionController::Parameters {"name" => "John Doe"} permitted: true>, #<ActionController::Parameters {"name" => "Jane Doe"} permitted: true>]
```

Permit all attributes under a key using:

```ruby
params.expect(user: {})
```

This does not check for types or any nested types. All contained attributes are permitted, which somewhat bypasses the security aspects of strong parameters.

WARNING: Extreme care should be taken when calling `expect` with an empty hash, as it will allow all current and future model attributes to be mass-assigned.

[`expect`]:
    https://api.rubyonrails.org/classes/ActionController/Parameters.html#method-i-expect

##### `permit` and `require`

[`permit`][] returns a new `ActionController::Parameters` object containing only the permitted attributes. Disallowed attributes are filtered out, and no error is raised.

```ruby
params = ActionController::Parameters.new(user: { id: 1, admin: "true" })
params.permit(:user)
# => #<ActionController::Parameters {} permitted: true>
params.permit(user: [:id])
# => #<ActionController::Parameters {"user" => #<ActionController::Parameters {"id" => 1} permitted: true>} permitted: true>
params.permit(user: [:id, :admin])
# => #<ActionController::Parameters {"user" => #<ActionController::Parameters {"id" => 1, "admin" => "true"} permitted: true>} permitted: true>
```

All values under a key can be permitted using `{}`:

```ruby
params = ActionController::Parameters.new(user: { id: 1, admin: "true" })
params.permit(user: {})
# => #<ActionController::Parameters {"user" => #<ActionController::Parameters {"id" => 1, "admin" => "true"} permitted: true>} permitted: true>
```

WARNING: Exercise caution when calling `permit` with an empty hash, as it will allow all current and future model attributes to be mass-assigned.

[`permit`][] is commonly chained with [`require`][] to permit a set of attributes keyed by a resource name. [`require`][] accepts a single key or an array of keys. It returns the associated values if found, or raises `ActionController::ParameterMissing` if any supplied keys are missing.

```ruby
params = ActionController::Parameters.new(user: { id: 1, admin: "true" })
params.require(:user)
# => #<ActionController::Parameters {"id" => 1, "admin" => "true"} permitted: false>
```

As demonstrated above, the object returned by `require(:user)` has not yet been `permitted`. As such, [`require`][] is often chained with [`permit`][] to return a set of permitted attributes:

```ruby
params = ActionController::Parameters.new(user: { id: 1, admin: "true" })
params.require(:user).permit(:id, :admin)
# => #<ActionController::Parameters {"id" => 1, "admin" => "true"} permitted: true>
```

Note that [`expect`][] is the recommended technique to permit attributes, especially when working with nested objects, as it is more explicit about value types, and hence provides additional safety.

[`permit`]:
    https://api.rubyonrails.org/classes/ActionController/Parameters.html#method-i-permit
[`require`]:
    https://api.rubyonrails.org/classes/ActionController/Parameters.html#method-i-require

##### `permit!`

The [`permit!`][] method sets the `permitted` attribute on an `ActionController::Parameters` object to `true`. It does no filtering or value checking whatsoever.

```ruby
params = ActionController::Parameters.new(id: 1, admin: "true")
# => #<ActionController::Parameters {"id"=>1, "admin"=>"true"} permitted: false>
params.permit!
# => #<ActionController::Parameters {"id"=>1, "admin"=>"true"} permitted: true>
```

WARNING: Since `permit!` does not check any values, it bypasses all security benefits provided by strong parameters. Use with extreme caution.

[`permit!`]:
    https://api.rubyonrails.org/classes/ActionController/Parameters.html#method-i-permit-21

Further details on advanced parameter filtering are available in the [API docs](https://api.rubyonrails.org/classes/ActionController/Parameters.html).

Cookies
-------

A [cookie](https://en.wikipedia.org/wiki/HTTP_cookie) (also known as an HTTP
cookie or a web cookie) is a small piece of data from the server that is saved
in the user's browser. The browser may store cookies, create new cookies, modify
existing ones, and send them back to the server with later requests. Cookies
persist data across web requests and therefore enable web applications to
remember user preferences.

Rails provides access to cookies in a controller via the [`cookies`][] method, which
returns an instance of [`ActionDispatch::Cookies`][]. [`ActionDispatch::Cookies`][] is a key-value store and is similar to a Ruby Hash.

```ruby
class PreferencesController < ApplicationController
  def new
    # Read data from a cookie
    @preferences = cookies[:preferences]
  end

  def create
    # Write data to a cookie
    cookies[:preferences] = params.expect(preferences: {})
  end

  def destroy
    # Delete a key from a cookie
    cookies.delete(:preferences)
  end
end
```

NOTE: Setting a key to `nil` will not delete the cookie. You need to use `cookies.delete(:key)`.

Cookies have a [default lifetime](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Cookies#removal_defining_the_lifetime_of_a_cookie) of `Session`, so they will be deleted when the user closes their browser.

Create a _permanent cookie_ that expires at a specific time by passing a hash with the `:expires` option:

```ruby
cookies[:remember_me] = { value: "true", expires: 1.month }
```

Rails also provides a _permanent cookie jar_ that automatically sets the expiration date to 20 years from the time of creation:

```ruby
cookies.permanent[:locale] = "fr"
```

### Encrypted and Signed Cookies

Since cookies are stored on the client browser, they can be susceptible to
tampering and are not considered secure for storing sensitive data. Rails
provides signed and encrypted cookie jars for storing sensitive
data.

The signed cookie jar appends a cryptographic signature on the cookie data to protect its integrity. The data can be read by a user, but cannot be tampered with as it is cryptographically signed.

```ruby
cookes.signed[:preferences] = @user.preferences.to_h
```

The encrypted cookie jar encrypts the data in addition to signing it, so that it cannot be read by the user nor tampered with.

```ruby
cookes.encrypted[:remember_token] = @user.remember_token
```

Refer to the [API documentation](https://api.rubyonrails.org/classes/ActionDispatch/Cookies.html) for more details.


These special cookie jars use a serializer to serialize the cookie values into
strings and deserialize them into Ruby objects when read back. The
default serializer for new applications is `:json`.

You can specify the serializer via [`config.action_dispatch.cookies_serializer`][].

NOTE: Be aware that JSON has limited support serializing Ruby objects such as
`Date`, `Time`, and `Symbol`. These will be serialized and deserialized into
`String`s.

If you need to store these or more complex objects, you may need to manually
convert their values when reading them in subsequent requests.

[`config.action_dispatch.cookies_serializer`]:
    configuring.html#config-action-dispatch-cookies-serializer
[`ActionDispatch::Cookies`]:
    https://api.rubyonrails.org/classes/ActionDispatch/Cookies.html
[`cookies`]:
    https://api.rubyonrails.org/classes/ActionController/Cookies.html#method-i-cookies

Session
-------

Rails provides a _session_ object which is used to store data relevant to the current user session. For example, data related to user authentication may be stored in the session object.

Session data is stored in an encrypted cookie by default, but other stores [may be configured](#session-stores).

### Working with the Session

The session is available in the controller and the view via the `session` method which returns an instance of `ActionDispatch::Http::Session`. This object is a key-value store and values can be accessed and set in the same way as a Ruby Hash.

```ruby
class SessionsController < ActionController::Base
  # Read the session to redirect the user back to their initial location
  # after a log in, or redirect them to the root path if no location is set.
  def create
    # ...

    redirect_to session[:initial_location] || root_path
  end
end
```

To store data the session, assign a value to a key as you would in a Ruby Hash.

```ruby
class ProductsController < ApplicationController
  def create
    # ...

    # Handle logged out user
    session[:initial_location] = request.referer
    redirect_to login_path
  end
end
```

To remove something from the session, delete the key:

```ruby
class ProductsController < ApplicationController
  def new
    session.delete(:initial_location)
  end
end
```

Delete all data and create a new session object using [`reset_session`][]. It is
recommended to use `reset_session` before logging in to avoid [session fixation
attacks](security.html#session-fixation).

NOTE: Sessions are lazily loaded. If you don't access sessions in your action's
code, they will not be loaded. Hence, you will never need to disable sessions -
not accessing them will do the job.

[`reset_session`]:
    https://api.rubyonrails.org/classes/ActionController/Metal.html#method-i-reset_session

### Session Stores

The storage mechanism for session data can be configured. By default, data is stored in an encrypted cookie, but other stores are available.

All sessions have a unique ID representing the session object. Regardless of the chosen store, this session ID is always stored in a cookie. The session data can be stored using one of the following storage mechanisms:

* [`ActionDispatch::Session::CookieStore`][] - Stores the data in an encrypted cookie.
* [`ActionDispatch::Session::CacheStore`][] - Stores the data in the Rails
  cache.
* [`ActionDispatch::Session::ActiveRecordStore`][activerecord-session_store] -
  Stores the data in a database using Active Record (requires the
  [`activerecord-session_store`][activerecord-session_store] gem).
* A custom store or a store provided by a third party gem.

For most session stores, Rails uses the unique session ID in the cookie
to read session data from your chosen store. Rails does not allow you
to pass the session ID in the URL as this is less secure.

#### `CookieStore`

The `CookieStore` is the default and recommended session store. It stores all
session data, including the session ID, in an encrypted cookie. The `CookieStore`
is lightweight and does not require any configuration to use in a new application.

Cookies are limited 4 kB of data, and the cookie store is bound by this limit.
While this is lesser than the other storage options, it is usually enough. Storing
large amounts of data in the session is discouraged. You should especially
avoid storing complex objects (such as model instances) in the session.

#### `CacheStore`

You can use the `CacheStore` if your sessions don't store critical data or don't
need to be around for long periods. This will store sessions using the cache
implementation you have configured for your application. The advantage is that
you can use your existing cache infrastructure for storing sessions without
requiring any additional setup or administration. The downside is that the
session storage will be temporary and data could disappear at any time.

Read more about session storage in the [Security Guide](security.html#sessions).

### Configuring the Session

Some aspects of the session can be configured.

Set the session store using:

```ruby
# config/initializers/sessions.rb

Rails.application.config.session_store :cache_store
```

When using the cookie store, Rails automatically sets the name of the cookie. However, this can also be configured:

```ruby
# config/initializers/sessions.rb

Rails.application.config.session_store :cookie_store, key: "_your_app_session"
```

NOTE: Be sure to restart your server when you modify an initializer file.

You can also pass a `:domain` key and specify the domain name for the cookie:

```ruby
Rails.application.config.session_store :cookie_store, key: "_your_app_session", domain: ".example.com"
```

See [`config.session_store`](configuring.html#config-session-store) in the
configuration guide for more information.

NOTE: Signed and encrypted cookies, including the session when using the cookie store, are signed using the `secret_key_base` generated for all new Rails applications. It is usually stored in the encrypted credentials file: `config/credentials.yml.enc`. Changing the `secret_key_base` will render all signed and encrypted cookies unreadable. Refer to the [security guide](security.html#custom-credentials) for further information.

[`ActionDispatch::Session::CookieStore`]:
    https://api.rubyonrails.org/classes/ActionDispatch/Session/CookieStore.html
[`ActionDispatch::Session::CacheStore`]:
    https://api.rubyonrails.org/classes/ActionDispatch/Session/CacheStore.html
[activerecord-session_store]:
    https://github.com/rails/activerecord-session_store

### The Flash

The [flash](https://api.rubyonrails.org/classes/ActionDispatch/Flash.html)
provides a way to pass temporary data between controller actions
invoked in successive HTTP requests.

Anything you place in the flash will be available in the very next request,
and then cleared.

The flash is typically used for setting messages such as notices and alerts in a
controller action, before redirecting to an action that displays the message.

The flash is accessed via the [`flash`][] method which returns an instance of [`ActionDispatch::Flash::FlashHash`][]. Similar to the session, the
flash values are stored as key-value pairs exactly like a Ruby Hash.

Consider the below example where the controller sets a flash message after a product
is created, which will be available to display during the next request after the
user is redirected.

```ruby
class ProductsController < ApplicationController
  def create
    # ...

    flash[:notice] = "Your product was created!"
    redirect_to products_path, status: :see_other
  end
end
```

You may use different keys to assign different message types:

```ruby
flash[:notice]  = "Your product was created!"
flash[:alert]   = "Sorry, something when wrong while creating your product."
flash[:warning] = "Your product was created, but there were some problems."
```

Set a flash message when calling `redirect_to` by including it as a parameter:

```ruby
# Equivalent to setting flash[:notice]
redirect_to root_url, notice: "Your product was created!"

# Equivalent to setting flash[:alert]
redirect_to root_url, alert: "Sorry, something when wrong when creating your product."
```

Only `notice:` and `alert:` options may be used at the top-level. Storing messages under other keys needs the `flash:` option:

```ruby
# Equivalent to setting flash[:warning]
redirect_to root_url, flash: { warning: "Your product was created, but there were some problems." }
```

The flash does not render anything in the UI — it is a short-term data storage mechanism. Reading flash data and rendering the appropriate HTML is left up the the developer.

[`ActionDispatch::Flash::FlashHash`]:
    https://api.rubyonrails.org/classes/ActionDispatch/Flash/FlashHash.html

#### Displaying Flash Messages

It is recommend to add code to render flash messages in your application layout, so
messages are automatically rendered on every page without additional steps.

Iterate through all the keys and values to render all set messages, and then you can use CSS to style the different types of messages based on their type:

```erb
<%# app/views/layouts/application.html.erb %>

<html>
  <%# ... %>
  <body>
    <% flash.each do |type, message| -%>
      <%= tag.div class: class_names("flash", type) do %>
        <p><%= message %></p>
      <% end %>
    <% end -%>

    <%# ... %>
    <%= yield %>
  </body>
</html>
```

#### `flash.keep` and `flash.now`

[`flash.keep`][] is used to carry over the flash value through to an additional
request. This is useful when there are multiple redirects.

For example, assume that the `root_url` routes to the `index` action in the controller below, and all requests here are redirected to `UsersController#index`.

If an action sets the flash and redirects to `MainController#index`, those flash values will be lost during the next redirect.

Use `flash.keep` to persist the values in the flash for one more request.

```ruby#4,7
class MainController < ApplicationController
  def index
    # Persists all flash values.
    flash.keep

    # Persists only the `:notice` value.
    flash.keep(:notice)

    # ...
  end
end
```

By default, setting flash value will make them available to the next request. [`flash.now`][] is used to make the flash values available in the same request.

In the below example, when the `create` action fails to save a resource, the `new` template is rendered.

Since there is no redirection, the response will not immediately trigger another HTTP request. Use `flash.now` to display a message using the flash in this case. This will make the message available in only the current request.

```ruby
class ProductsController < ApplicationController
  def create
    @product = Product.new(product_params)
    if @product.save
      # ...
    else
      flash.now[:error] = "The product could not be saved"
      render "new", status: :unprocessable_content
    end
  end
end
```

[`flash`]:
    https://api.rubyonrails.org/classes/ActionDispatch/Flash/RequestMethods.html#method-i-flash
[`flash.keep`]:
    https://api.rubyonrails.org/classes/ActionDispatch/Flash/FlashHash.html#method-i-keep
[`flash.now`]:
    https://api.rubyonrails.org/classes/ActionDispatch/Flash/FlashHash.html#method-i-now

The Request and Response Objects
--------------------------------

Every controller has two methods, [`request`][] and [`response`][], which can be
used to access the request and response objects associated with the
current request cycle.

The `request` method returns an instance of
[`ActionDispatch::Request`][]. The [`response`][] method returns an instance
of [`ActionDispatch::Response`][].

[`ActionDispatch::Request`]: https://api.rubyonrails.org/classes/ActionDispatch/Request.html
[`request`]: https://api.rubyonrails.org/classes/ActionController/Base.html#method-i-request
[`response`]: https://api.rubyonrails.org/classes/ActionController/Base.html#method-i-response
[`ActionDispatch::Response`]: https://api.rubyonrails.org/classes/ActionDispatch/Response.html

### The `request` Object

The request object contains useful information about the request coming in from
the client. This section describes the purpose of some of the properties of the
`request` object.

The full list of the available methods can be viewed in the [Rails API
documentation](https://api.rubyonrails.org/classes/ActionDispatch/Request.html)
and [Rack](https://rack.github.io/rack/main/Rack/Request.html)
documentation.

| Property of `request`                     | Purpose                                                                          |
| ----------------------------------------- | -------------------------------------------------------------------------------- |
| `host`                                    | The hostname used for this request.                                              |
| `domain(n=2)`                             | The hostname's first `n` segments, starting from the right (the TLD).            |
| `format`                                  | The content type requested by the client.                                        |
| `method`                                  | The HTTP method used for the request.                                            |
| `get?`, `post?`, `patch?`, `put?`, `delete?`, `head?` | Returns true if the HTTP method is GET/POST/PATCH/PUT/DELETE/HEAD.   |
| `headers`                                 | Returns a hash containing the headers associated with the request.               |
| `port`                                    | The port number (integer) used for the request.                                  |
| `protocol`                                | Returns a string containing the protocol used plus "://", for example "http://". |
| `query_string`                            | The query string part of the URL, i.e., everything after "?".                    |
| `remote_ip`                               | The IP address of the client.                                                    |
| `url`                                     | The entire URL used for the request.                                             |

#### `query_parameters`, `request_parameters`, and `path_parameters`

Rails collects all of the parameters for a given request in the `params` hash,
including the ones set in the URL as query string parameters, and those sent as
the body of a `POST` request. The request object has three methods that give you
access to the various parameters.

* [`query_parameters`][] - contains parameters that were sent as part of the
  query string.
* [`request_parameters`][] - contains parameters sent as part of the post body.
* [`path_parameters`][] - contains parameters parsed by the router as being part
  of the path leading to this particular controller and action.

[`path_parameters`]: https://api.rubyonrails.org/classes/ActionDispatch/Http/Parameters.html#method-i-path_parameters
[`query_parameters`]: https://api.rubyonrails.org/classes/ActionDispatch/Request.html#method-i-query_parameters
[`request_parameters`]: https://api.rubyonrails.org/classes/ActionDispatch/Request.html#method-i-request_parameters

### The `response` Object

The response object is built up during the execution of the action from
rendering data to be sent back to the client browser. It's not usually used
directly but sometimes, in an `after_action` callback for example, it can be
useful to access the response directly. One use case is for setting the content type header:

```ruby
response.content_type = "application/pdf"
```

Another use case is for setting custom response headers:

```ruby
response.headers["X-Custom-Header"] = "some value"
```

The `headers` attribute is a hash which maps header names to header values.
Rails sets some headers automatically but if you need to update a header or add
a custom header, you can use `response.headers` as in the example above.

NOTE: The `headers` method can be accessed directly in the controller as well.

Here are some of the properties of the `response` object:

| Property of `response` | Purpose                                                                                             |
| ---------------------- | --------------------------------------------------------------------------------------------------- |
| `body`                 | This is the string of data being sent back to the client. This is most often HTML.                  |
| `status`               | The HTTP status code for the response, like 200 for a successful request or 404 for file not found. |
| `location`             | The URL the client is being redirected to, if any.                                                  |
| `content_type`         | The content type of the response.                                                                   |
| `charset`              | The character set being used for the response. Default is "utf-8".                                  |
| `headers`              | Headers used for the response.                                                                      |

To get a full list of the available methods, refer to the [Rails API
documentation](https://api.rubyonrails.org/classes/ActionDispatch/Response.html)
and [Rack
Documentation](https://rack.github.io/rack/main/Rack/Response.html).
