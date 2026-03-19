**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Layouts and Rendering in Rails
==============================

This guide covers the rendering features of Action Controller and its relationship with Action View.

After reading this guide, you will know:

* How to use the various rendering methods built into Rails.
* How to render views in multiple formats and variants.
* How to send HTTP redirect responses.
* How to set the layout in Rails controllers.

--------------------------------------------------------------------------------

Introduction
------------

This guide focuses on the relationship between the **Controller** and the **View**, and the process of rendering a response to send back to the client. It assumes a basic understanding of [HTTP requests and responses](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Overview), [Action View](action_view_overview.html), [Rails controller conventions](action_controller_overview.html), and [Rails routing](routing.html).

The controller is responsible for orchestrating how an HTTP request is handled in Rails. It reads the parameters from an incoming request, then hands off to the model layer for any complex business logic. Finally, it hands off to the view to send a response back to the user.

There are four ways to create an HTTP response in a Rails controller:

* [`render`][controller.render] to create a full response with a body, usually with a `2xx` status code.
* [`redirect_to`][] to redirect the user to another path using an HTTP redirect status code.
* [`respond_to`][] to enable rendering of multiple formats based on the HTTP request's `Accept` header.
* [`head`][] to create a response consisting solely of HTTP headers without a body.

[controller.render]: https://api.rubyonrails.org/classes/ActionController/Rendering.html#method-i-render
[`redirect_to`]: https://api.rubyonrails.org/classes/ActionController/Redirecting.html#method-i-redirect_to
[`head`]: https://api.rubyonrails.org/classes/ActionController/Head.html#method-i-head
[`respond_to`]: https://api.rubyonrails.org/classes/ActionController/MimeResponds.html#method-i-respond_to

`render`ing Responses
---------------------

The majority of responses in your Rails application will likely be created using the [`render`][controller.render] method. It's used to create a fully-formed response with a body which usually contains an HTML document.

### The Basics

Consider the below controller class and the route pointing to it. We also have a view for the `index` action.

```ruby
# app/controllers/books_controller.rb

class BooksController < ApplicationController
end
```

```ruby
# config/routes.rb

resources :books
```

```html+erb
<%# app/views/books/index.html.erb -%>

<h1>Books are coming soon!</h1>
```

Navigating to `/books` will render the heading "Books are coming soon!". This works due to Rails conventions. We don't even need to define an `index` method in the controller — it is implicit.

Next, we define the `index` action and load all `Book` records from our database to render in the view.

```ruby
class BooksController < ApplicationController
  def index
    @books = Book.all
  end
end
```

The view to display all the books might look like:

```html+erb
<h1>Books</h1>

<table>
  <thead>
    <tr>
      <th>Name</th>
      <th>Synopsis</th>
      <th colspan="3"></th>
    </tr>
  </thead>

  <tbody>
    <% @books.each do |book| %>
      <tr>
        <td><%= book.name %></td>
        <td><%= book.synopsis %></td>
        <td><%= link_to "Show", book %></td>
        <td><%= link_to "Edit", edit_book_path(book) %></td>
        <td><%= link_to "Destroy", book, data: { turbo_method: :delete, turbo_confirm: "Are you sure?" } %></td>
      </tr>
    <% end %>
  </tbody>
</table>

<br>

<%= link_to "New book", new_book_path %>
```

We'll now see this table at `/books`. We don't need to explicitly call `render` in the action. The `index` action implicitly renders the `index.html.erb` template.

### Rendering Templates

When you want to render a different template within a controller action, or set the HTTP response code, you'll need to explicitly call `render`.

```ruby
def update
  @book = Book.find(params[:id])
  if @book.update(book_params)
    redirect_to @book
  else
    render "edit", status: :unprocessable_content
  end
end
```

You can also use a symbol instead of a string to specify the name of the template:

```ruby
render :edit, status: :unprocessable_content
```

If you wish to be more explicit, you can use the `action:` option:

```ruby
render action: :edit, status: :unprocessable_content
```

NOTE: We render with the HTTP status `303 Unprocessable Content` in the above example since it's the idiomatically correct HTTP response code for a form submission error. It's also required by the [Turbo](https://turbo.hotwired.dev) JavaScript library which Rails includes by default.

To render a template which belongs to a different controller, you can use its relative path from the `app/views/` directory. For example, to render `app/views/products/show.html.erb` from the `BooksController`, you'd invoke:

```ruby
render "products/show"
```

Optionally, you can include the `template:` keyword argument:

```ruby
render template: "products/show"
```

### Template Lookup Hierarcy

When there isn't an explicit call to `render`, Rails follows the controller's inheritance chain to find the appropriate template. Consider the below controllers:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
end

# app/controllers/admin_controller.rb
class AdminController < ApplicationController
end

# app/controllers/admin/products_controller.rb
class Admin::ProductsController < AdminController
  def index
  end
end
```

The lookup order for an `admin/products#index` action will be:

* `app/views/admin/products/index.html.erb`
* `app/views/admin/index.html.erb`
* `app/views/application/index.html.erb`

### Inline `render`ing

The `render` method can be used to define the response body within the controller itself. This technique can be used to render reponses in a variety of formats such as _plain text_, _JSON_, _XML_ etc.

A key difference when rendering inline is that the response is rendered without a [layout](action_view_overview.html#layouts) by default. For HTML and plain text responses, you can use the `layout:` option to explicity define a layout template; but, all other formats have [custom renderers](https://github.com/rails/rails/blob/main/actionpack/lib/action_controller/metal/renderers.rb#L169) which don't incorporate a layout.

Let's look at some examples to understand what this means.

#### HTML

Use the `html:` option to render an HTML string inline.

```ruby
render html: helpers.tag.strong("Not Found")
```

The response will be rendered without a layout by default. Use the `layout:` option render within a layout template:

```ruby
# Renders within the default layout for the controller, usually: `app/views/layouts/application.html.erb`.
render html: helpers.tag.strong("Not Found"), layout: true

# Explitly define rendering within the `app/views/layouts/admin.html.erb` layout template.
render html: helpers.tag.strong("Not Found"), layout: "admin"
```

NOTE: There's rarely a good reason to do this in practice. Use a template file to render HTML responses.

WARNING: When using `html:` option, HTML entities will be escaped if the string is not composed with `html_safe`-aware APIs.

#### Plain Text

You can send plain text - with no markup at all - back to the browser:

```ruby
render plain: "OK"
```

To wrap this response in layout, you'll need a `.text.erb` layout file and then use the `layout:` option:

```ruby
# Inserts the text "OK" into the controller's default layout, usually:
# `app/views/layouts/application.text.erb`
render plain: "OK", layout: true

# Inserts the text "OK" into `app/views/layouts/plain_text_wrapper.text.erb`
render plain: "OK", layout: "plain_text_wrapper"
```

TIP: Rendering text is most useful when you're responding to Ajax or web service requests that are expecting something other than HTML.

#### JSON

Use the `json:` option to format JSON reponses. It will automatically call `to_json` on any object passed into it.

```ruby
render json: @product
```

#### XML

XML can be rendered with the `xml:` option. Any object passed in will be converted to XML using `to_xml`

```ruby
render xml: @product
```

#### Raw Body

You can create a response using a raw string using the `body:` option:

```ruby
render body: "raw"
```

WARNING: There's unlikely to be a practical scenario where this option fits the bill.
Use one of the alternate rendering options such as JSON or XML to create stucturally sound reponses
and all the security benefits that come with it.

#### Files

Rails can render a file from an absolute path. This is useful for rendering static files like error pages. ERB and other templating engines are not supported.

```ruby
render file: "#{Rails.root}/public/404.html"
```

If a layout file matching the file's format exists, it will be rendered within that layout by default. For example, the above example will render the `404.html` page within the `app/views/layouts/application.html.erb` layout. This can be disabled using `layout: false`:

```ruby
render file: "#{Rails.root}/public/404.html", layout: false
```

WARNING: Using the `:file` option in combination with users input can lead to security problems
since an attacker could use this action to access security sensitive files in your file system.

TIP: [`send_file`](action_controller_advanced_topics.html#sending-files) is often a faster and better option if a layout isn't required.

#### Rendering Objects

Rails can render objects responding to `render_in`. The format is defined by a `format` method on the object.

```ruby
class Greeting
  include ActionView::Helpers::TagHelper

  def render_in(view_context)
    view_context.render html: tag.h1("Hello, world")
  end

  def format
    :html
  end
end
```

Render the above object in a controller action using:

```ruby
render Greeting.new
```

This calls `render_in` on the provided object with the current [view context][]. You can specify the `renderable:` option to be more explicit:

```ruby
render renderable: Greeting.new
```

[view context]: https://api.rubyonrails.org/classes/ActionView/Base.html

#### Inline Templating

ERB or a similar templating string can be rendered inline using the `inline:` option:

```ruby
render inline: "<% products.each do |p| %><p><%= p.name %></p><% end %>"
```

Supply `type:` to use other templating engines:

```ruby
render inline: "xml.p 'This is a bad idea...'", type: :builder
```

```ruby
render inline: "json.content 'This is a bad idea...'", type: :jbuilder
```

WARNING: There is seldom any good reason to use this technique. Mixing templating logic into your controllers defeats the MVC orientation of Rails and will make it harder for other developers to follow the logic of your project. Use a separate view instead.

### Customizing Responses

HTTP responses can be customized by passing additional options to [`render`][controller.render].

#### `content_type:`

This sets the [`content-type`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Type) HTTP header for the response. It needs to be set to a valid [MIME type](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/MIME_types/Common_types) so the browser understands how the response is formatted.

Rails automatically sets this in most cases. For example, rendering an HTML ERB template will set it to `text/html`, and rendering a JSON object will set it to `application/json`.

It can be explicity set if needed:

```ruby
render template: "feed", content_type: "application/rss"
```

#### `location:`

Use this option to set the HTTP [`Location`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Location) header:

```ruby
render plain: "Redirecting...", location: root_path, status: :see_other
```

WARNING:  While this is valid code, using [`redirect_to`](#redirecting-requests) is the canonical way to send redirect responses in Rails.

#### `status:`

Rails automatically sets the HTTP status code — in most cases, this is `200 OK`. Change it by supplying a `status:`:

```ruby
render status: 500
render status: :forbidden
```

Rails understands both numeric status codes and the corresponding symbols shown below.

| Response Class      | HTTP Status Code | Symbol                           |
| ------------------- | ---------------- | -------------------------------- |
| **Informational**   | 100              | :continue                        |
|                     | 101              | :switching_protocols             |
|                     | 102              | :processing                      |
|                     | 103              | :early_hints                     |
| **Success**         | 200              | :ok                              |
|                     | 201              | :created                         |
|                     | 202              | :accepted                        |
|                     | 203              | :non_authoritative_information   |
|                     | 204              | :no_content                      |
|                     | 205              | :reset_content                   |
|                     | 206              | :partial_content                 |
|                     | 207              | :multi_status                    |
|                     | 208              | :already_reported                |
|                     | 226              | :im_used                         |
| **Redirection**     | 300              | :multiple_choices                |
|                     | 301              | :moved_permanently               |
|                     | 302              | :found                           |
|                     | 303              | :see_other                       |
|                     | 304              | :not_modified                    |
|                     | 305              | :use_proxy                       |
|                     | 307              | :temporary_redirect              |
|                     | 308              | :permanent_redirect              |
| **Client Error**    | 400              | :bad_request                     |
|                     | 401              | :unauthorized                    |
|                     | 402              | :payment_required                |
|                     | 403              | :forbidden                       |
|                     | 404              | :not_found                       |
|                     | 405              | :method_not_allowed              |
|                     | 406              | :not_acceptable                  |
|                     | 407              | :proxy_authentication_required   |
|                     | 408              | :request_timeout                 |
|                     | 409              | :conflict                        |
|                     | 410              | :gone                            |
|                     | 411              | :length_required                 |
|                     | 412              | :precondition_failed             |
|                     | 413              | :content_too_large               |
|                     | 414              | :uri_too_long                    |
|                     | 415              | :unsupported_media_type          |
|                     | 416              | :range_not_satisfiable           |
|                     | 417              | :expectation_failed              |
|                     | 421              | :misdirected_request             |
|                     | 422              | :unprocessable_content           |
|                     | 423              | :locked                          |
|                     | 424              | :failed_dependency               |
|                     | 426              | :upgrade_required                |
|                     | 428              | :precondition_required           |
|                     | 429              | :too_many_requests               |
|                     | 431              | :request_header_fields_too_large |
|                     | 451              | :unavailable_for_legal_reasons   |
| **Server Error**    | 500              | :internal_server_error           |
|                     | 501              | :not_implemented                 |
|                     | 502              | :bad_gateway                     |
|                     | 503              | :service_unavailable             |
|                     | 504              | :gateway_timeout                 |
|                     | 505              | :http_version_not_supported      |
|                     | 506              | :variant_also_negotiates         |
|                     | 507              | :insufficient_storage            |
|                     | 508              | :loop_detected                   |
|                     | 510              | :not_extended                    |
|                     | 511              | :network_authentication_required |

NOTE: The mapping between the codes and symbols is [defined within Rack](https://github.com/rack/rack/blob/main/lib/rack/utils.rb#L498). If you try to render content along with a non-content status code (100-199, 204, 205, or 304), it will be dropped from the response.

### Avoiding Double Render Errors

The `render` method **does not** `return` from the current scope. Lines after a `render` call will still be executed. Calling `render` multiple times in the same controller action is not allowed and will raise a `AbstractController::DoubleRenderError`.

For example, this action will trigger a double render error:

```ruby
def index
  @books = Book.all
  if Current.user.admin?
    render "admin/books/index"
  end

  render "index"
end
```

If the user is an admin, the `render` within the `if` statement will be called, but so will `render "index"`.

You can fix this by adding an explicit `return`:

```ruby
def index
  @books = Book.all
  if Current.user.admin?
    return render "admin/books/index"
  end

  render "index"
end
```

Or by using an `else` branch:

```ruby
def index
  @books = Book.all
  if Current.user.admin?
    render "admin/books/index"
  else
    render "index"
  end
end
```

Implicit rendering is unaffected by this. The controller action will only render the conventional template if `render` wasn't called when the action executed. The below example will not raise a double render error and is functionally equivalent to the previous example.

```ruby
def index
  @books = Book.all
  if Current.user.admin?
    render "admin/books/index"
  end
end
```

Multi-Format Responses
----------------------

Rails templates [can be written in a variety of formats](action_view_overview.html#templates), not just HTML. For example, consider the below JSON and XML templates:

```ruby
# app/views/books/index.json.jbuilder

json.array! @books do |book|
  json.name(book.name)
  json.synopsis(book.synopsis)
end
```

```erb
<%# app/views/books/index.xml.erb -%>

<books>
  <% @books.each do |book| %>
  <book>
    <name><%= book.name %></name>
    <synopsis><%= book.synopsis %></synopsis>
  </book>
  <% end %>
</books>
```

NOTE: In these examples, we're building the JSON template using [`jbuilder`](action_view_overview.html#jbuilder) for security and convenience, but still using ERB for the XML template. Rails also includes [`builder`](action_view_overview.html#builder), which provides a DSL to create XML templates if you wish to use it.

These templates can co-exist alongside an HTML ERB template:

```html+erb
<%# app/views/books/index.html.erb -%>

<h1>Books</h1>

<table>
  <thead>
    <tr>
      <th>Name</th>
      <th>Synopsis</th>
    </tr>
  </thead>

  <tbody>
    <% @books.each do |book| %>
    <tr>
      <td><%= book.name %></td>
      <td><%= book.synopsis %></td>
    </tr>
    <% end %>
  </tbody>
</table>
```

This means there are 3 template formats available for the `index` action on the `BooksController`. Without an explicit `render`, Rails will automatically choose the correct format based on the request.

The request can control the response format by specifying an `Accept` HTTP header with the appropriate [MIME type](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/MIME_types/Common_types):

```
GET /books.json HTTP/1.1
Accept: application/json
```

or it can set an extension on the path:

```
/books.json
/books.xml
```

The default format is HTML. For more fine-grained control over formats, Rails controllers offer two methods:

* Supplying `formats:` when calling `render`.
* Using `respond_to`.

### The `formats:` option

The `formats:` option on `render` overrides any definitions in the request and forces the controller to render the specified format:

```ruby
render formats: :json
```

An array can be passed to define fallbacks if the template for a given format doesn't exist. The below example will attempt to render the JSON template, but fallback to XML if it doesn't exist.

```ruby
render formats: [:json, :xml]
```

An `ActionView::MissingTemplate` error is raised when a template with the required format doesn't exist.

### Advanced Format Handling Using `respond_to`

[`respond_to`][] explicitly defines the formats available to the controller.

```ruby
class BooksController < ApplicationController
  def index
    @books = Book.all

    respond_to :html, :xml, :json
  end
end
```

The above is functionally equivalent to an implicit render when templates for all 3 formats exist:

```ruby
class BooksController < ApplicationController
  def index
    @books = Book.all
  end
end
```

It can also be expressed using a block:

```ruby
class BooksController < ApplicationController
  def index
    @books = Book.all

    respond_to do |format|
      format.html
      format.json
      format.xml
    end
  end
end
```

The above 3 code snippets are functionally equivalent. However, within this block structure, you can define custom handling for each format. For example, you might want to render a different template for HTML requests:

```ruby
class BooksController < ApplicationController
  def index
    @books = Book.all

    respond_to do |format|
      format.html { render "carousel" }
      format.json
      format.xml
    end
  end
end
```

HTML requests will render `carousel.html.erb`, whereas JSON and XML requests will render `index.json.jbuilder` and `index.xml.erb` respectively.

You can even redirect requests based on the format:

```ruby
class BooksController < ApplicationController
  def index
    @books = Book.all

    respond_to do |format|
      format.html { redirect_to books_grid_path }
      format.json
      format.xml
    end
  end
end
```

Now requests for HTML pages will be redirected, but JSON and XML requests will be rendered.

You can create a handler for multiple formats using `format.any`:

```ruby
class BooksController < ApplicationController
  def index
    @books = Book.all

    respond_to do |format|
      format.html { redirect_to books_grid_path }
      format.any(:xml, :json)
    end
  end
end
```

Omit the format definitions passed to `format.any` to create a catch-all handler. The below example will redirect HTML requests and render the appropriate `index` template for all other request types, where available.

```ruby
class BooksController < ApplicationController
  def index
    @books = Book.all

    respond_to do |format|
      format.html { redirect_to books_grid_path }
      format.any
    end
  end
end
```

If the requested format isn't available when using `respond_to`, Rails will respond with the HTTP status `406 Not Acceptable`.

### Template Variants

Rails allows you to create multiple variants of the same template. Controllers responding to requests from a mobile platform might need to render different content than requests from a desktop browser. One strategy to accomplish this is to set a request variant.

Variant names are arbitrary, and can communicate anything from the request's platform (`:android`, `:ios`, `:linux`, `:macos`, `:windows`) to its device (`:mobile`, `:desktop`), to the type of user (`:admin`, `:guest`, `:user`).

The variant name is included in the file's extension.

- `app/views/books/index.html+mobile.erb`
- `app/views/books/index.html+desktop.erb`
- `app/views/books/index.html.erb`

Render a variant using the `variants:` option.

```ruby
class BooksController < ApplicationController
  def index
    @books = Book.all

    # `variants:` accepts a single symbol or an array of symbols
    render variants: [:mobile, :desktop]
  end
end
```

Rails will render the first available template variant from the array supplied, falling back to the default `.html.erb` if no matching variant is found.

Rails automatically renders the appropriate variant when [`request.variant`](https://api.rubyonrails.org/classes/ActionDispatch/Http/MimeNegotiation.html#method-i-variant-3D) is set. It's a good idea to add the logic to set the variant to your `ApplicationController` so all your controllers get this functionality. Rails will always render the default template so variants can be added only where necessary.


```ruby
# app/controllers/concerns/set_request_variant.rb
module SetRequestVariant
  extend ActiveSupport::Concern

  included do
    before_action :set_request_variant
  end

  private

    def set_request_variant
      # App-specific logic to determine which variant is requested
      request.variant = # ...
    end
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include SetRequestVariant
end

# app/controllers/books_controller.rb
class BooksController < ApplicationController
  def index
    @books = Book.all
  end
end
```

An explicit `render variants:` call isn't required when using `request.variant`.

You can add custom handling for variants within a `respond_to` block:

```ruby
respond_to do |format|
  format.html do |html|
    html.desktop { render "dashboard" }
    html.mobile
  end
  format.json
  format.xml
end
```

```ruby
respond_to do |format|
  format.html.desktop { render "dashboard" }
  format.html
  format.json
  format.xml
end
```

### Custom MIME types

Rails registers several common [MIME types](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/MIME_types) [by default](https://github.com/rails/rails/blob/main/actionpack/lib/action_dispatch/http/mime_types.rb). All these types can be used to in conjunction with `respond_to`. Your application can additionally define custom MIME types.

```ruby
# config/initializers/mime_types.rb

Mime::Type.register "text/vnd.my-mime-type", :my_mime_type
```

The above definition follows the convention for naming custom MIME types. This can now be used to render responses:

```ruby
respond_to do |format|
  format.my_mime_type { render plain: "This is a custom MIME type" }
  format.any
end
```

Even though we're using `render plain:`, the `content-type` HTTP header in the response will be set to `text/vnd.my-mime-type` since it's a format-specific handler.

NOTE: This is exactly how [Rails' integration](https://github.com/hotwired/turbo-rails) with [Turbo](https://turbo.hotwired.dev) creates Turbo Stream responses. It registers the `text/vnd.turbo-stream.html` MIME type which allows us to create `.turbo_stream.html` templates and use `format.turbo_stream` in `respond_to` blocks.

Redirecting Requests
--------------------

Instead of `render`ing a response, you might want to redirect the user to a different path. An [HTTP redirection status code](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status#redirection_messages) can be used for this. Rails' [`redirect_to`][] method uses `302 Found` by default.

```ruby
redirect_to photos_url
```

This will send a `302` HTTP response to the browser with `photos_url` in the response's `Location` header. The browser will then make a new `GET` request to the `photos_url`.

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

Use the `status:` option to use a different HTTP response code. Just like `render`, you can use both numeric and symbolic values.

```ruby
redirect_to photos_path, status: :see_other
```

NOTE: It's worth being aware that `redirect_to` doesn't move execution to a different method within the same request. It sends an HTTP response and then the browser makes a new request to the redirected location which won't have any context from the previous request.

Header-Only Responses
---------------------

The [`head`][] method can be used to send responses with only headers to the browser. This is usually in response to an [HTTP `HEAD`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Methods/HEAD) request.

The `head` method accepts a number or symbol representing an HTTP status code.

```ruby
head :bad_request
```

This would produce the following headers:

```http
HTTP/1.1 400 Bad Request
Connection: close
Date: Sun, 24 Jan 2010 12:15:53 GMT
Transfer-Encoding: chunked
Content-Type: text/html; charset=utf-8
X-Runtime: 0.013483
Set-Cookie: _blog_session=...snip...; path=/; HttpOnly
Cache-Control: no-cache
```

You can add additional HTTP headers if you wish.

```ruby
head :created, location: photo_path(@photo)
```

Which would produce:

```http
HTTP/1.1 201 Created
Connection: close
Date: Sun, 24 Jan 2010 12:16:44 GMT
Transfer-Encoding: chunked
Location: /photos/1
Content-Type: text/html; charset=utf-8
X-Runtime: 0.083496
Set-Cookie: _blog_session=...snip...; path=/; HttpOnly
Cache-Control: no-cache
```

Setting Layouts In Controllers
-------------------------------

Layouts provide a common structure into which responses are `render`ed. If a layout isn't explicitly defined, Rails will automatically select it.

### Automatic Layout Selection

All layout files must be placed within `app/views/layouts`. Rails will first look for a layout file with the same base name as the controller — for example, `photos.html.erb` for a `PhotosController`. If such a file doesn't exist, it will fall back to the default `application.html.erb`.

### Specifying Layouts for Controllers

Explicity define a layout for a controller with the [`layout`][] declaration.

```ruby
class ProductsController < ApplicationController
  layout "inventory"

  # ...
end
```

With this declaration, all views rendered by the `ProductsController` will be inserted into `app/views/layouts/inventory.html.erb`.

Use a `layout` declaration in your `ApplicationController` to change the default layout for your entire application:

```ruby
class ApplicationController < ActionController::Base
  layout "main"

  # ...
end
```

[`layout`]: https://api.rubyonrails.org/classes/ActionView/Layouts/ClassMethods.html#method-i-layout

### Setting Layouts Dynamically

Invoke the `layout` method with a symbol denoting a method name to select a layout dynamically at runtime.

```ruby
class ProductsController < ApplicationController
  layout :products_layout

  def show
    @product = Product.find(params[:id])
  end

  private
    def products_layout
      Current.user.admin? ? "admin" : "products"
    end
end
```

Now, if the current user is a administrator, they'll get the admin-specific layout when viewing a product.

You can also invoke `layout` with a `Proc` or `lambda`. The controller instance will be passed into it.

```ruby
class ProductsController < ApplicationController
  layout ->(controller) { controller.request.xhr? ? "popup" : "application" }
end
```

### Conditional Layouts

Layouts defined at the controller level support the `:only` and `:except` options. You can use these options to specify layouts for a subset of the controller's actions.

```ruby
class ProductsController < ApplicationController
  # The `product` layout is used for all actions except `index` and `rss`.
  layout "product", except: [:index, :rss]
end
```

```ruby
class ProductsController < ApplicationController
  # The `product` layout is used only for the `show` and `edit` actions.
  layout "product", only: [:show, :edit]
end
```

### Layout Hierarchy

Layout declarations cascade downward in the hierarchy, and more specific layout declarations always override more general ones. For example:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  layout "main"
end

# app/controllers/articles_controller.rb
class ArticlesController < ApplicationController
end

# app/controllers/products_controller.rb
class ProductsController < ArticlesController
  layout "product"
end

# app/controllers/profiles_controller.rb
class ProfilesController < ApplicationController
  layout false

  def show
    @profile = Profile.find(params[:id])
    render layout: "profile"
  end

  def index
    @profiles = Profile.all
  end

  # ...
end
```

In this application:

* All `ArticlesController` actions will use the `main` layout.
* All `ProductsController` actions will use the `product` layout.
* `ProfilesController#show` will use the `profile` layout.
* `ProfilesController#index` and all other actions in that controller will not use a layout.
* All other actions across the application will default to the `main` layout.
