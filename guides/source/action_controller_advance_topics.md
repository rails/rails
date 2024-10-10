**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Action Controller Advance Topics
================================

In this guide, you will learn about the following topics related to controllers: TODO update bullet points.

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

Please see the [Action Controller Overview](action_controller_overview.html) guide.
TODO introduce these miscellaneous topics.


Request Forgery Protection
--------------------------

Cross-site request forgery is a type of attack in which a site tricks a user into making requests on another site, possibly adding, modifying, or deleting data on that site without the user's knowledge or permission.

The first step to avoid this is to make sure all "destructive" actions (create, update, and destroy) can only be accessed with non-GET requests. If you're following RESTful conventions you're already doing this. However, a malicious site can still send a non-GET request to your site quite easily, and that's where the request forgery protection comes in. As the name says, it protects from forged requests.

The way this is done is to add a non-guessable token which is only known to your server to each request. This way, if a request comes in without the proper token, it will be denied access.

If you generate a form like this:

```erb
<%= form_with model: @user do |form| %>
  <%= form.text_field :username %>
  <%= form.text_field :password %>
<% end %>
```

You will see how the token gets added as a hidden field:

```html
<form accept-charset="UTF-8" action="/users/1" method="post">
<input type="hidden"
       value="67250ab105eb5ad10851c00a5621854a23af5489"
       name="authenticity_token"/>
<!-- fields -->
</form>
```

Rails adds this token to every form that's generated using the [form helpers](form_helpers.html), so most of the time you don't have to worry about it. If you're writing a form manually or need to add the token for another reason, it's available through the method `form_authenticity_token`:

The `form_authenticity_token` generates a valid authentication token. That's useful in places where Rails does not add it automatically, like in custom Ajax calls.

The [Security Guide](security.html) has more about this, and a lot of other security-related issues that you should be aware of when developing a web application.

HTTP Authentications
--------------------

Rails comes with three built-in HTTP authentication mechanisms:

* Basic Authentication
* Digest Authentication
* Token Authentication

### HTTP Basic Authentication

HTTP basic authentication is an authentication scheme that is supported by the majority of browsers and other HTTP clients. As an example, consider an administration section which will only be available by entering a username, and a password into the browser's HTTP basic dialog window. Using the built-in authentication only requires you to use one method, [`http_basic_authenticate_with`][].

```ruby
class AdminsController < ApplicationController
  http_basic_authenticate_with name: "humbaba", password: "5baa61e4"
end
```

With this in place, you can create namespaced controllers that inherit from `AdminsController`. The action callback will thus be run for all actions in those controllers, protecting them with HTTP basic authentication.

[`http_basic_authenticate_with`]: https://api.rubyonrails.org/classes/ActionController/HttpAuthentication/Basic/ControllerMethods/ClassMethods.html#method-i-http_basic_authenticate_with

### HTTP Digest Authentication

HTTP digest authentication is superior to the basic authentication as it does not require the client to send an unencrypted password over the network (though HTTP basic authentication is safe over HTTPS). Using digest authentication with Rails only requires using one method, [`authenticate_or_request_with_http_digest`][].

```ruby
class AdminsController < ApplicationController
  USERS = { "lifo" => "world" }

  before_action :authenticate

  private
    def authenticate
      authenticate_or_request_with_http_digest do |username|
        USERS[username]
      end
    end
end
```

As seen in the example above, the `authenticate_or_request_with_http_digest` block takes only one argument - the username. And the block returns the password. Returning `false` or `nil` from the `authenticate_or_request_with_http_digest` will cause authentication failure.

[`authenticate_or_request_with_http_digest`]: https://api.rubyonrails.org/classes/ActionController/HttpAuthentication/Digest/ControllerMethods.html#method-i-authenticate_or_request_with_http_digest

### HTTP Token Authentication

HTTP token authentication is a scheme to enable the usage of Bearer tokens in the HTTP `Authorization` header. There are many token formats available and describing them is outside the scope of this document.

As an example, suppose you want to use an authentication token that has been issued in advance to perform authentication and access. Implementing token authentication with Rails only requires using one method, [`authenticate_or_request_with_http_token`][].

```ruby
class PostsController < ApplicationController
  TOKEN = "secret"

  before_action :authenticate

  private
    def authenticate
      authenticate_or_request_with_http_token do |token, options|
        ActiveSupport::SecurityUtils.secure_compare(token, TOKEN)
      end
    end
end
```

As seen in the example above, the `authenticate_or_request_with_http_token` block takes two arguments - the token and a `Hash` containing the options that were parsed from the HTTP `Authorization` header. The block should return `true` if the authentication is successful. Returning `false` or `nil` on it will cause an authentication failure.

[`authenticate_or_request_with_http_token`]: https://api.rubyonrails.org/classes/ActionController/HttpAuthentication/Token/ControllerMethods.html#method-i-authenticate_or_request_with_http_token

Streaming and File Downloads
----------------------------

Sometimes you may want to send a file to the user instead of rendering an HTML page. All controllers in Rails have the [`send_data`][] and the [`send_file`][] methods, which will both stream data to the client. `send_file` is a convenience method that lets you provide the name of a file on the disk, and it will stream the contents of that file for you.

To stream data to the client, use `send_data`:

```ruby
require "prawn"
class ClientsController < ApplicationController
  # Generates a PDF document with information on the client and
  # returns it. The user will get the PDF as a file download.
  def download_pdf
    client = Client.find(params[:id])
    send_data generate_pdf(client),
              filename: "#{client.name}.pdf",
              type: "application/pdf"
  end

  private
    def generate_pdf(client)
      Prawn::Document.new do
        text client.name, align: :center
        text "Address: #{client.address}"
        text "Email: #{client.email}"
      end.render
    end
end
```

The `download_pdf` action in the example above will call a private method which actually generates the PDF document and returns it as a string. This string will then be streamed to the client as a file download, and a filename will be suggested to the user. Sometimes when streaming files to the user, you may not want them to download the file. Take images, for example, which can be embedded into HTML pages. To tell the browser a file is not meant to be downloaded, you can set the `:disposition` option to "inline". The opposite and default value for this option is "attachment".

[`send_data`]: https://api.rubyonrails.org/classes/ActionController/DataStreaming.html#method-i-send_data
[`send_file`]: https://api.rubyonrails.org/classes/ActionController/DataStreaming.html#method-i-send_file

### Sending Files

If you want to send a file that already exists on disk, use the `send_file` method.

```ruby
class ClientsController < ApplicationController
  # Stream a file that has already been generated and stored on disk.
  def download_pdf
    client = Client.find(params[:id])
    send_file("#{Rails.root}/files/clients/#{client.id}.pdf",
              filename: "#{client.name}.pdf",
              type: "application/pdf")
  end
end
```

This will read and stream the file 4 kB at the time, avoiding loading the entire file into memory at once. You can turn off streaming with the `:stream` option or adjust the block size with the `:buffer_size` option.

If `:type` is not specified, it will be guessed from the file extension specified in `:filename`. If the content-type is not registered for the extension, `application/octet-stream` will be used.

WARNING: Be careful when using data coming from the client (params, cookies, etc.) to locate the file on disk, as this is a security risk that might allow someone to gain access to files they are not meant to.

TIP: It is not recommended that you stream static files through Rails if you can instead keep them in a public folder on your web server. It is much more efficient to let the user download the file directly using Apache or another web server, keeping the request from unnecessarily going through the whole Rails stack.

### RESTful Downloads

While `send_data` works just fine, if you are creating a RESTful application having separate actions for file downloads is usually not necessary. In REST terminology, the PDF file from the example above can be considered just another representation of the client resource. Rails provides a slick way of doing "RESTful" downloads. Here's how you can rewrite the example so that the PDF download is a part of the `show` action, without any streaming:

```ruby
class ClientsController < ApplicationController
  # The user can request to receive this resource as HTML or PDF.
  def show
    @client = Client.find(params[:id])

    respond_to do |format|
      format.html
      format.pdf { render pdf: generate_pdf(@client) }
    end
  end
end
```

You can call any method on `format` that is an extension registered as a MIME type by Rails.
Rails already registers common MIME types like `"text/html"` and `"application/pdf"`:

```ruby
Mime::Type.lookup_by_extension(:pdf)
# => "application/pdf"
```

If you need additional MIME types, call [`Mime::Type.register`](https://api.rubyonrails.org/classes/Mime/Type.html#method-c-register) in the file `config/initializers/mime_types.rb`. For example, this is how you would register the Rich Text Format (RTF):

```ruby
Mime::Type.register("application/rtf", :rtf)
```

NOTE: Configuration files are not reloaded on each request, so you have to restart the server for their changes to take effect.

Now the user can request to get a PDF version of a client just by adding ".pdf" to the URL:

```
GET /clients/1.pdf
```

### Live Streaming of Arbitrary Data

Rails allows you to stream more than just files. In fact, you can stream anything
you would like in a response object. The [`ActionController::Live`][] module allows
you to create a persistent connection with a browser. Using this module, you will
be able to send arbitrary data to the browser at specific points in time.

[`ActionController::Live`]: https://api.rubyonrails.org/classes/ActionController/Live.html

#### Incorporating Live Streaming

Including `ActionController::Live` inside of your controller class will provide
all actions inside the controller the ability to stream data. You can mix in
the module like so:

```ruby
class MyController < ActionController::Base
  include ActionController::Live

  def stream
    response.headers['Content-Type'] = 'text/event-stream'
    100.times {
      response.stream.write "hello world\n"
      sleep 1
    }
  ensure
    response.stream.close
  end
end
```

The above code will keep a persistent connection with the browser and send 100
messages of `"hello world\n"`, each one second apart.

There are a couple of things to notice in the above example. We need to make
sure to close the response stream. Forgetting to close the stream will leave
the socket open forever. We also have to set the content type to `text/event-stream`
before we write to the response stream. This is because headers cannot be written
after the response has been committed (when `response.committed?` returns a truthy
value), which occurs when you `write` or `commit` the response stream.

#### Example Usage

Let's suppose that you were making a Karaoke machine, and a user wants to get the
lyrics for a particular song. Each `Song` has a particular number of lines and
each line takes time `num_beats` to finish singing.

If we wanted to return the lyrics in Karaoke fashion (only sending the line when
the singer has finished the previous line), then we could use `ActionController::Live`
as follows:

```ruby
class LyricsController < ActionController::Base
  include ActionController::Live

  def show
    response.headers['Content-Type'] = 'text/event-stream'
    song = Song.find(params[:id])

    song.each do |line|
      response.stream.write line.lyrics
      sleep line.num_beats
    end
  ensure
    response.stream.close
  end
end
```

The above code sends the next line only after the singer has completed the previous
line.

#### Streaming Considerations

Streaming arbitrary data is an extremely powerful tool. As shown in the previous
examples, you can choose when and what to send across a response stream. However,
you should also note the following things:

* Each response stream creates a new thread and copies over the thread local
  variables from the original thread. Having too many thread local variables can
  negatively impact performance. Similarly, a large number of threads can also
  hinder performance.
* Failing to close the response stream will leave the corresponding socket open
  forever. Make sure to call `close` whenever you are using a response stream.
* WEBrick servers buffer all responses, and so including `ActionController::Live`
  will not work. You must use a web server which does not automatically buffer
  responses.


Log Filtering
-------------

Rails keeps a log file for each environment in the `log` folder. These are extremely useful when debugging what's actually going on in your application, but in a live application you may not want every bit of information to be stored in the log file.

### Parameters Filtering

You can filter out sensitive request parameters from your log files by
appending them to [`config.filter_parameters`][] in the application configuration.
These parameters will be marked [FILTERED] in the log.

```ruby
config.filter_parameters << :password
```

NOTE: Provided parameters will be filtered out by partial matching regular
expression. Rails adds a list of default filters, including `:passw`,
`:secret`, and `:token`, in the appropriate initializer
(`initializers/filter_parameter_logging.rb`) to handle typical application
parameters like `password`, `password_confirmation` and `my_token`.

[`config.filter_parameters`]: configuring.html#config-filter-parameters

### Redirects Filtering

Sometimes it's desirable to filter out from log files some sensitive locations your application is redirecting to.
You can do that by using the `config.filter_redirect` configuration option:

```ruby
config.filter_redirect << 's3.amazonaws.com'
```

You can set it to a String, a Regexp, or an array of both.

```ruby
config.filter_redirect.concat ['s3.amazonaws.com', /private_path/]
```

Matching URLs will be replaced with '[FILTERED]'. However, if you only wish to filter the parameters, not the whole URLs,
please take a look at [Parameters Filtering](#parameters-filtering).

Force HTTPS Protocol
--------------------

If you'd like to ensure that communication to your controller is only possible
via HTTPS, you should do so by enabling the [`ActionDispatch::SSL`][] middleware via
[`config.force_ssl`][] in your environment configuration.

[`config.force_ssl`]: configuring.html#config-force-ssl
[`ActionDispatch::SSL`]: https://api.rubyonrails.org/classes/ActionDispatch/SSL.html

Built-in Health Check Endpoint
------------------------------

Rails also comes with a built-in health check endpoint that is reachable at the `/up` path. This endpoint will return a 200 status code if the app has booted with no exceptions, and a 500 status code otherwise.

In production, many applications are required to report their status upstream, whether it's to an uptime monitor that will page an engineer when things go wrong, or a load balancer or Kubernetes controller used to determine a pod's health. This health check is designed to be a one-size fits all that will work in many situations.

While any newly generated Rails applications will have the health check at `/up`, you can configure the path to be anything you'd like in your "config/routes.rb":

```ruby
Rails.application.routes.draw do
  get "healthz" => "rails/health#show", as: :rails_health_check
end
```

The health check will now be accessible via the `/healthz` path.

NOTE: This endpoint does not reflect the status of all of your application's dependencies, such as the database or redis cluster. Replace "rails/health#show" with your own controller action if you have application specific needs.

Think carefully about what you want to check as it can lead to situations where your application is being restarted due to a third-party service going bad. Ideally, you should design your application to handle those outages gracefully.

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
