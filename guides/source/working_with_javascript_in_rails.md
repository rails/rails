**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON http://guides.rubyonrails.org.**

Working with JavaScript in Rails
================================

This guide covers the built-in Ajax/JavaScript functionality of Rails (and
more); it will enable you to create rich and dynamic Ajax applications with
ease!

After reading this guide, you will know:

* The basics of Ajax.
* Unobtrusive JavaScript.
* How Rails' built-in helpers assist you.
* How to handle Ajax on the server side.
* The Turbolinks gem.

-------------------------------------------------------------------------------

An Introduction to Ajax
------------------------

In order to understand Ajax, you must first understand what a web browser does
normally.

When you type `http://localhost:3000` into your browser's address bar and hit
'Go,' the browser (your 'client') makes a request to the server. It parses the
response, then fetches all associated assets, like JavaScript files,
stylesheets and images. It then assembles the page. If you click a link, it
does the same process: fetch the page, fetch the assets, put it all together,
show you the results. This is called the 'request response cycle.'

JavaScript can also make requests to the server, and parse the response. It
also has the ability to update information on the page. Combining these two
powers, a JavaScript writer can make a web page that can update just parts of
itself, without needing to get the full page data from the server. This is a
powerful technique that we call Ajax.

Rails ships with CoffeeScript by default, and so the rest of the examples
in this guide will be in CoffeeScript. All of these lessons, of course, apply
to vanilla JavaScript as well.

As an example, here's some CoffeeScript code that makes an Ajax request using
the jQuery library:

```coffeescript
$.ajax(url: "/test").done (html) ->
  $("#results").append html
```

This code fetches data from "/test", and then appends the result to the `div`
with an id of `results`.

Rails provides quite a bit of built-in support for building web pages with this
technique. You rarely have to write this code yourself. The rest of this guide
will show you how Rails can help you write websites in this way, but it's
all built on top of this fairly simple technique.

Unobtrusive JavaScript
-------------------------------------

Rails uses a technique called "Unobtrusive JavaScript" to handle attaching
JavaScript to the DOM. This is generally considered to be a best-practice
within the frontend community, but you may occasionally read tutorials that
demonstrate other ways.

Here's the simplest way to write JavaScript. You may see it referred to as
'inline JavaScript':

```html
<a href="#" onclick="this.style.backgroundColor='#990000'">Paint it red</a>
```
When clicked, the link background will become red. Here's the problem: what
happens when we have lots of JavaScript we want to execute on a click?

```html
<a href="#" onclick="this.style.backgroundColor='#009900';this.style.color='#FFFFFF';">Paint it green</a>
```

Awkward, right? We could pull the function definition out of the click handler,
and turn it into CoffeeScript:

```coffeescript
@paintIt = (element, backgroundColor, textColor) ->
  element.style.backgroundColor = backgroundColor
  if textColor?
    element.style.color = textColor
```

And then on our page:

```html
<a href="#" onclick="paintIt(this, '#990000')">Paint it red</a>
```

That's a little bit better, but what about multiple links that have the same
effect?

```html
<a href="#" onclick="paintIt(this, '#990000')">Paint it red</a>
<a href="#" onclick="paintIt(this, '#009900', '#FFFFFF')">Paint it green</a>
<a href="#" onclick="paintIt(this, '#000099', '#FFFFFF')">Paint it blue</a>
```

Not very DRY, eh? We can fix this by using events instead. We'll add a `data-*`
attribute to our link, and then bind a handler to the click event of every link
that has that attribute:

```coffeescript
@paintIt = (element, backgroundColor, textColor) ->
  element.style.backgroundColor = backgroundColor
  if textColor?
    element.style.color = textColor

$ ->
  $("a[data-background-color]").click (e) ->
    e.preventDefault()

    backgroundColor = $(this).data("background-color")
    textColor = $(this).data("text-color")
    paintIt(this, backgroundColor, textColor)
```
```html
<a href="#" data-background-color="#990000">Paint it red</a>
<a href="#" data-background-color="#009900" data-text-color="#FFFFFF">Paint it green</a>
<a href="#" data-background-color="#000099" data-text-color="#FFFFFF">Paint it blue</a>
```

We call this 'unobtrusive' JavaScript because we're no longer mixing our
JavaScript into our HTML. We've properly separated our concerns, making future
change easy. We can easily add behavior to any link by adding the data
attribute. We can run all of our JavaScript through a minimizer and
concatenator. We can serve our entire JavaScript bundle on every page, which
means that it'll get downloaded on the first page load and then be cached on
every page after that. Lots of little benefits really add up.

The Rails team strongly encourages you to write your CoffeeScript (and
JavaScript) in this style, and you can expect that many libraries will also
follow this pattern.

Built-in Helpers
----------------------

### Remote elements

Rails provides a bunch of view helper methods written in Ruby to assist you
in generating HTML. Sometimes, you want to add a little Ajax to those elements,
and Rails has got your back in those cases.

Because of Unobtrusive JavaScript, the Rails "Ajax helpers" are actually in two
parts: the JavaScript half and the Ruby half.

Unless you have disabled the Asset Pipeline,
[rails-ujs](https://github.com/rails/rails/tree/master/actionview/app/assets/javascripts)
provides the JavaScript half, and the regular Ruby view helpers add appropriate
tags to your DOM.

You can read below about the different events that are fired dealing with
remote elements inside your application.

#### form_with

[`form_with`](http://api.rubyonrails.org/classes/ActionView/Helpers/FormHelper.html#method-i-form_with)
is a helper that assists with writing forms. By default, `form_with` assumes that
your form will be using Ajax. You can opt out of this behavior by
passing the `:local` option `form_with`.

```erb
<%= form_with(model: @article) do |f| %>
  ...
<% end %>
```

This will generate the following HTML:

```html
<form action="/articles" method="post" data-remote="true">
  ...
</form>
```

Note the `data-remote="true"`. Now, the form will be submitted by Ajax rather
than by the browser's normal submit mechanism.

You probably don't want to just sit there with a filled out `<form>`, though.
You probably want to do something upon a successful submission. To do that,
bind to the `ajax:success` event. On failure, use `ajax:error`. Check it out:

```coffeescript
$(document).ready ->
  $("#new_article").on("ajax:success", (event) ->
    [data, status, xhr] = event.detail
    $("#new_article").append xhr.responseText
  ).on "ajax:error", (event) ->
    $("#new_article").append "<p>ERROR</p>"
```

Obviously, you'll want to be a bit more sophisticated than that, but it's a
start.

#### link_to

[`link_to`](http://api.rubyonrails.org/classes/ActionView/Helpers/UrlHelper.html#method-i-link_to)
is a helper that assists with generating links. It has a `:remote` option you
can use like this:

```erb
<%= link_to "an article", @article, remote: true %>
```

which generates

```html
<a href="/articles/1" data-remote="true">an article</a>
```

You can bind to the same Ajax events as `form_with`. Here's an example. Let's
assume that we have a list of articles that can be deleted with just one
click. We would generate some HTML like this:

```erb
<%= link_to "Delete article", @article, remote: true, method: :delete %>
```

and write some CoffeeScript like this:

```coffeescript
$ ->
  $("a[data-remote]").on "ajax:success", (e, data, status, xhr) ->
    alert "The article was deleted."
```

#### button_to

[`button_to`](http://api.rubyonrails.org/classes/ActionView/Helpers/UrlHelper.html#method-i-button_to) is a helper that helps you create buttons. It has a `:remote` option that you can call like this:

```erb
<%= button_to "An article", @article, remote: true %>
```

this generates

```html
<form action="/articles/1" class="button_to" data-remote="true" method="post">
  <input type="submit" value="An article" />
</form>
```

Since it's just a `<form>`, all of the information on `form_with` also applies.

### Customize remote elements

It is possible to customize the behavior of elements with a `data-remote`
attribute without writing a line of JavaScript. Your can specify extra `data-`
attributes to accomplish this.

#### `data-method`

Activating hyperlinks always results in an HTTP GET request. However, if your
application is [RESTful](http://en.wikipedia.org/wiki/Representational_State_Transfer),
some links are in fact actions that change data on the server, and must be
performed with non-GET requests. This attribute allows marking up such links
with an explicit method such as "post", "put" or "delete".

The way it works is that, when the link is activated, it constructs a hidden form
in the document with the "action" attribute corresponding to "href" value of the
link, and the method corresponding to `data-method` value, and submits that form.

NOTE: Because submitting forms with HTTP methods other than GET and POST isn't
widely supported across browsers, all other HTTP methods are actually sent over
POST with the intended method indicated in the `_method` parameter. Rails
automatically detects and compensates for this.

#### `data-url` and `data-params`

Certain elements of your page aren't actually referring to any URL, but you may want
them to trigger Ajax calls. Specifying the `data-url` attribute along with
the `data-remote` one will trigger an Ajax call to the given URL. You can also
specify extra parameters through the `data-params` attribute.

This can be useful to trigger an action on check-boxes for instance:

```html
<input type="checkbox" data-remote="true"
    data-url="/update" data-params="id=10" data-method="put">
```

#### `data-type`

It is also possible to define the Ajax `dataType` explicitly while performing
requests for `data-remote` elements, by way of the `data-type` attribute.

### Confirmations

You can ask for an extra confirmation of the user by adding a `data-confirm`
attribute on links and forms. The user will be presented a JavaScript `confirm()`
dialog containing the attribute's text. If the user chooses to cancel, the action
doesn't take place.

Adding this attribute on links will trigger the dialog on click, and adding it
on forms will trigger it on submit. For example:

```erb
<%= link_to "Dangerous zone", dangerous_zone_path,
  data: { confirm: 'Are you sure?' } %>
```

This generates:

```html
<a href="..." data-confirm="Are you sure?">Dangerous zone</a>
```

The attribute is also allowed on form submit buttons. This allows you to customize
the warning message depending on the button which was activated. In this case,
you should **not** have `data-confirm` on the form itself.

The default confirmation uses a JavaScript confirm dialog, but you can customize
this by listening to the `confirm` event, which is fired just before the confirmation
window appears to the user. To cancel this default confirmation, have the confirm
handler to return `false`.

### Automatic disabling

It is also possible to automatically disable an input while the form is submitting
by using the `data-disable-with` attribute. This is to prevent accidental
double-clicks from the user, which could result in duplicate HTTP requests that
the backend may not detect as such. The value of the attribute is the text that will
become the new value of the button in its disabled state.

This also works for links with `data-method` attribute.

For example:

```erb
<%= form_with(model: @article.new) do |f| %>
  <%= f.submit data: { "disable-with": "Saving..." } %>
<%= end %>
```

This generates a form with:

```html
<input data-disable-with="Saving..." type="submit">
```

Dealing with Ajax events
------------------------

Here are the different events that are fired when you deal with elements
that have a `data-remote` attribute:

NOTE: All handlers bound to these events are always passed the event object as the
first argument. The table below describes the extra parameters passed after the
event argument. For example, if the extra parameters are listed as `xhr, settings`,
then to access them, you would define your handler with `function(event, xhr, settings)`.

| Event name          | Extra parameters  | Fired                                                       |
|---------------------|-------------------|-------------------------------------------------------------|
| `ajax:before`       |                   | Before the whole ajax business, aborts if stopped.          |
| `ajax:beforeSend`   | xhr, options      | Before the request is sent, aborts if stopped.              |
| `ajax:send`         | xhr               | When the request is sent.                                   |
| `ajax:success`      | data, status, xhr | After completion, if the response was a success.            |
| `ajax:error`        | data, status, xhr | After completion, if the response was an error.             |
| `ajax:complete`     | xhr, status       | After the request has been completed, no matter the outcome.|
| `ajax:aborted:file` | elements          | If there are non-blank file inputs, aborts if stopped.      |

### Stoppable events

If you stop `ajax:before` or `ajax:beforeSend` by returning false from the
handler method, the Ajax request will never take place. The `ajax:before` event
is also useful for manipulating form data before serialization. The
`ajax:beforeSend` event is also useful for adding custom request headers.

If you stop the `ajax:aborted:file` event, the default behavior of allowing the
browser to submit the form via normal means (i.e. non-AJAX submission) will be
canceled and the form will not be submitted at all. This is useful for
implementing your own AJAX file upload workaround.

Server-Side Concerns
--------------------

Ajax isn't just client-side, you also need to do some work on the server
side to support it. Often, people like their Ajax requests to return JSON
rather than HTML. Let's discuss what it takes to make that happen.

### A Simple Example

Imagine you have a series of users that you would like to display and provide a
form on that same page to create a new user. The index action of your
controller looks like this:

```ruby
class UsersController < ApplicationController
  def index
    @users = User.all
    @user = User.new
  end
  # ...
```

The index view (`app/views/users/index.html.erb`) contains:

```erb
<b>Users</b>

<ul id="users">
<%= render @users %>
</ul>

<br>

<%= form_with(model: @user) do |f| %>
  <%= f.label :name %><br>
  <%= f.text_field :name %>
  <%= f.submit %>
<% end %>
```

The `app/views/users/_user.html.erb` partial contains the following:

```erb
<li><%= user.name %></li>
```

The top portion of the index page displays the users. The bottom portion
provides a form to create a new user.

The bottom form will call the `create` action on the `UsersController`. Because
the form's remote option is set to true, the request will be posted to the
`UsersController` as an Ajax request, looking for JavaScript. In order to
serve that request, the `create` action of your controller would look like
this:

```ruby
  # app/controllers/users_controller.rb
  # ......
  def create
    @user = User.new(params[:user])

    respond_to do |format|
      if @user.save
        format.html { redirect_to @user, notice: 'User was successfully created.' }
        format.js
        format.json { render json: @user, status: :created, location: @user }
      else
        format.html { render action: "new" }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end
```

Notice the format.js in the `respond_to` block; that allows the controller to
respond to your Ajax request. You then have a corresponding
`app/views/users/create.js.erb` view file that generates the actual JavaScript
code that will be sent and executed on the client side.

```erb
$("<%= escape_javascript(render @user) %>").appendTo("#users");
```

Turbolinks
----------

Rails ships with the [Turbolinks library](https://github.com/turbolinks/turbolinks),
which uses Ajax to speed up page rendering in most applications.

### How Turbolinks Works

Turbolinks attaches a click handler to all `<a>` on the page. If your browser
supports
[PushState](https://developer.mozilla.org/en-US/docs/Web/Guide/API/DOM/Manipulating_the_browser_history#The_pushState%28%29_method),
Turbolinks will make an Ajax request for the page, parse the response, and
replace the entire `<body>` of the page with the `<body>` of the response. It
will then use PushState to change the URL to the correct one, preserving
refresh semantics and giving you pretty URLs.

The only thing you have to do to enable Turbolinks is have it in your Gemfile,
and put `//= require turbolinks` in your JavaScript manifest, which is usually
`app/assets/javascripts/application.js`.

If you want to disable Turbolinks for certain links, add a `data-turbolinks="false"`
attribute to the tag:

```html
<a href="..." data-turbolinks="false">No turbolinks here</a>.
```

### Page Change Events

When writing CoffeeScript, you'll often want to do some sort of processing upon
page load. With jQuery, you'd write something like this:

```coffeescript
$(document).ready ->
  alert "page has loaded!"
```

However, because Turbolinks overrides the normal page loading process, the
event that this relies on will not be fired. If you have code that looks like
this, you must change your code to do this instead:

```coffeescript
$(document).on "turbolinks:load", ->
  alert "page has loaded!"
```

For more details, including other events you can bind to, check out [the
Turbolinks
README](https://github.com/turbolinks/turbolinks/blob/master/README.md).

Other Resources
---------------

Here are some helpful links to help you learn even more:

* [jquery-ujs wiki](https://github.com/rails/jquery-ujs/wiki)
* [jquery-ujs list of external articles](https://github.com/rails/jquery-ujs/wiki/External-articles)
* [Rails 3 Remote Links and Forms: A Definitive Guide](http://www.alfajango.com/blog/rails-3-remote-links-and-forms/)
* [Railscasts: Unobtrusive JavaScript](http://railscasts.com/episodes/205-unobtrusive-javascript)
* [Railscasts: Turbolinks](http://railscasts.com/episodes/390-turbolinks)
