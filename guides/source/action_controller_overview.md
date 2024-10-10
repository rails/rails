**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Action Controller Overview
==========================

In this guide, you will learn how controllers work and how they fit into the request cycle in your application.

After reading this guide, you will know how to:

* Follow the flow of a request through a controller.
* Restrict parameters passed to your controller.
* Store data in the session or cookies.
* Work with action callbacks to execute code during request processing.
* Use Action Controller's built-in HTTP authentication.
* Stream data directly to the user's browser.
* Filter sensitive parameters, so they do not appear in the application's log.
* Deal with exceptions that may be raised during request processing.
* Use the built-in health check end-point for load balancers and uptime monitors.

--------------------------------------------------------------------------------

Introduction
------------

Action Controller is the C in Model View Controller
([MVC](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93controller))
pattern. After the [router](routing.html) has matched a controller to an
incoming request, the controller is responsible for processing the request and
generating the appropriate output.

For most conventional
[RESTful](https://en.wikipedia.org/wiki/Representational_state_transfer)
applications, the controller will receive the request, fetch or save data from a
model, and use a view to create HTML output.

You can imagine that a controller sits between models and views. The controller
makes model data available to the view, so that the view can display that data
to the user. The controller also receives user input from the view and saves or
updates model data accordingly.

Creating a Controller
---------------------

A controller is a Ruby class which inherits from `ApplicationController` and has methods just like any other class. Once an incoming request is matched to a controller by the router, Rails creates an instance of that controller class and calls the method with the same name as the action.

```ruby
class ClientsController < ApplicationController
  def new
  end
end
```

Given the above `ClientsController`, if a user goes to `/clients/new` in your application to add a new client, Rails will create an instance of `ClientsController` and call its `new` method.

NOTE: The empty method from the example above would work because Rails will render the `new.html.erb` view by default.

In the `new` method, the controller would typically create an instance of the `Client` model, and make it available as an instance variable called `@client` in the view:

```ruby
def new
  @client = Client.new
end
```

NOTE: All controllers inherit from `ApplicationController`, which in turn inherits from [`ActionController::Base`](https://api.rubyonrails.org/classes/ActionController/Base.html).

### Controller Naming Convention

Rails favors making the last word in the controller's name plural. For example,
`ClientsController` is preferred over `ClientController` and
`SiteAdminsController` over `SiteAdminController` or `SitesAdminsController`.

NOTE: The plural names are not strictly required (e.g. `ApplicationController`).

Following this naming convention will allow you to use the [default route
generators](routing.html#crud-verbs-and-actions) (e.g. `resources`) without
needing to qualify each with options such as
[`:controller`](routing.html#specifying-a-controller-to-use). The convention
also makes named route helpers consistent throughout your application.

The controller naming convention is different from models. While plural
names are preferred for controller names, the singular form is preferred for
models names (e.g. `Account` vs. `Accounts`).

Controller actions should be `public`, as only `public` methods are callable as actions. It is also best practice to lower the visibility of helper methods (with `private` or `protected`) which are _not_ intended to be actions.

WARNING: Some method names are reserved by Action Controller. Accidentally redefining them could result in `SystemStackError`. If you limit your controllers to only RESTful [Resource Routing][] actions you should not need to worry about this.

NOTE: If you must use a reserved method as an action name, one workaround is to use a custom route to map the reserved method name to your non-reserved action method.

[Resource Routing]: routing.html#resource-routing-the-rails-default

Parameters
----------

Data provided by the user is available in your controller in the [`params`][] hash. There are two types of parameter data:

- Query string parameter which are sent as part of the URL (for example, after the `?` in `example.com/accounts?filter=free`).
- POST data which are submitted as from an HTML form.

Rails does not make a distinction between query string parameters and POST parameters; both are available in the `params` hash in your controller. For example:

```ruby
class ClientsController < ApplicationController
  # This action receives query string parameters from an HTTP GET request
  # at the URL "/clients?status=activated"
  def index
    if params[:status] == "activated"
      @clients = Client.activated
    else
      @clients = Client.inactivated
    end
  end

  # This action receives parameters from a POST request to "/clients" URL with # form data in the request body.
  def create
    @client = Client.new(params[:client])
    if @client.save
      redirect_to @client
    else
      render "new"
    end
  end
end
```

NOTE: The `params` hash is not a plain old Ruby Hash; instead, it is an [`ActionController::Parameters`][] object. While it behaves like Hash, it does not inherit from Hash.

[`params`]: https://api.rubyonrails.org/classes/ActionController/StrongParameters.html#method-i-params
[`ActionController::Parameters`]: https://api.rubyonrails.org/classes/ActionController/Parameters.html

### Hash and Array Parameters

The `params` hash is not limited to one-dimensional keys and values. It can
contain nested arrays and hashes. To send an array of values, append an empty
pair of square brackets "[]" to the key name:

```
GET /clients?ids[]=1&ids[]=2&ids[]=3
```

NOTE: The actual URL in this example will be encoded as
"/clients?ids%5b%5d=1&ids%5b%5d=2&ids%5b%5d=3" as the "[" and "]" characters are
not allowed in URLs. Most of the time you don't have to worry about this because
the browser will encode it for you, and Rails will decode it automatically, but
if you ever find yourself having to send those requests to the server manually
you should keep this in mind.

The value of `params[:ids]` will be the array `["1", "2", "3"]`. Note that
parameter values are always strings; Rails does not attempt to guess or cast the
type.

NOTE: Values such as `[nil]` or `[nil, nil, ...]` in `params` are replaced with
`[]` for security reasons by default. See [Security
Guide](security.html#unsafe-query-generation) for more information.

To send a hash, you include the key name inside the brackets:

```html
<form accept-charset="UTF-8" action="/clients" method="post">
  <input type="text" name="client[name]" value="Acme" />
  <input type="text" name="client[phone]" value="12345" />
  <input type="text" name="client[address][postcode]" value="12345" />
  <input type="text" name="client[address][city]" value="Carrot City" />
</form>
```

When this form is submitted, the value of `params[:client]` will be `{ "name" => "Acme", "phone" => "12345", "address" => { "postcode" => "12345", "city" => "Carrot City" } }`. Note the nested hash in `params[:client][:address]`.

The `params` object acts like a Hash, but lets you use symbols and strings interchangeably as keys.

### JSON Parameters

If your application exposes an API, you will likely accept parameters in JSON format. If the "Content-Type" header of your request is set to "application/json", Rails will automatically load your parameters into the `params` hash, which you can access as you would normally.

So for example, if you are sending this JSON content:

```json
{ "company": { "name": "acme", "address": "123 Carrot Street" } }
```

Your controller will receive `params[:company]` as `{ "name" => "acme", "address" => "123 Carrot Street" }`.

#### Configuring Wrap Parameters

You can [configure wrap parameters](configuring.html#config-action-controller-wrap-parameters-by-default) option if you want to omit the root element in the JSON parameters. It is `true` by default.

```ruby
config.action_controller.wrap_parameters_by_default = true
```

With this configuration, parameters will be cloned and wrapped with a key chosen based on your controller's name.

```json
{ "name": "acme", "address": "123 Carrot Street" }
```

Assuming that you're sending the data to `CompaniesController`, the above JSON would be wrapped within the `:company` key like this:

```ruby
{ name: "acme", address: "123 Carrot Street", company: { name: "acme", address: "123 Carrot Street" } }
```

You can customize the name of the key or specific parameters you want to wrap by consulting the [API documentation](https://api.rubyonrails.org/classes/ActionController/ParamsWrapper.html)

NOTE: Support for parsing XML parameters has been extracted into a gem named `actionpack-xml_parser`.

[`wrap_parameters`]: https://api.rubyonrails.org/classes/ActionController/ParamsWrapper/Options/ClassMethods.html#method-i-wrap_parameters

### Routing Parameters

Parameters specified as part of a route declaration in the `routes.rb` file are
also made available in the `params` hash.

For example, we can add a route that captures the `:status` parameter for a
client:

```ruby
get '/clients/:status', to: 'clients#index', foo: 'bar'
```

When a user navigates to `/clients/active` URL, `params[:status]` will be set to
"active". When this route is used, `params[:foo]` will also be set to "bar", as
if it were passed in the query string.

Any other parameters defined by the route declaration, such as `:id`, will also
be available.

NOTE: In the above example, your controller will also receive `params[:action]`
as "index" and `params[:controller]` as "clients". The `params` hash will always
contain the `:controller` and `:action` keys, but it's recommended to use the
methods [`controller_name`][] and [`action_name`][] instead to access these
values.

[`controller_name`]: https://api.rubyonrails.org/classes/ActionController/Metal.html#method-i-controller_name
[`action_name`]: https://api.rubyonrails.org/classes/AbstractController/Base.html#method-i-action_name

### Composite Key Parameters

[Composite key parameters](active_record_composite_primary_keys.html) contain
multiple values in one parameter separated by a delimiter. Therefore, you will
need extract each value so that you can pass them to Active Record. You can use
the `extract_value` do that.

For example, given the following controller:

```ruby
class BooksController < ApplicationController
  def show
    # Extract the composite ID value from URL parameters.
    id = params.extract_value(:id)
    @book = Book.find(id)
  end
end
```

And the this route:

```ruby
get '/books/:id', to: 'books#show'
```

When a user opens the URL `/books/4_2`, the controller will extract the
composite key value `["4", "2"]` and pass it to `Book.find`. The `extract_value`
method may be used to extract arrays out of any delimited parameters.

TODO: this section may not go here. Also test this out in code.

### The `default_url_options` Method

You can set global default parameters for [`url_for`]( https://api.rubyonrails.org/classes/ActionView/RoutingUrlFor.html#method-i-url_for) by defining a method called `default_url_options` in your controller. This method must return a hash with the desired defaults, whose keys must be symbols:

```ruby
class ApplicationController < ActionController::Base
  def default_url_options
    { locale: I18n.locale }
  end
end
```

These options will be used as a starting point when generating URLs. They can be overridden by the options passed to `url_for` calls.

If you define `default_url_options` in `ApplicationController`, as in the example above, these defaults will be used for all URL generation. The method can also be defined in a specific controller, in which case it only applies to URLs generated for that controller.

In a given request, the method is not actually called for every single generated URL. For performance reasons the returned hash is cached.

Strong Parameters
-----------------

With Action Controller [strong
parameters](https://api.rubyonrails.org/classes/ActionController/StrongParameters.html),
parameters cannot be used in Active Model mass assignments until they have been
explicitly permitted. This means you will need to decide which attributes to
permit for mass update and declare them in the controller. This is a security
practice to prevent users from accidentally updating sensitive model attributes.

In addition, parameters can be marked as required and the request will result in
a 400 Bad Request being returned if not all required parameters are passed in.

```ruby
class PeopleController < ActionController::Base

  # This will raise an ActiveModel::ForbiddenAttributesError exception
  # because it's using mass assignment without an explicit permit
  def create
    Person.create(params[:person])
  end

  # This will work as we are using `person_params` helper method, which has the
  # call to `permit` to allow mass assignment.
  def update
    person = Person.find(params[:id])
    person.update!(person_params)
    redirect_to person
  end

  private
    # Using a private method to encapsulate the permitted parameters is a good
    # pattern. you can use the same list for both create and update.
    def person_params
      params.require(:person).permit(:name, :age)
    end
end
```

### Permitting Values

Calling [`permit`][] allows the specified key (`:id` below) for inclusion if it
appears in `params`:

```ruby
params.permit(:id)
```

For the permitted key `:id`, its value also needs to be one of these
permitted scalar values: `String`, `Symbol`, `NilClass`, `Numeric`, `TrueClass`,
`FalseClass`, `Date`, `Time`, `DateTime`, `StringIO`, `IO`,
`ActionDispatch::Http::UploadedFile`, and `Rack::Test::UploadedFile`.

If you have not called `permit` on the key, it will be filtered out. Arrays,
hashes, or any other objects are not injected by default.

To include a value in `params` that's an array of one of the permitted scalar
values, you can map the key to an empty array like this:

```ruby
params.permit(id: [])
```

To include hash values, you can map to an empty hash:

```ruby
params.permit(options: {})
```

The above `permit` call ensures that values in `options` are permitted scalars
and filters out anything else. But be careful because the above opens the door
to arbitrary input. Sometimes it is not possible or convenient to declare each
valid key of a hash parameter or its internal structure.

There is also [`permit!`][] (with an `!`) which permits an entire hash of parameters without checking values.

```ruby
params.require(:log_entry).permit!
```

The above marks the `:log_entry` parameters hash and any sub-hash of it as
permitted and does not check for permitted scalars, anything is accepted.

WARNING: Extreme care should be taken when using `permit!`, as it will allow all
current and future model attributes to be mass-assigned.

[`permit`]: https://api.rubyonrails.org/classes/ActionController/Parameters.html#method-i-permit
[`permit!`]: https://api.rubyonrails.org/classes/ActionController/Parameters.html#method-i-permit-21

### Nested Parameters

You can use `permit` on more complex nested parameters. Here is an example followed by an explanation:

```ruby
params.permit(:name,
              { emails: [] },
              friends: [ :name, { family: [ :name ], hobbies: [] }])
```

This declaration permits the `name`, `emails`, and `friends` attributes. It is
expected that `emails` will be an array of permitted scalar values, and that
`friends` will be an array of resources with specific attributes.

The `friends` array should have a `name` attribute (any permitted scalar values
allowed), a `family` attribute which is restricted to having a `name`, and a
`hobbies` attribute as an array of permitted scalar values.

TODO: do something about the 1, 2, 3, 4.

### Examples

Here are some examples of how to use `permit` for different use cases.

1.
You may want to also use the permitted attributes in your `new`
action. This raises the problem that you can't use [`require`][] on the
root key because, normally, it does not exist when calling `new`:

```ruby
# using `fetch` you can supply a default and use
# the Strong Parameters API from there.
params.fetch(:blog, {}).permit(:title, :author)
```

2.
The model class method `accepts_nested_attributes_for` allows you to
update and destroy associated records. This is based on the `id` and `_destroy`
parameters:

```ruby
# permit :id and :_destroy
params.require(:author).permit(:name, books_attributes: [:title, :id, :_destroy])
```

3.
Hashes with integer keys are treated differently, and you can declare
the attributes as if they were direct children. You get these kinds of
parameters when you use `accepts_nested_attributes_for` in combination
with a `has_many` association:

```ruby
# To permit the following data:
# {"book" => {"title" => "Some Book",
#             "chapters_attributes" => { "1" => {"title" => "First Chapter"},
#                                        "2" => {"title" => "Second Chapter"}}}}

params.require(:book).permit(:title, chapters_attributes: [:title])
```

4.
Imagine a scenario where you have parameters representing a product
name, and a hash of arbitrary data associated with that product, and
you want to permit the product name attribute and also the whole
data hash:

```ruby
def product_params
  params.require(:product).permit(:name, data: {})
end
```

[`require`]: https://api.rubyonrails.org/classes/ActionController/Parameters.html#method-i-require

Cookies
-------

The concept of a cookie is not specific to Rails. A cookie (also known as an
HTTP cookie or a web cookie) is a small piece of data from the server that is
saved in the user's browser. The browser may store cookies, create new cookies,
modify existing ones, and send them back to the server with later requests.
Cookies persist data across web requests and therefore enable web applications
to remember user preferences.

Rails provides an easy way to access cookies via the [`cookies`][] method, which
works like a hash:

```ruby
class CommentsController < ApplicationController
  def new
    # Auto-fill the commenter's name if it has been stored in a cookie
    @comment = Comment.new(author: cookies[:commenter_name])
  end

  def create
    @comment = Comment.new(comment_params)
    if @comment.save
      if params[:remember_name]
        # Save the commenter's name in a cookie.
        cookies[:commenter_name] = @comment.author
      else
        # Delete cookie for the commenter's name, if any.
        cookies.delete(:commenter_name)
      end
      redirect_to @comment.article
    else
      render action: "new"
    end
  end
end
```

NOTE: To delete a cookie, you need to use `cookies.delete(:key)`. Setting the `key` to a `nil` value does not delete te cookie.

### Encrypted and Signed Cookies

Since cookies are stored on the client browser, they can be susceptible to
tampering and are not considered secure for storing sensitive data. Rails does
provide a signed cookie jar and an encrypted cookie jar for storing sensitive
data. The signed cookie jar appends a cryptographic signature on the cookie
values to protect their integrity. The encrypted cookie jar encrypts the values
in addition to signing them, so that they cannot be read by the user. Refer to
the [API
documentation](https://api.rubyonrails.org/classes/ActionDispatch/Cookies.html)
for more details.

These special cookie jars use a serializer to serialize the cookie values into
strings and deserialize them into Ruby objects when read back. You can specify
which serializer to use via [`config.action_dispatch.cookies_serializer`][]. The default serializer for new applications is `:json`.

NOTE: Be aware that JSON has limited support serializing Ruby objects suck as
`Date`, `Time`, and `Symbol`. These will be serialized and deserialized into
`String`s:

```ruby
class CookiesController < ApplicationController
  def set_cookie
    cookies.encrypted[:expiration_date] = Date.tomorrow # => Thu, 20 Mar 2014
    redirect_to action: 'read_cookie'
  end

  def read_cookie
    cookies.encrypted[:expiration_date] # => "2014-03-20"
  end
end
```

If you need to store these or more complex objects, you may need to manually
convert their values when reading them in subsequent requests.

If you use the cookie session store, the above applies to the `session` and
`flash` hash as well.

[`config.action_dispatch.cookies_serializer`]: configuring.html#config-action-dispatch-cookies-serializer
[`cookies`]: https://api.rubyonrails.org/classes/ActionController/Cookies.html#method-i-cookies

Session
-------

While cookies are stored client-side, session data is stored server-side (in
memory, a database, or a cache), and the duration is usually temporary and tied
to the user's session (e.g. until they close the browser). An example use case
for session is storing sensitive data like user authentication.

In a Rails application, the session is available in the controller and the view.

### Working With the Session

You can use the `session` instance method to access the session in your controllers. Session values are stored as key/value pairs like a hash:

```ruby
class ApplicationController < ActionController::Base
  private
    # Look up the key `:current_user_id` in the session and use it to
    # find the current `User`. This is a common way to handle user login in
    # a Rails application; logging in sets the session value and
    # logging out removes it.
    def current_user
      @current_user ||= User.find_by(id: session[:current_user_id]) if session[:current_user_id]
    end
end
```

To store something in the session, you can assign it to a key similar to adding a value to a hash. After a user is authenticated, its `id` is saved in the session to be used for subsequent requests:

```ruby
class SessionsController < ApplicationController
  def create
    if user = User.authenticate(params[:username], params[:password])
      session[:current_user_id] = user.id
      redirect_to root_url
    end
  end
end
```

To remove something from the session, delete the key/value pair. Deleting the `current_user_id` key from the session is a typical way to log the user out:

```ruby
class SessionsController < ApplicationController
  def destroy
    session.delete(:current_user_id)
    # Clear the current user as well
    @current_user = nil
    redirect_to root_url, status: :see_other
  end
end
```

It is possible to reset the entire session with [`reset_session`][]. It is recommended to use `reset_session` after logging in to avoid session fixation attacks. Please refer to the [Security Guide](https://edgeguides.rubyonrails.org/security.html#session-fixation-countermeasures) for details.

NOTE: Sessions are lazily loaded. If you don't access sessions in your action's code, they will not be loaded. Hence, you will never need to disable sessions, just not accessing them will do the job.

[`reset_session`]: https://api.rubyonrails.org/classes/ActionController/Metal.html#method-i-reset_session

### The Flash

The [flash](https://api.rubyonrails.org/classes/ActionDispatch/Flash.html)
provides a way to pass temporary data between actions. Anything you place in the
flash will be available to the very next action and then cleared. The flash is
typically used for setting messages (e.g. notices and alerts) in a controller
action before redirecting to an action that displays the message to the user.

The flash is accessed via the [`flash`][] method. Similar to the session, the
flash values are stored as key/value pairs.

For example, in the controller action for logging out a user, the controller can
set a flash message which can be displayed to the user on the next request:

```ruby
class SessionsController < ApplicationController
  def destroy
    session.delete(:current_user_id)
    flash[:notice] = "You have successfully logged out."
    redirect_to root_url, status: :see_other
  end
end
```

Displaying a message after a user performs some interactive action in your
application is a good practice to give the user feedback that their action was
successful (or that there were errors).

In addition to `:notice`, you can also set `:alert`. These are typically styled
(using CSS) with different colors to indicate their meaning (e.g. green for
notices and orange/red for alerts).

It is also possible to assign a flash message as part of the redirection as a
parameter to `redirect_to`:

```ruby
redirect_to root_url, notice: "You have successfully logged out."
redirect_to root_url, alert: "There was an issue."
redirect_to root_url, flash: { referral_code: 1234 }
```

You can set any key in a flash (similar to sessions); you're not limited to `notice` and `alert`:

```erb
<% if flash[:just_signed_up] %>
  <p class="welcome">Welcome to our site!</p>
<% end %>
```

In the above logout example, the `destroy` action redirects to the application's
`root_url`, where the message is available to be displayed. However, it's not
displayed automatically. It's up to the next action to decide what, if anything,
it will do with what the previous action put in the flash.

#### Displaying flash messages

If a previous action _has_ set a flash message, it's a good idea of display that to the user typically. We can accomplish this consistently by adding the HTML for displaying any flash messages in the application's default layout. Here's an example from `app/views/layouts/application.html.erb`:

```erb
<html>
  <!-- <head/> -->
  <body>
    <% flash.each do |name, msg| -%>
      <%= content_tag :div, msg, class: name %>
    <% end -%>

    <!-- more content -->
    <%= yield %>
  </body>
</html>
```

The `name` above indicates the type of flash message, such as `notice` or `alert`. This information is typically used to style how the message is displayed to the user.

TIP: You can filter by `name` if you want to limit to displaying only `notice` and `alert` in layout. Otherwise all keys set in the `flash` will be displayed.

Including the reading and displaying of flash messages in the layout ensures that your application will display these automatically, without each view having to include logic to read the flash.

#### `flash.keep` and `flash.now`

[`flash.keep`][] is used to carry over the flash value through to an addditioanl
request. This is useful when there are multiplle redirects.

For example, assume that the `index` action in the controller below corresponds
to the root_url. And you want all requests here to be redirected to
UsersController#index. If an action sets the flash and redirects to
MainController#index, those flash values will be lost when another redirect
happens, unless you use `flash.keep` to make the values persist for another request.

```ruby
class MainController < ApplicationController
    # Will persist all flash values.
    flash.keep

    # You can also use a key to keep only some kind of value.
    # flash.keep(:notice)
    redirect_to users_url
  end
end
```

[`flash.now`][] is used to make the flash values available in the same request.By default, adding values to the flash will make them available to the next request. For example, if the `create` action fails to save a resource, and you render the `new` template directly, that's not going to result in a new request, but you may still want to display a message using the flash. To do this, you can use [`flash.now`][] in the same way you use the normal `flash`:

```ruby
class ClientsController < ApplicationController
  def create
    @client = Client.new(client_params)
    if @client.save
      # ...
    else
      flash.now[:error] = "Could not save client"
      render action: "new"
    end
  end
end
```

[`flash`]: https://api.rubyonrails.org/classes/ActionDispatch/Flash/RequestMethods.html#method-i-flash
[`flash.keep`]: https://api.rubyonrails.org/classes/ActionDispatch/Flash/FlashHash.html#method-i-keep
[`flash.now`]: https://api.rubyonrails.org/classes/ActionDispatch/Flash/FlashHash.html#method-i-now

### Session Storage Options

All sessions have a unique Id that represents the session object; these Ids are stored in a cookie. The actual session objects use one of the following storage mechanisms:

* [`ActionDispatch::Session::CookieStore`][] - Stores everything on the client.
* [`ActionDispatch::Session::CacheStore`][] - Stores the data in the Rails cache.
* [`ActionDispatch::Session::ActiveRecordStore`][activerecord-session_store] -
  Stores the data in a database using Active Record (requires the
  [`activerecord-session_store`][activerecord-session_store] gem)
* A custom store or a store provided by a third party gem

For most session stores, the unique Id in the cookie is used to look up session data on the server (e.g. a database table). Rails does not allow you to pass the session ID in the URL as this is less secure.

The `CookieStore` is the default and recommended session store. It stores all session data in the cookie itself (the ID is still available to you if you need it). The cookie data is cryptographically signed to prevent tampering. It's also encrypted so anyone with access to it can't read its contents. The `CookieStore` is lightweight and does not require any configuration to use in a new application.

The `CookieStore`` can store 4 kB of data - much less than the other storage options - but this is usually enough. Storing large amounts of data in the session is discouraged. You should especially avoid storing complex objects (such as model instances) in the session.

You can use the `CacheStore` if your sessions don't store critical data or don't need to be around for long periods (for instance if you just use the flash for messaging). This will store sessions using the cache implementation you have configured for your application. The advantage of this is that you can use your existing cache infrastructure for storing sessions without requiring any additional setup or administration. The downside, of course, is that the sessions will be ephemeral and could disappear at any time.

Read more about session storage in the [Security Guide](security.html#sessions).

There are a few configuration options related to session storage. You can configure the type of storage in an initializer:

```ruby
Rails.application.config.session_store :cache_store
```

Rails sets up a session key (the name of the cookie) when signing the session data. These can also be changed in an initializer:

```ruby
Rails.application.config.session_store :cookie_store, key: '_your_app_session'
```

You can also pass a `:domain` key and specify the domain name for the cookie:

```ruby
Rails.application.config.session_store :cookie_store, key: '_your_app_session', domain: ".example.com"
```

NOTE: Be sure to restart your server when you modify an initializer file.

TIP: See [`config.session_store`](configuring.html#config-session-store) in the
configuration guide for more information.

Rails sets up a secret key for `CookieStore` used for signing the session data in `config/credentials.yml.enc`. The credentials can be updated with `bin/rails credentials:edit`.

```yaml
# aws:
#   access_key_id: 123
#   secret_access_key: 345

# Used as the base secret for all MessageVerifiers in Rails, including the one protecting cookies.
secret_key_base: 492f...
```

WARNING: Changing the secret_key_base when using the `CookieStore` will invalidate all existing sessions.

[`ActionDispatch::Session::CookieStore`]: https://api.rubyonrails.org/classes/ActionDispatch/Session/CookieStore.html
[`ActionDispatch::Session::CacheStore`]: https://api.rubyonrails.org/classes/ActionDispatch/Session/CacheStore.html
[activerecord-session_store]: https://github.com/rails/activerecord-session_store

Controller Callbacks
--------------------

Controller callbacks are methods that are defined to automatically run before
and/or after a controller action. A controller callback method can be defined in
a given controller or in the `ApplicationController`. Since all controllers
inherit from `ApplicationController`, callbacks defined here will run on every
controller in your application.

### `before_action`

Callback methods registered via [`before_action`][] run _before_ a controller
action. They may halt the request cycle. A common example use case for
`before_action` is ensuring that a user is logged in:

```ruby
class ApplicationController < ActionController::Base
  before_action :require_login

  private
    def require_login
      unless logged_in?
        flash[:error] = "You must be logged in to access this section"
        redirect_to new_login_url # halts request cycle
      end
    end
end
```

The method stores an error message in the flash and redirects to the login form
if the user is not already logged in. When a `before_action` callback renders or
redirects (like in the example above), the original controller action is not
run. If there are additional callbacks registered to run, they are also
cancelled and not run.

In this example, the `before_action` is defined in `Applicationcontroller` so
all controllers in the application inherit it. That implies that all requests in
the application will require the user to be logged in. This is fine except for
the "login" page. The "login" action should succeed even when the user is not
logged in (to allow the user to log in) otherwise the user will never be able to
log in. You can use [`skip_before_action`][] to allow specified controller
actions to skip a given `before_action`:

```ruby
class LoginsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]
end
```

Now, the `LoginsController`'s `new` and `create` actions will work without
requiring the user to be logged in.

The `:only` option skips the callback only for the listed actions; there is also
an `:except` option which works the other way. These options can be used when
registering action callbacks too, to add callbacks which only runs for selected
actions.

NOTE: If you register the same action callback multiple times with different
options, the last action callback definition will overwrite the previous ones.

[`before_action`]: https://api.rubyonrails.org/classes/AbstractController/Callbacks/ClassMethods.html#method-i-before_action
[`skip_before_action`]: https://api.rubyonrails.org/classes/AbstractController/Callbacks/ClassMethods.html#method-i-skip_before_action

### `after_action` and `around_action`

You can also define action callbacks to run _after_ a controller action has been executed with [`after_action`][], or to run both before and after with `around_action`][].

The `after_action` callbacks are similar to `before_action`callbacks, but because the controller action has already been run they have access to the response data that's about to be sent to the client.

NOTE: `after_action` callbacks are executed only after a successful controller action, and not if an exception is raised in the request cycle.

The `around_action` callbacks are useful when you want to execute code before and after a controller action, allowing you to encapsulate functionality that affects the action's execution. They are responsible for running their associated actions by yielding.

For example, imagine you want to monitor the performance of specific actions. You could use an `around_action` to measure how long each action takes to complete and log this information:

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

TIP: Action callbacks receive `controller_name` and `action_name` as parameters you can use, as shown in the example above.

The `around_action` callback also wraps rendering. In the example above, view rendering will be included in the time. The code after the `yield` in an `around_action` is run even when there is an exception in the associated action and there is an `ensure` block in the callback. (This is different from `after_action` callbacks where exception in the action cancels the `after_action` code.)

[`after_action`]: https://api.rubyonrails.org/classes/AbstractController/Callbacks/ClassMethods.html#method-i-after_action
[`around_action`]: https://api.rubyonrails.org/classes/AbstractController/Callbacks/ClassMethods.html#method-i-around_action

### Other Ways to Use Callbacks

In addition to `before_action`, `after_action`, or `around_action`, which are more common, there are two other ways to register callbacks.

The first is to use a block directly with the `*_action` methods. The block receives the controller as an argument. For example, the `require_login` action callback from above could be rewritten to use a block:

```ruby
class ApplicationController < ActionController::Base
  before_action do |controller|
    unless controller.send(:logged_in?)
      flash[:error] = "You must be logged in to access this section"
      redirect_to new_login_url
    end
  end
end
```

Note that the action callback, in this case, uses `send` because the `logged_in?` method is private, and the action callback does not run in the scope of the controller. This is not the recommended way to implement this particular action callback, but in simpler cases, it might be useful.

Specifically for `around_action`, the block also yields in the `action`:

```ruby
around_action { |_controller, action| time(&action) }
```

The second way is to specify a class (or any object that responds to the expected methods) for the callback action. This can be useful in cases that are more complex. As an example, you could rewrite the login action callback with a class:

```ruby
class ApplicationController < ActionController::Base
  before_action LoginActionCallback
end

class LoginActionCallback
  def self.before(controller)
    unless controller.send(:logged_in?)
      controller.flash[:error] = "You must be logged in to access this section"
      controller.redirect_to controller.new_login_url
    end
  end
end
```

The above is not an ideal example. The `LoginActionCallback` method is not run in the scope of the controller but gets `controller` as an argument.

In general, the class being used for a `*_action` callback must implement a method with the same name as the action callback. So for the `before_action` action callback, the class must implement a `before` method, and so on. Also, the `around` method must `yield` to execute the action.

The Request and Response Objects
--------------------------------

Every controller has two methods, [`request`][] and [`response`][],
which can be used to access the request object and the response objects
associated with the current request cycle. The `request` method returns an
instance of [`ActionDispatch::Request`][]. The [`response`][] method returns an
object representing what is going to be sent back to the client (e.g. from `render` or `redirect` in the controller action).

[`ActionDispatch::Request`]: https://api.rubyonrails.org/classes/ActionDispatch/Request.html
[`request`]: https://api.rubyonrails.org/classes/ActionController/Base.html#method-i-request
[`response`]: https://api.rubyonrails.org/classes/ActionController/Base.html#method-i-response

### The `request` Object

The request object contains a lot of useful information about the request coming in from the client. To get a full list of the available methods, refer to the [Rails API documentation](https://api.rubyonrails.org/classes/ActionDispatch/Request.html) and [Rack Documentation](https://www.rubydoc.info/github/rack/rack/Rack/Request). Among the properties that you can access on this object are:

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

Rails collects all of the parameters for a given request in the `params` hash, including the ones set in the URL as query string parameters, and those sent as the body of a `POST` request. The request object has three methods that give you access to the various parameters. 

* [`query_parameters`][] - contains parameters that were sent as part of the query string.
* [`request_parameters`][] - contains parameters sent as part of the post body. * [`path_parameters`][] - contains parameters parsed by the router as being part of the path leading to this particular controller and action.

[`path_parameters`]: https://api.rubyonrails.org/classes/ActionDispatch/Http/Parameters.html#method-i-path_parameters
[`query_parameters`]: https://api.rubyonrails.org/classes/ActionDispatch/Request.html#method-i-query_parameters
[`request_parameters`]: https://api.rubyonrails.org/classes/ActionDispatch/Request.html#method-i-request_parameters

### The `response` Object

The response object is not usually used directly, but is built up during the execution of the action and rendering of the data that is being sent back to the user, but sometimes - like in an after action callback - it can be useful to access the response directly. Some of these accessor methods also have setters, allowing you to change their values. To get a full list of the available methods, refer to the [Rails API documentation](https://api.rubyonrails.org/classes/ActionDispatch/Response.html) and [Rack Documentation](https://www.rubydoc.info/github/rack/rack/Rack/Response).

| Property of `response` | Purpose                                                                                             |
| ---------------------- | --------------------------------------------------------------------------------------------------- |
| `body`                 | This is the string of data being sent back to the client. This is most often HTML.                  |
| `status`               | The HTTP status code for the response, like 200 for a successful request or 404 for file not found. |
| `location`             | The URL the client is being redirected to, if any.                                                  |
| `content_type`         | The content type of the response.                                                                   |
| `charset`              | The character set being used for the response. Default is "utf-8".                                  |
| `headers`              | Headers used for the response.                                                                      |

#### Setting Custom Headers

If you want to set custom headers for a response then `response.headers` is the place to do it. The headers attribute is a hash which maps header names to their values, and Rails will set some of them automatically. If you want to add or change a header, just assign it to `response.headers` this way:

```ruby
response.headers["Content-Type"] = "application/pdf"
```

NOTE: In the above case it would make more sense to use the `content_type` setter directly.

Rescue
------

Most likely your application is going to contain bugs or otherwise throw an exception that needs to be handled. For example, if the user follows a link to a resource that no longer exists in the database, Active Record will throw the `ActiveRecord::RecordNotFound` exception.

Rails default exception handling displays a "500 Server Error" message for all exceptions. If the request was made locally, a nice traceback and some added information gets displayed, so you can figure out what went wrong and deal with it. If the request was remote Rails will just display a simple "500 Server Error" message to the user, or a "404 Not Found" if there was a routing error, or a record could not be found. Sometimes you might want to customize how these errors are caught and how they're displayed to the user. There are several levels of exception handling available in a Rails application:

### The Default 500 and 404 Templates

By default, in the production environment the application will render either a 404, or a 500 error message. In the development environment all unhandled exceptions are simply raised. These messages are contained in static HTML files in the public folder, in `404.html` and `500.html` respectively. You can customize these files to add some extra information and style, but remember that they are static HTML; i.e. you can't use ERB, SCSS, CoffeeScript, or layouts for them.

### `rescue_from`

If you want to do something a bit more elaborate when catching errors, you can use [`rescue_from`][], which handles exceptions of a certain type (or multiple types) in an entire controller and its subclasses.

When an exception occurs which is caught by a `rescue_from` directive, the exception object is passed to the handler. The handler can be a method or a `Proc` object passed to the `:with` option. You can also use a block directly instead of an explicit `Proc` object.

Here's how you can use `rescue_from` to intercept all `ActiveRecord::RecordNotFound` errors and do something with them.

```ruby
class ApplicationController < ActionController::Base
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  private
    def record_not_found
      render plain: "404 Not Found", status: 404
    end
end
```

Of course, this example is anything but elaborate and doesn't improve on the default exception handling at all, but once you can catch all those exceptions you're free to do whatever you want with them. For example, you could create custom exception classes that will be thrown when a user doesn't have access to a certain section of your application:

```ruby
class ApplicationController < ActionController::Base
  rescue_from User::NotAuthorized, with: :user_not_authorized

  private
    def user_not_authorized
      flash[:error] = "You don't have access to this section."
      redirect_back(fallback_location: root_path)
    end
end

class ClientsController < ApplicationController
  # Check that the user has the right authorization to access clients.
  before_action :check_authorization

  # Note how the actions don't have to worry about all the auth stuff.
  def edit
    @client = Client.find(params[:id])
  end

  private
    # If the user is not authorized, just throw the exception.
    def check_authorization
      raise User::NotAuthorized unless current_user.admin?
    end
end
```

WARNING: Using `rescue_from` with `Exception` or `StandardError` would cause serious side-effects as it prevents Rails from handling exceptions properly. As such, it is not recommended to do so unless there is a strong reason.

NOTE: When running in the production environment, all
`ActiveRecord::RecordNotFound` errors render the 404 error page. Unless you need
a custom behavior you don't need to handle this.

NOTE: Certain exceptions are only rescuable from the `ApplicationController` class, as they are raised before the controller gets initialized, and the action gets executed.

[`rescue_from`]: https://api.rubyonrails.org/classes/ActiveSupport/Rescuable/ClassMethods.html#method-i-rescue_from
