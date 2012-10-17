AJAX on Rails
=============

This guide covers the built-in Ajax/JavaScript functionality of Rails (and more);
it will enable you to create rich and dynamic AJAX applications with ease! We will
cover the following topics:

* Quick introduction to AJAX and related technologies
* Unobtrusive JavaScript helpers with drivers for Prototype, jQuery etc
* Testing JavaScript functionality

--------------------------------------------------------------------------------

Hello AJAX - a Quick Intro
--------------------------

AJAX is about updating parts of a web page without reloading the page. An AJAX
call happens as a response to an event, like when the page finished loading or
when a user clicks on an element. For example, let say you click on a link, which
would usually take you to a new page, but instead of doing that, an asynchronous
HTTP request is made and the response is evaluated with JavaScript. That way the
page is not reloaded and new information can be dynamically included in the page.
The way that happens is by inserting, removing or changing parts of the DOM. The
DOM, or Document Object Model, is a convention to represent the HTML document as
a set of nodes that contain other nodes. For example, a list of names is represented
as a `ul` element node containing several `li` element nodes. An AJAX call can
be made to obtain a new list item to include, and append it inside a `li` node to
the `ul` node.

### Asynchronous JavaScript + XML

AJAX means Asynchronous JavaScript + XML. Asynchronous means that the page is not
reloaded, the request made is separate from the regular page request. JavaScript
is used to evaluate the response and the XML part is a bit misleading as XML is
not required, you respond to the HTTP request with JSON or regular HTML as well.

### The DOM

The DOM (Document Object Model) is a convention to represent HTML (or XML)
documents, as a set of nodes that act as objects and contain other nodes. You can
have a `div` element that contains other `div` elements as well as `p` elements
that contain text.

### Standard HTML communication vs AJAX

In regular HTML comunications, when you click on a link, the browser makes an HTTP
`GET` request, the server responds with a new HTML document that the browsers renders
and then replaces the previous one. The same thing happens when you click a button to
submit a form, except that you make and HTTP `POST` request, but you also get a new
HTML document that the browser renders and replaces the current one. In AJAX
communications, the request is separate, and the response is evaluated in JavaScript
instead of rendered by the browser. That way you can have more control over the content
that gets returned, and the page is not reloaded.

Built-in Rails Helpers
----------------------

Rails 4.0 ships with [jQuery](http://jquery.com) as the default JavaScript library.
The Gemfile contains `gem 'jquery-rails'` which provides the `jquery.js` and
`jquery_ujs.js` files via the asset pipeline.

You will have to use the `require` directive to tell Sprockets to load `jquery.js`
and `jquery.js`. For example, a new Rails application includes a default
`app/assets/javascripts/application.js` file which contains the following lines:

```
// ...
//= require jquery
//= require jquery_ujs
// ...
```

The `application.js` file acts like a manifest and is used to tell Sprockets the
files that you wish to require. In this case, you are requiring the files `jquery.js`
and `jquery_ujs.js` provided by the `jquery-rails` gem.

If the application is not using the asset pipeline, this can be accessed as:

```ruby
javascript_include_tag :defaults
```

By default, `:defaults` loads jQuery.

You can also choose to use Prototype instead of jQuery and specify the option
using `-j` switch while generating the application.

```bash
rails new app_name -j prototype
```

This will add the `prototype-rails` gem to the Gemfile and modify the
`app/assets/javascripts/application.js` file:

```
// ...
//= require prototype
//= require prototype_ujs
// ...
```

You are ready to add some AJAX love to your Rails app!

### Examples

To make them working with AJAX, simply pass the `remote: true` option to
the original non-remote method.

```ruby
button_to 'New', action: 'new', form_class: 'new-thing'
```

will produce

```html
<form method="post" action="/controller/new" class="new-thing">
  <div><input value="New" type="submit" /></div>
</form>
```

```ruby
button_to 'Create', action: 'create', remote: true, form: { 'data-type' => 'json' }
```

will produce

```html
<form method="post" action="/images/create" class="button_to" data-remote="true" data-type="json">
  <div><input value="Create" type="submit" /></div>
</form>
```

```ruby
button_to 'Delete Image', { action: 'delete', id: @image.id },
             method: :delete, data: { confirm: 'Are you sure?' }
```

will produce

```html
<form method="post" action="/images/delete/1" class="button_to">
  <div>
    <input type="hidden" name="_method" value="delete" />
    <input data-confirm='Are you sure?' value="Delete" type="submit" />
 </div>
</form>
```

```ruby
button_to 'Destroy', 'http://www.example.com',
             method: 'delete', remote: true, data: { disable_with: 'loading...', confirm: 'Are you sure?' }
```

will produce

```html
<form class='button_to' method='post' action='http://www.example.com' data-remote='true'>
  <div>
    <input name='_method' value='delete' type='hidden' />
    <input value='Destroy' type='submit' data-disable-with='loading...' data-confirm='Are you sure?' />
  </div>
</form>
```

### The Quintessential AJAX Rails Helper: link_to_remote

Let's start with what is probably the most often used helper: `link_to_remote`. It has an interesting feature from the documentation point of view: the options supplied to `link_to_remote` are shared by all other AJAX helpers, so learning the mechanics and options of `link_to_remote` is a great help when using other helpers.

The signature of `link_to_remote` function is the same as that of the standard `link_to` helper:

```ruby
def link_to_remote(name, options = {}, html_options = nil)
```

And here is a simple example of link_to_remote in action:

```ruby
link_to_remote "Add to cart",
  :url => add_to_cart_url(product.id),
  :update => "cart"
```

* The very first parameter, a string, is the text of the link which appears on the page.
* The second parameter, the `options` hash is the most interesting part as it has the AJAX specific stuff:
    * **:url** This is the only parameter that is always required to generate the simplest remote link (technically speaking, it is not required, you can pass an empty `options` hash to `link_to_remote` - but in this case the URL used for the POST request will be equal to your current URL which is probably not your intention). This URL points to your AJAX action handler. The URL is typically specified by Rails REST view helpers, but you can use the `url_for` format too.
    * **:update** Specifying a DOM id of the element we would like to update. The above example demonstrates the simplest way of accomplishing this - however, we are in trouble if the server responds with an error message because that will be injected into the page too! However, Rails has a solution for this situation:

        ```ruby
        link_to_remote "Add to cart",
          :url => add_to_cart_url(product),
          :update => { :success => "cart", :failure => "error" }
        ```

        If the server returns 200, the output of the above example is equivalent to our first, simple one. However, in case of error, the element with the DOM id `error` is updated rather than the `cart` element.

    * **position** By default (i.e. when not specifying this option, like in the examples before) the response is injected into the element with the specified DOM id, replacing the original content of the element (if there was any). You might want to alter this behavior by keeping the original content - the only question is where to place the new content? This can specified by the `position` parameter, with four possibilities:
      * `:before` Inserts the response text just before the target element. More precisely, it creates a text node from the response and inserts it as the left sibling of the target element.
      * `:after` Similar behavior to `:before`, but in this case the response is inserted after the target element.
      * `:top` Inserts the text into the target element, before its original content. If the target element was empty, this is equivalent with not specifying `:position` at all.
      * `:bottom` The counterpart of `:top`: the response is inserted after the target element's original content.

            A typical example of using `:bottom` is inserting a new \<li> element into an existing list:

            ```ruby
            link_to_remote "Add new item",
              :url => items_url,
              :update => 'item_list',
              :position => :bottom
            ```

    * **:method** Most typically you want to use a POST request when adding a remote
link to your view so this is the default behavior. However, sometimes you'll want to update (PATCH/PUT) or delete/destroy (DELETE) something and you can specify this with the `:method` option. Let's see an example for a typical AJAX link for deleting an item from a list:

        ```ruby
        link_to_remote "Delete the item",
          :url => item_url(item),
          :method => :delete
        ```

        Note that if we wouldn't override the default behavior (POST), the above snippet would route to the create action rather than destroy.

    * **JavaScript filters** You can customize the remote call further by wrapping it with some JavaScript code. Let's say in the previous example, when deleting a link, you'd like to ask for a confirmation by showing a simple modal text box to the user. This is a typical example what you can accomplish with these options - let's see them one by one:
        * `:condition` =&gt; `code` Evaluates `code` (which should evaluate to a boolean) and proceeds if it's true, cancels the request otherwise.
        * `:before` =&gt; `code` Evaluates the `code` just before launching the request. The output of the code has no influence on the execution. Typically used show a progress indicator (see this in action in the next example).
        * `:after` =&gt; `code` Evaluates the `code` after launching the request. Note that this is different from the `:success` or `:complete` callback (covered in the next section) since those are triggered after the request is completed, while the code snippet passed to `:after` is evaluated after the remote call is made. A common example is to disable elements on the page or otherwise prevent further action while the request is completed.
        * `:submit` =&gt; `dom_id` This option does not make sense for `link_to_remote`, but we'll cover it for the sake of completeness. By default, the parent element of the form elements the user is going to submit is the current form - use this option if you want to change the default behavior. By specifying this option you can change the parent element to the element specified by the DOM id `dom_id`.
        * `:with` &gt; `code` The JavaScript code snippet in `code` is evaluated and added to the request URL as a parameter (or set of parameters). Therefore, `code` should return a valid URL query string (like "item_type=8" or "item_type=8&sort=true"). Usually you want to obtain some value(s) from the page - let's see an example:

            ```ruby
            link_to_remote "Update record",
              :url => record_url(record),
              :method => :patch,
              :with => "'status=' + 'encodeURIComponent($('status').value) + '&completed=' + $('completed')"
            ```

            This generates a remote link which adds 2 parameters to the standard URL generated by Rails, taken from the page (contained in the elements matched by the 'status' and 'completed' DOM id).

    * **Callbacks** Since an AJAX call is typically asynchronous, as its name suggests (this is not a rule, and you can fire a synchronous request - see the last option, `:type`) your only way of communicating with a request once it is fired is via specifying callbacks. There are six options at your disposal (in fact 508, counting all possible response types, but these six are the most frequent and therefore specified by a constant):
      * `:loading:` =&gt; `code` The request is in the process of receiving the data, but the transfer is not completed yet.
      * `:loaded:` =&gt; `code` The transfer is completed, but the data is not processed and returned yet
      * `:interactive:` =&gt; `code` One step after `:loaded`: The data is fully received and being processed
      * `:success:` =&gt; `code` The data is fully received, parsed and the server responded with "200 OK"
      * `:failure:` =&gt; `code` The data is fully received, parsed and the server responded with **anything** but "200 OK" (typically 404 or 500, but in general with any status code ranging from 100 to 509)
      * `:complete:` =&gt; `code` The combination of the previous two: The request has finished receiving and parsing the data, and returned a status code (which can be anything).
      * Any other status code ranging from 100 to 509: Additionally you might want to check for other HTTP status codes, such as 404. In this case simply use the status code as a number:

            ```ruby
            link_to_remote "Add new item",
              :url => items_url,
              :update => "item_list",
              404 => "alert('Item not found!')"
            ```

            Let's see a typical example for the most frequent callbacks, `:success`, `:failure` and `:complete` in action:

            ```ruby
            link_to_remote "Add new item",
              :url => items_url,
              :update => "item_list",
              :before => "$('progress').show()",
              :complete => "$('progress').hide()",
              :success => "display_item_added(request)",
              :failure => "display_error(request)"
            ```

    * **:type** If you want to fire a synchronous request for some obscure reason (blocking the browser while the request is processed and doesn't return a status code), you can use the `:type` option with the value of `:synchronous`.

* Finally, using the `html_options` parameter you can add HTML attributes to the generated tag. It works like the same parameter of the `link_to` helper. There are interesting side effects for the `href` and `onclick` parameters though:
    * If you specify the `href` parameter, the AJAX link will degrade gracefully, i.e. the link will point to the URL even if JavaScript is disabled in the client browser
    * `link_to_remote` gains its AJAX behavior by specifying the remote call in the onclick handler of the link. If you supply `html_options[:onclick]` you override the default behavior, so use this with care!

We are finished with `link_to_remote`. I know this is quite a lot to digest for one helper function, but remember, these options are common for all the rest of the Rails view helpers, so we will take a look at the differences / additional parameters in the next sections.

### AJAX Forms

There are three different ways of adding AJAX forms to your view using Rails Prototype helpers. They are slightly different, but striving for the same goal: instead of submitting the form using the standard HTTP request/response cycle, it is submitted asynchronously, thus not reloading the page. These methods are the following:

* `remote_form_for` (and its alias `form_remote_for`) is tied to Rails most tightly of the three since it takes a resource, model or array of resources (in case of a nested resource) as a parameter.
* `form_remote_tag` AJAXifies the form by serializing and sending its data in the background
* `submit_to_remote` and `button_to_remote` is more rarely used than the previous two. Rather than creating an AJAX form, you add a button/input

Let's see them in action one by one!

#### `remote_form_for`

#### `form_remote_tag`

#### `submit_to_remote`

### Serving JavaScript

First we'll check out how to send JavaScript to the server manually. You are practically never going to need this, but it's interesting to understand what's going on under the hood.

```ruby
def javascript_test
  render :text => "alert('Hello, world!')",
         :content_type => "text/javascript"
end
```

(Note: if you want to test the above method, create a `link_to_remote` with a single parameter - `:url`, pointing to the `javascript_test` action)

What happens here is that by specifying the Content-Type header variable, we instruct the browser to evaluate the text we are sending over (rather than displaying it as plain text, which is the default behavior).

Testing JavaScript
------------------

JavaScript testing reminds me the definition of the world 'classic' by Mark Twain: "A classic is something that everybody wants to have read and nobody wants to read." It's similar with JavaScript testing: everyone would like to have it, yet it's not done by too much developers as it is tedious, complicated, there is a proliferation of tools and no consensus/accepted best practices, but we will nevertheless take a stab at it:

* (Fire)Watir
* Selenium
* Celerity/Culerity
* Cucumber+Webrat
* Mention stuff like screw.unit/jsSpec

Note to self: check out the RailsConf JS testing video
