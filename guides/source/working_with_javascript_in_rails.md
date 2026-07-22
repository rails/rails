**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Working with JavaScript in Rails
================================

This guide covers the integration of JavaScript into your Rails application —
including the usage of Turbo and Stimulus as well as the installation of external JavaScript packages
into Rails.

After reading this guide, you will know:

* How to use an Import Map to deliver JavaScript in your Rails app.
* How to integrate JavaScript bundlers like `esbuild` or `rollup` with Rails.
* What Turbo is and how Rails integrates with it.
* How to install Stimulus and use it for client-side JavaScript functionality.
* How to make HTTP requests using JavaScript with the `request.js` library.

--------------------------------------------------------------------------------

Introduction
------------

Rails provides two mechanisms to deliver JavaScript within your application: using an [import map](#using-a-javascript-import-map), or a [JavaScript bundler](#using-a-javascript-bundler). Both of these systems integrate with the [Asset Pipeline](asset_pipeline.html) to deliver the files to the browser.

The [Turbo](#turbo) and [Stimulus](#stimulus) JavaScript libraries (which are part of the [Hotwire](https://hotwired.dev) suite) are included in Rails, and form the default front-end stack.

Using a JavaScript Import Map
-----------------------------

A JavaScript [import map](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/script/type/importmap) allows JavaScript files to be delivered separately without bundling and still be able to reference each other.

It is a JSON object which defines the mapping between the module specifier passed to an `import` statement, and the path to the actual file to be imported. Here's an example:

```json
{
  "imports": {
    "animations": "/scripts/animations.js",
    "utilities": "/scripts/utilities.js"
  }
}
```

Scripts can now invoke `import "animations"` or `import "utilities"` and the browser will import the corresponding file and the module it contains.

In Rails, the import map is constructed using the [importmap-rails](https://github.com/rails/importmap-rails) gem.

This technique doesn't require an additional build step for your JavaScript. Your files are delivered as-is, and hence no JavaScript runtime such as Node.js is required.

### Installing `importmap-rails`

The `importmap-rails` gem is included by default in all new Rails applications. In older applications, you can install it using:

```bash
$ bundle add importmap-rails
$ bin/rails importmap:install
```

### Declaring JavaScript Files

All your JavaScript files need to be declared in `config/importmap.rb` so Rails knows to include them in the import map object.

```ruby
# config/importmap.rb

# Declare JavaScript files from your application
pin "application"
pin "utilities"

# Declare all files inside a folder
pin_all_from "app/javascript/controllers", under: "controllers"
```

NOTE: All files declared in your `config/importmap.rb` must exist within your [asset pipeline's load paths](asset_pipeline.html#load_paths).

This will create an import map object similar to:

```json
{
  "imports": {
    "application": "/assets/application-d8a8613a.js",
    "utilities": "/assets/utilities-e8dc057d.js",
    "controllers/application": "/assets/controllers/application-3affb389.js",
    "controllers/hello_controller": "/assets/controllers/hello_controller-708796bd.js",
    "controllers": "/assets/controllers/index-ee64e1f1.js"
  }
}
```

which is rendered in your HTML document's `<head>` using:

```erb
<%= javascript_importmap_tags %>
```

NOTE: You'll notice that the filenames contain a _hash_. This is added by [Rails' Asset Pipeline](asset_pipeline.html). It is calculated based on the file's contents and used to version the files.

See the [Asset Pipeline guide](asset_pipeline.html#javascript-import-map) and the [`importmap-rails` Readme](https://github.com/rails/importmap-rails) for further information.

Using a JavaScript Bundler
--------------------------

You can integrate a JavaScript bundler into Rails using the [`jsbundling-rails`](https://github.com/rails/jsbundling-rails) gem. It supports a number of builders such as [ESBuild](https://esbuild.github.io/), [Rollup](https://rollupjs.org/guide/en/), [Bun](https://bun.sh), and [Webpack](https://webpack.js.org/).

This gem requires a JavaScript runtime. For all bundlers except Bun, you'll need Node.js and Yarn. For Bun, you'll just need to install that as it is both a JavaScript runtime and a bundler.

### Installing Node.js and Yarn

Find the installation instructions on the [Node.js website](https://nodejs.org/en/download/) and verify it’s installed correctly:

```bash
$ node --version
v23.6.1
```

To install Yarn, follow the installation instructions at the [Yarn website](https://classic.yarnpkg.com/en/docs/install). Verify it's installed using:

```bash
$ yarn --version
1.22.19
```

### Installing Bun

Follow the installation instructions at the [Bun website](https://bun.sh) and verify it’s installed:

```bash
$ bun --version
v1.3.13
```

### Installing `jsbundling-rails`

When creating a new Rails app, setup a JavaScript bundler using the `-j` or `--javascript` flag:

```bash
$ rails new my_new_app -j esbuild
```

```bash
$ rails new my_new_app --javascript=esbuild
```

Add the `jsbundling-rails` gem in an existing Rails app using:

```bash
$ bundle add jsbundling-rails
```

Then configure your chosen bundler with:

```bash
$ bin/rails javascript:install:[bun|esbuild|rollup|webpack]
```

When using `jsbundling-rails`, use `bin/dev` to start the JavaScript bundler along with Rails server in development. Further information is available in the [Asset Pipeline guide](asset_pipeline.html#bundling-and-transpiling-javascript).

Adding npm Packages
-------------------

### Vendoring NPM Packages with `importmap-rails`

When using `importmap-rails`, NPM packages are downloaded into the `vendor` folder in your app and checked into source control.

Add a package to your application using `bin/importmap pin`:

```bash
$ bin/importmap pin ahoy.js
```

This will download the package into your `vendor` folder and declare them in your `config/importmap.rb`. You can then import the package in your `application.js`:

```javascript
import ahoy from 'ahoy.js';
```

Further information is available in the [`importmap-rails` Readme](https://github.com/rails/importmap-rails?tab=readme-ov-file#using-npm-packages-via-javascript-cdns).

### Installing NPM Packages with a JavaScript Bundler

When using Bun, the Bun package manager installs NPM packages:

```bash
$ bun add ahoy.js
```

See the [Bun documentation](https://bun.com/docs/pm/cli/install) for more information.

For all other bundlers, use Yarn to manage your dependencies:

```bash
$ yarn add ahoy.js
```

Further details are available in the [Yarn documentation](https://yarnpkg.com/getting-started/usage).

Choosing Between an Import Map and a JavaScript Bundler
-------------------------------------------------------

In all new Rails apps, JavaScript is delivered using an import map. The Rails team believes that using an import maps reduces complexity, improves developer experience, and delivers performance gains.

For many applications, especially those that rely primarily on [Hotwire](https://hotwired.dev/), an import map will be the right option for the long term. You can read more about the reasoning behind making import maps the default in Rails 7 [here](https://world.hey.com/dhh/rails-7-will-have-three-great-answers-to-javascript-in-2021-8d68191b).

However, there may be use cases that call for a JavaScript bundler. Listed below are a few considerations where a JavaScript bundler may be more suited to your app than an import map:

* You cannot serve your assets over HTTP/2.
* Your code requires a transpilation step, such as JSX or TypeScript.
* You need to use JavaScript libraries that include CSS or otherwise rely on
  [Webpack loaders](https://webpack.js.org/loaders/).
* Your JavaScript architecture requires [tree-shaking](https://en.wikipedia.org/wiki/Tree_shaking).
* You're using the [`cssbundling-rails` gem](https://github.com/rails/cssbundling-rails) to manage your CSS.

Hotwire
-------

Rails' default JavaScript stack is [Hotwire](https://hotwired.dev). It is a suite of front-end libraries that enable us to build rich, high-fidelity, and modern web applications without the complexities of a single-page application.

[Turbo][] and [Stimulus][] which are part of the Hotwire suite are automatically installed in all new Rails apps.

This guide primarily covers Rails' integration with Turbo and Stimulus. Consult their documentation for detailed usage information:

* [Turbo][]
* [Stimulus][]

[Turbo]: https://turbo.hotwired.dev/
[Stimulus]: https://stimulus.hotwired.dev/

### Turbo

Turbo is the nucleus of Hotwire. It consists of 3 parts: [Turbo Drive][], [Turbo Frames][], and [Turbo Streams][].

**Turbo Drive** accelerates links and form submissions by making those requests using JavaScript and swapping out the document's `<body>` element, eliminating the need for full page loads.

**Turbo Frames** allow you to decompose pages into independent contexts where navigation and updates can occur without affecting the rest of the page.

**Turbo Streams** are used to make fine-grained, targeted updates to specific DOM elements using a range of CRUD actions.

Rails integrates with Turbo via the [`turbo-rails`][] gem. You can use this gem to install Turbo in existing applications:

```bash
$ bundle add turbo-rails
$ bin/rails turbo:install
```

See the [Turbo handbook](https://turbo.hotwired.dev/handbook/) for more information on how Turbo works and its features.

[Turbo Drive]: https://turbo.hotwired.dev/handbook/drive
[Turbo Frames]: https://turbo.hotwired.dev/handbook/frames
[Turbo Streams]: https://turbo.hotwired.dev/handbook/streams
[`turbo-rails`]: https://github.com/hotwired/turbo-rails

#### Turbo Drive

[Turbo Drive](https://turbo.hotwired.dev/handbook/drive) largely works automatically when imported into your HTML document. It offers a few configuration options, and the ability to define `data-` attributes and `<meta>` tags in your HTML to customize behavior. See the [handbook](https://turbo.hotwired.dev/handbook/drive) and [reference](https://turbo.hotwired.dev/reference/drive) for further details.

Rails offers view helper methods via the [`turbo-rails` gem](https://github.com/hotwired/turbo-rails/tree/main/lib) which define `<meta>` tags to customize Turbo Drive on specific pages.

You can [control a page's caching behavior](https://turbo.hotwired.dev/handbook/building#opting-out-of-caching) by setting a `turbo-cache-control` meta tag.

```erb
<%# Renders <meta name="turbo-cache-control" content="no-cache"> %>
<%= turbo_exempts_page_from_cache %>

<%# Renders <meta name="turbo-cache-control" content="no-preview"> %>
<%= turbo_exempts_page_from_preview %>
```

Force a [full page reload for specific pages](https://turbo.hotwired.dev/reference/attributes#meta-tags) with:

```erb
<%# Renders <meta name="turbo-visit-control" content="reload"> %>
<%= turbo_page_requires_reload %>
```

Configure [morphing page refreshes](https://turbo.hotwired.dev/handbook/page_refreshes#morphing) with:

```erb
<%= turbo_refreshes_with(method: :morph, scroll: :preserve) %>
```

View the [source code](https://github.com/hotwired/turbo-rails/blob/main/app/helpers/turbo/drive_helper.rb) for more details.

#### Turbo Frames

[Turbo Frames](https://turbo.hotwired.dev/handbook/frames) uses a `<turbo-frame>` element to isolate parts of a web page into its own navigation context, so it can be updated independently from the rest of the page.

The [`turbo-rails`][] gem defines a helper method to simplify the declaration of a `<turbo-frame>`:

```erb
<%= turbo_frame_tag dom_id(post) do %>
  <div>
     <%= link_to post.title, post_path(post) %>
  </div>
<% end %>
```

All Turbo Frame elements require a unique ID. The [`dom_id`](https://api.rubyonrails.org/classes/ActionView/RecordIdentifier.html#method-i-dom_id) method calculates an ID based on an Active Record object and is commonly used to identify Turbo Frames.

#### Turbo Streams

[Turbo Streams](https://turbo.hotwired.dev/handbook/streams) are used to perform a series of actions (such as `create`, `append`, `remove`, `replace` etc.) on specific DOM elements via a `<turbo-stream>` element. As soon as a `<turbo-stream>` tag is added to the document, Turbo will execute it and perform the action it defines.

[`turbo-rails`][] provides helpers to create HTTP responses consisting of Turbo Streams, as well as an integration with [Action Cable](action_cable_overview.html) to allow Turbo Streams to be delivered via WebSockets.

Render a Turbo Stream in your controller using:

```ruby
def create
  @post = Post.new(post_params)

  respond_to do |format|
    if @post.save
      format.turbo_stream do
        # Renders:
        # <turbo-stream action="prepend" target="posts">
        #   <template>
        #     <h2>My New Post</h2>
        #   </template>
        # </turbo-stream>
        render turbo_stream: turbo_stream.prepend("posts", helpers.tag.h2(@post.title))
      end
    else
      format.html { render :new, status: :unprocessable_entity }
    end
  end
end
```

You can use an ERB template as well. This is useful when defining multiple Turbo Streams:

```ruby
def create
  @post = Post.new(post_params)

  respond_to do |format|
    if @post.save
      format.turbo_stream
    else
      format.html { render :new, status: :unprocessable_entity }
    end
  end
end
```

```erb
<%# create.turbo_stream.erb %>

<%= turbo_stream.prepend("posts", partial: "posts/post", locals: { post: @post }) %>
<%= turbo_stream.replace("posts_title") do %>
  <%= Post.count %> posts
<% end %>
```

#### Turbo Streams over Action Cable

To deliver Turbo Streams over WebSockets, ensure that [Action Cable](action_cable_overview.html) is set up in your application and you have the [`turbo-rails`][] JavaScript package installed.

Turbo Streams can be received over WebSockets by subscribing to broadcasts on a _stream_ within a view:

```erb
<%= turbo_stream_from "posts" %>
```

This will render a `<turbo-cable-stream-source>` tag which opens a WebSocket connection and subscribes to a stream called `"posts"`. It will automatically execute any Turbo Streams it receives.

Broadcast a Turbo Stream action to this stream using:

```ruby
Turbo::StreamsChannel.broadcast_action_to(
  "posts",
  action: :append,
  target: "posts",
  partial: "posts/post",
  locals: { post: post }
)
```

There are helper methods to broadcast the stock Turbo Stream actions. The above snippet can be rewritten as:

```ruby
Turbo::StreamsChannel.broadcast_append_to(
  "posts",
  target: "posts",
  partial: "posts/post",
  locals: { post: post }
)
```

You can also broadcast a Turbo Stream template containing multiple actions:

```ruby
Turbo::StreamsChannel.broadcast_render_to(
  "posts",
  template: "posts/create"
)
```

or broadcast a `refresh` action which is useful for morphing:

```ruby
Turbo::StreamsChannel.broadcast_refresh_to("posts")
```

All the above examples render templates and broadcast them synchronously. They can be offloaded to a background job to improve performance by using the `later` version of the methods such as `broadcast_append_later_to`.

```ruby
# enqueues a `Turbo::Streams::ActionBroadcastJob`
Turbo::StreamsChannel.broadcast_append_later_to(
  "posts",
  target: "posts",
  partial: "posts/post",
  locals: { post: post }
)

# enqueues a `Turbo::Streams::BroadcastJob`
Turbo::StreamsChannel.broadcast_render_later_to(
  "posts",
  template: "posts/create"
)
```

Check out the [source code](https://github.com/hotwired/turbo-rails/blob/main/app/channels/turbo/streams/broadcasts.rb) for all available helpers.

In addition to this, the gem provides a [`Broadcastable`](https://github.com/hotwired/turbo-rails/blob/main/app/models/concerns/turbo/broadcastable.rb) concern which is included in Active Record. It applies Rails conventions to succinctly broadcast model-specific Turbo Streams. Some example use cases are:

```ruby
@post = Post.first

# Turbo Stream actions are implicitly broadcast to
# the model object's stream. To subscribe to an individual
# model's stream, you'd use:
#
# <%= turbo_stream_from @post %>

# Broadcasts an `append` action containing the partial
# `posts/post` targeted at the DOM ID `posts`.
@post.broadcast_append
@post.broadcast_append_later

# The update action targets the specific model's HTML element (`dom_id(@post)`).
# In this case, it will target the DOM ID `post_1`. The content
# will be the partial `posts/post`.
@post.broadcast_update
@post.broadcast_update_later

# The remove action targets the specific model's HTML element (`dom_id(@post)`).
# In this case, it will target the DOM ID `post_1`.
@post.broadcast_remove
@post.broadcast_remove_later

# The partial can be explicitly defined if required.
@post.broadcast_append(partial: "posts/post", locals: { post: @post })
@post.broadcast_append_later(partial: "posts/post", locals: { post: @post })

# Broadcast to a specific stream
@post.broadcast_append_to("posts")
@post.broadcast_append_later_to("posts")
```

The `broadcasts_to` method configures a model to emit Turbo Streams on creation, update, and deletion to the supplied stream name:

```ruby
class Post < ApplicationRecord
  broadcasts_to ->(post) { post.model_name.plural }
end
```

The above snippet is equivalent to:

```ruby
class Post < ApplicationRecord
  after_create_commit  -> { broadcast_append_later_to("posts", target: "posts", partial: "posts/post") }
  after_update_commit  -> { broadcast_replace_later_to("posts", target: dom_id(self), partial: "posts/post") }
  after_destroy_commit -> { broadcast_remove_to("posts", target: dom_id(self)) }
end
```

Use `broadcasts` to emit Turbo Streams to an inferred stream name:

```ruby
class Post < ApplicationRecord
  broadcasts
end
```

This can be expanded as:

```ruby
class Post < ApplicationRecord
  after_create_commit  -> { broadcast_append_later_to("posts", target: "posts", partial: "posts/post") }
  after_update_commit  -> { broadcast_replace_later_to(self, target: dom_id(self), partial: "posts/post") }
  after_destroy_commit -> { broadcast_remove_to(self, target: dom_id(self)) }
end
```

Use `broadcasts_refreshes` to emit a Turbo Stream to `refresh` the page whenever the model changes:

```ruby
class Post < ApplicationRecord
  broadcasts_refreshes
end
```

The above code is equivalent to:

```ruby
class Post < ApplicationRecord
  after_create_commit  -> { broadcast_refresh_later_to("posts") }
  after_update_commit  -> { broadcast_refresh_later_to(dom_id(self)) }
  after_destroy_commit -> { broadcast_refresh_to(dom_id(self)) }
end
```

See the [source code](https://github.com/hotwired/turbo-rails/blob/main/app/models/concerns/turbo/broadcastable.rb) and inline RDoc comments for all available helpers and options.

### Stimulus

[Stimulus][] is a lightweight library to manipulate HTML with reusable pieces of JavaScript logic encapsulated in a JavaScript _controller_.

Stimulus has an HTML-centric way of writing JavaScript. The markup is connected to the controller using a range of `data-` attributes.

Here's an example of a Stimulus controller:

```js
// hello_controller.js
import { Controller } from "stimulus"

export default class extends Controller {
  static targets = [ "name", "output" ]

  greet() {
    this.outputTarget.textContent =
      `Hello, ${this.nameTarget.value}!`
  }
}
```

The above controller uses _targets_, which are named references to elements in its HTML scope, to grab an input's value and display a greeting. The `greet()` action reads the `name` _target_ and writes it into the `output` _target_.

It can be attached to the DOM via the `data-controller` attribute:

```html
<div data-controller="hello">
  <input data-hello-target="name" type="text">

  <button data-action="click->hello#greet">
    Greet
  </button>

  <span data-hello-target="output">
  </span>
</div>
```

Refer to the Stimulus [handbook](https://stimulus.hotwired.dev/handbook/introduction) and [reference](https://stimulus.hotwired.dev/reference/controllers) for complete usage information.

Rails integrates with Stimulus via the [`stimulus-rails`][] gem, which provides a generator to create Stimulus controllers:

```bash
# Generates app/javascript/controllers/hello_controller.js
$ bin/rails generate stimulus hello
```

```js
// app/javascript/controllers/hello_controller.js

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="hello"
export default class extends Controller {
  connect() {
  }
}
```

It also contains a _task_ which you can use to install Stimulus in an existing application:

```bash
$ bin/rails stimulus:install
```

[`stimulus-rails`]: https://github.com/hotwired/stimulus-rails

### `request.js`

Rails protects against [CSRF attacks](security.html#cross-site-request-forgery-csrf) by [validating non-`GET` requests with a token](security.html#required-security-token). The [`request.js`](https://github.com/rails/request.js) library automatically adds the CSRF token to HTTP requests, making it easier to trigger HTTP requests using JavaScript.

This library is maintained by the Rails team but it isn't included in Rails by default, so you'll need to install it:

```bash
$ bundle add requestjs-rails
$ bin/rails requestjs:install
```

Here's an example of a Stimulus controller that uses `request.js` to make a `POST` request:

```js
import { post } from '@rails/request.js'
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input" ]

  async fetchSuggestions() {
    const response = await post('/users/suggestions', {
      body: JSON.stringify({
        input: this.inputTarget.value
      })
    })

    if (response.ok) {
      // Do something with the response
    }
  }
}
```

`request.js` will automatically activate JavaScript responses which have a `content-type` response header of `application/javascript` or `application/ecmascript`. It will also automatically execute Turbo Stream responses.

See the [Readme](https://github.com/rails/request.js) for advanced usage and futher installation information.

NOTE: Prior to Rails 7, a JavaScript library called Rails UJS was used to enhannce Rails on the front-end. This library has now been removed from Rails, and all its functionality has been replaced by Turbo, Stimulus, and request.js. You can find information about Rails UJS in an [older version of the guides](/v6.1/working_with_javascript_in_rails.html#unobtrusive-javascript).
