**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Using Hotwire With Rails
========================

[Hotwire](https://hotwired.dev) is Rails' default JavaScript front-end stack. This
guide covers Rails' integration with the Hotwire libraries *Turbo* and *Stimulus*.

After reading this guide you will know:

- The libraries that the Hotwire suite consists of.
- What Turbo is, and how to use Turbo Drive, Frames, and Streams in Rails.
- How Turbo Streams can be delivered over WebSockets with Action Cable.
- How to emit Turbo Stream updates when Active Record models are created and updated.
- What Stimulus is and how to use it in Rails.

--------------------------------------------------------------------------------

What is Hotwire?
----------------

[Hotwire](https://hotwired.dev) is a suite of front-end libraries that enable us to
build rich, high-fidelity, and modern web applications without the complexities
of a single-page application.

Hotwire for the web consists of two libraries:

* [Turbo][]
* [Stimulus][]

[Turbo]: https://turbo.hotwired.dev/
[Stimulus]: https://stimulus.hotwired.dev/

Rails integrates with [Turbo][] and [Stimulus][] using the gems [`turbo-rails`][]
and [`stimulus-rails`][]. They're installed by default in all new Rails apps. Install
them in existing applications using:

```bash
$ bundle add turbo-rails
$ bin/rails turbo:install
```

```bash
$ bundle add stimulus-rails
$ bin/rails stimulus:install
```

[`turbo-rails`]: https://github.com/hotwired/turbo-rails
[`stimulus-rails`]: https://github.com/hotwired/stimulus-rails

NOTE: Hotwire also includes [Hotwire Native](https://native.hotwired.dev). This library is
focused on native mobile applications and hence we won't cover it in this guide.

This guide focuses on Rails' integration with Turbo and Stimulus, and not on the libraries
themselves. If you're unfamiliar with them, read the [Hotwire docs](https://hotwired.dev)
before continuing with this guide.

Turbo
-----

Turbo is the nucleus of Hotwire. It consists of 3 parts: [Turbo Drive][], [Turbo Frames][],
and [Turbo Streams][].

**Turbo Drive** accelerates links and form submissions by making those requests using
JavaScript and swapping out the document's `<body>` element, eliminating the need for full
page loads.

**Turbo Frames** allow you to decompose pages into independent contexts where navigation and
updates can occur without affecting the rest of the page.

**Turbo Streams** are used to make fine-grained, targeted updates to specific DOM elements using a range of actions such as: `prepend`, `replace`, `append`,
and more!

See the [Turbo handbook](https://turbo.hotwired.dev/handbook/introduction) for more information on how
Turbo works and its features.

[Turbo Drive]: https://turbo.hotwired.dev/handbook/drive
[Turbo Frames]: https://turbo.hotwired.dev/handbook/frames
[Turbo Streams]: https://turbo.hotwired.dev/handbook/streams
[`turbo-rails`]: https://github.com/hotwired/turbo-rails

### Turbo Drive

[Turbo Drive](https://turbo.hotwired.dev/handbook/drive) largely works
automatically when imported into your HTML document. It offers a
few configuration options, and the ability to define `data-` attributes
and `<meta>` tags in your HTML to customize behavior.
See the [handbook](https://turbo.hotwired.dev/handbook/drive) and
[reference](https://turbo.hotwired.dev/reference/drive) for further details.

The [`turbo-rails` gem](https://github.com/hotwired/turbo-rails/tree/main/lib)
provides helper methods which define `<meta>` tags to customize Turbo Drive on specific pages.

All these helpers use [`provide :head`][provide_api] to render
the `<meta>` tag so they can be used in your views — just ensure
`<% yield :head %>` is declared in your layout's `<head>` so the tags
are injected correctly.

[provide_api]: https://api.rubyonrails.org/classes/ActionView/Helpers/CaptureHelper.html#method-i-provide

Control a [page's caching behavior](https://turbo.hotwired.dev/handbook/building#opting-out-of-caching)
by setting a `turbo-cache-control` meta tag:

```erb
<%# Renders <meta name="turbo-cache-control" content="no-cache"> %>
<%= turbo_exempts_page_from_cache %>

<%# Renders <meta name="turbo-cache-control" content="no-preview"> %>
<%= turbo_exempts_page_from_preview %>
```

Force a [full page reload for specific pages](https://turbo.hotwired.dev/reference/attributes#meta-tags)
with a `turbo-visit-control` meta tag:

```erb
<%# Renders <meta name="turbo-visit-control" content="reload"> %>
<%= turbo_page_requires_reload %>
```

Configure [morphing page refreshes](https://turbo.hotwired.dev/handbook/page_refreshes#morphing)
with:

```erb
<%# Renders: %>
<%# <meta name="turbo-refresh-method" content="morph"> %>
<%# <meta name="turbo-refresh-scroll" content="preserve"> %>

<%= turbo_refreshes_with(method: :morph, scroll: :preserve) %>
```

View the [source code](https://github.com/hotwired/turbo-rails/blob/main/app/helpers/turbo/drive_helper.rb)
for more details.

### Turbo Frames

[Turbo Frames](https://turbo.hotwired.dev/handbook/frames) uses a `<turbo-frame>` element
to isolate parts of a web page into its own navigation context, allowing it to be updated
independently from the rest of the page.

Use the `turbo_frame_tag` helper to declare a Turbo Frame:

```erb
<%= turbo_frame_tag dom_id(post) do %>
  <div>
     <%= link_to post.title, post_path(post) %>
  </div>
<% end %>
```

All Turbo Frame elements require a unique HTML `id` attribute, which is used
to match the content being replaced when requesting new pages from the server.

An `id` based on one or more Active Record objects can be generated using
the [`dom_id`][] or [`dom_target`][] methods.

[`dom_id`]: https://api.rubyonrails.org/classes/ActionView/RecordIdentifier.html#method-i-dom_id
[`dom_target`]: https://api.rubyonrails.org/classes/ActionView/RecordIdentifier.html#method-i-dom_target

### Turbo Streams

[Turbo Streams](https://turbo.hotwired.dev/handbook/streams) are used to perform a series of
actions (such as `create`, `append`, `remove`, `replace` etc.) on specific DOM elements via a
`<turbo-stream>` element. As soon as a `<turbo-stream>` tag is added to the document, Turbo
will execute it and perform the action it defines.

[`turbo-rails`][] provides helpers to create HTTP responses consisting of Turbo Streams, as
well as an integration with [Action Cable](action_cable_overview.html) to broadcast Turbo Streams
from the server.

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
      format.html
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
      format.html
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

#### Custom Stream Actions

Turbo allows the
[creation of custom actions](https://turbo.hotwired.dev/handbook/streams#custom-actions)
for Streams. Consider the below example to add a class to an element:

```js
import { StreamActions } from "@hotwired/turbo"

StreamActions.add_class = function() {
  let className = this.getAttribute("class")
  this.targetElements.forEach(e => {
    e.classList.add(className)
  })
}
```

Since this is a custom action, `turbo-rails` doesn't define a helper method to
render it. It can be rendered using the generic tag helper:

```erb
<%= turbo_stream_action_tag(:add_class, target: :posts, class: "font-bold") %>
```

Alternatively, you can define your own custom helper:

```ruby
# app/helpers/turbo_stream_actions_helper.rb

module TurboStreamActionsHelper
  def add_class(target, class_name)
    turbo_stream_action_tag(
      :add_class,
      target: target,
      class: class_name
    )
  end
end

Turbo::Streams::TagBuilder.prepend(TurboStreamActionsHelper)
```

The custom action can now be rendered with a more readable syntax:

```erb
<%= turbo_stream.add_class(:posts, "font-bold") %>
```

### Content Security Policy

Rails supports the use of a [Content Security Policy (CSP)](security.html#content-security-policy-header)
along with a [_nonce_](security.html#adding-a-nonce) to restrict the loading
of external content such as scripts, stylesheets, or images. If you're
unfamiliar with how a Content Security Policy works or what a nonce is,
refer to the [Security guide](security.html#content-security-policy-header).

This section outlines the extra considerations required when
using a CSP in Rails with Turbo.

Rails sets the CSP using an HTTP response header, and it is activated
by the browser when an HTML document is loaded. Since Turbo intercepts
all link clicks and form submissions to perform the HTTP
request and update the page using JavaScript, the HTML document
is never reloaded during page navigation. Hence, the CSP defined on
the page's first load is active until the document is fully reloaded
(by a page refresh, for example).

Due to this behavior, Turbo requires a nonce that is constant for
the duration of a session — such as the session ID.

```ruby
# config/content_security_policy.rb

# ...

# The session ID will be defined in the CSP, and be set as a
# `nonce` attribute in `<script>` elements, allowing them
# to execute.
# Note that a user will not have a valid session for their
# first ever request to your app, resulting in an invalid
# nonce for that request.
config.content_security_policy_nonce_generator = ->(request) {
  request.session.id.to_s
}

# To work around the above issue, you may use a randomly
# generated value and store it in the session.
config.content_security_policy_nonce_generator = ->(request) {
  request.session[:nonce] ||= SecureRandom.base64(16)
  request.session[:nonce]
}
```

Generating a unique nonce for each request isn't compatible with
Turbo because the HTML document isn't reloaded during navigation,
meaning the CSP cannot be updated with a new request-specific nonce.

WARNING: Rails renders the nonce in a meta tag in the document's head.
Turbo reads the nonce from this tag and applies it to every script element
in the content it loads. If an inline script without a valid nonce has been
injected into a page's content through an XSS vulnerability, it will be
blocked on a full page load, but will execute after a Turbo Drive
navigation to the same page. <br><br>
This functionality can be disabled by excluding the `csp_meta_tag`
directive in your document's head, so the nonce isn't rendered within the
page.

WARNING: Do not add `'strict-dynamic'` to your CSP when using
Turbo. Turbo uses the `createElement` method to insert received script tags
into the document. `'strict-dynamic'` allows scripts inserted in
this way regardless of their nonce. If an attacker managed to inject
a script into a page that is navigated to using Turbo, the
`'strict-dynamic'` directive in your CSP would allow it to run even
without a nonce.

Further information can be found in the
[security guide](security.html#adding-a-nonce).

Turbo Streams over Action Cable
-------------------------------

To broadcast Turbo Streams using [Action Cable](action_cable_overview.html),
you'll need the `@hotwired/turbo-rails` JavaScript package:

```bash
$ bin/rails turbo:install
```

Ensure that [Action Cable](action_cable_overview.html) is set up in your
application. It is recommended to create an `ApplicationCable::Connection`
class to authenticate Turbo Stream connections:

```ruby
# app/channels/application_cable/connection.rb

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = authenticate_user
    end

    private
      def authenticate_user
        # Authenticate the user using cookies.

        # Reject the connection using `reject_unauthorized_connection`
        # if authentication fails.
      end
  end
end
```

Turbo Streams can be received over an Action Cable connection by subscribing to
broadcasts on a _stream_ within a view:

```erb
<%= turbo_stream_from "notifications" %>
```

You can broadcast a Turbo Stream action to this stream using:

```ruby
Turbo::StreamsChannel.broadcast_action_to(
  "notifications",
  action: :append,
  target: "notifications_container",
  partial: "notifications/alert",
  locals: { notification: notification }
)
```

The above example broadcasts a Turbo Stream `append` action to the
`notifications` stream. Clients subscribed to this stream will
receive the action and execute it, inserting the supplied partial into
the DOM element with the `id` `notifications_container`.

### Subscribing to Streams

`turbo_stream_from` renders a `<turbo-cable-stream-source>` element which uses the
Action Cable JavaScript library to create connections and subscribe to streams.

```erb
<%# Subscribes to a stream named `"notifications"` %>
<%= turbo_stream_from "notifications" %>
```

will render

```html
<turbo-cable-stream-source
  channel="Turbo::StreamsChannel"
  signed-stream-name="Im5vdGlmaWNhdGlvbnMi--3d5e05f70fe3ccf6a6554557ab1213a94da33d4f4064eca0dd4668a0ca971cf8">
</turbo-cable-stream-source>
```

The supplied stream name is Base64 encoded and signed using
[`ActiveSupport::MessageVerifier`](https://api.rubyonrails.org/classes/ActiveSupport/MessageVerifier.html)
to ensure it can't be tampered with.

#### Stream Names

The stream name must be a string, but other types of objects are often utilized
used to generate the final string used. Objects used to generate the
stream name must respond to `to_gid_param` or `to_param`. Hence, they're
usually Active Record objects, strings, or symbols. These are
called _broadcastables_ or _streamables_.

Multiple arguments may be passed to `turbo_stream_from` to namespace the stream
name. In this case, `to_gid_param` or `to_param` will be called on each
object and then joined with a `:`.

```erb
<%= turbo_stream_from @post, :chat %>
```

will subscribe to a stream named:

```ruby
"Z2lkOi8vcmFpbHMtZ3VpZGVzLWRlbW8vUG9zdC8x:chat"
```

where `Z2lkOi8vcmFpbHMtZ3VpZGVzLWRlbW8vUG9zdC8x` is the Base64 encoded
[Global ID](https://github.com/rails/globalid) of the `@post` object.

NOTE: The above stream name is presented in plain-text for demonstration —
however, when it is rendered to HTML using `turbo_stream_from`, it will
be signed as shown in the previous section.

#### Custom Channels

`<turbo-cable-stream-source>` uses the
[`Turbo::StreamsChannel`](https://rubydoc.info/github/hotwired/turbo-rails/Turbo/StreamsChannel)
to manage subscriptions by default. This is a generic class provided by
the `turbo-rails` gem and doesn't run any authorization checks on the
resource before accepting subscription to a stream. It verifies the signed
stream name and then wires up the stream.

```ruby
class Turbo::StreamsChannel < ActionCable::Channel::Base
  extend Turbo::Streams::Broadcasts, Turbo::Streams::StreamName
  include Turbo::Streams::StreamName::ClassMethods

  def subscribed
    if stream_name = verified_stream_name_from_params
      stream_from stream_name
    else
      reject
    end
  end
end
```

Since there is no authorization check, a user could theoretically subscribe to
another user's stream if they were able to acquire their signed stream name.
Prevent this issue by creating your own channel and authorizing the user's
permissions before allowing subscription. `turbo-rails` provides primitives
we can include to verify stream names in our own channels:

```ruby
# app/channels/posts_channel.rb

class PostsChannel < ApplicationCable::Channel
  extend Turbo::Streams::StreamName
  include Turbo::Streams::StreamName::ClassMethods

  def subscribed
    if post&.authorize(current_user)
      stream_from stream_name
    else
      reject
    end
  end

  private
    def stream_name
      @stream_name ||= verified_stream_name_from_params
    end

    def post
      @post ||= GlobalID::Locator.locate(stream_name)
    end
end
```

Specify this channel in your view:

```erb
<%# Renders:  %>
<%# <turbo-cable-stream-source channel="PostsChannel" signed-stream-name="..."></turbo-cable-stream-source> %>
<%= turbo_stream_from @post, channel: "PostsChannel" %>
```

Subscriptions will now be managed by the `PostsChannel` which checks the
user's permissions before accepting the stream.

### Broadcasting to Streams

`turbo-rails` provides a plethora of helper methods to broadcast stream actions.
Under the hood, they all call `ActionCable.server.broadcast(...)`.

A generic broadcast operation:

```ruby#1,3
Turbo::StreamsChannel.broadcast_action_to(
  "posts",
  action: :append,
  target: "posts",
  partial: "posts/post",
  locals: { post: post }
)
```

can be rewritten as:

```ruby#1
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

NOTE: Even when using custom channels to handle subscriptions to Turbo Streams,
you can use the `Turbo::StreamsChannel` broadcast helpers to deliver the Stream
actions. It will compute the correct stream name based on the supplied
broadcastables.

All the above examples render templates and broadcast them synchronously.
They can be offloaded to a background job to improve performance by using the `
later` version of the methods such as `broadcast_append_later_to`.

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

Check out the
[source code](https://github.com/hotwired/turbo-rails/blob/main/app/channels/turbo/streams/broadcasts.rb)
for all available helpers.

#### Broadcastable Model Helpers

The `turbo-rails` gem contains a
[`Broadcastable`](https://github.com/hotwired/turbo-rails/blob/main/app/models/concerns/turbo/broadcastable.rb)
concern which is included in `ActiveRecord::Base`. It applies Rails conventions
to succinctly broadcast model-specific Turbo Streams. Some example use cases are:

```ruby
@post = Post.first

# These helpers implicitly broadcast Stream actions to
# the model object's stream.
#
# <%= turbo_stream_from @post %>

# Broadcasts an `append` action containing the partial
# `posts/post` targeted at the DOM element with the ID `"posts"`.
# Conventionally, the target is pluralized model name, and the
# partial is obtained by calling `@post.to_partial_path`.
@post.broadcast_append
@post.broadcast_append_later

# The update action targets the specific model's HTML element.
# In this case, it will target `"post_1"`, where `1` is the ID of
# the `@post` record. The content will be the partial `posts/post`.
# The target is generated using `ActionView::RecordIdentifier.dom_id(@post)`,
# and the partial is obtained by calling `@post.to_partial_path`.
@post.broadcast_update
@post.broadcast_update_later

# The remove action targets the specific model's HTML element.
# In this case, it will target `post_1`, where `1` is the ID of
# the `@post` record.
@post.broadcast_remove
@post.broadcast_remove_later

# The partial and target can be explicitly defined if required.
@post.broadcast_append(target: "posts", partial: "posts/post", locals: { post: @post })
@post.broadcast_append_later(target: "posts", partial: "posts/post", locals: { post: @post })

# Broadcast to a specific stream
@post.broadcast_append_to("posts_list")
@post.broadcast_append_later_to("posts_list")
```

Turbo Stream helpers provided by `Broadcastable` are most useful in lifecycle
callbacks:

```ruby
class Post < ApplicationRecord
  after_create_commit -> { broadcast_append_later_to("posts") }
end
```

The `broadcasts_to` method configures a model to emit Turbo Streams on creation,
update, and deletion to the supplied stream name (provided via a block or method
signature).

```ruby
class Post < ApplicationRecord
  broadcasts_to ->(post) { post.model_name.plural }
end
```

```ruby
class Post < ApplicationRecord
  broadcasts_to :stream_name

  def stream_name
    "posts"
  end
end
```

The above snippets are equivalent to:

```ruby
class Post < ApplicationRecord
  after_create_commit  -> {
    broadcast_append_later_to("posts", target: "posts", partial: "posts/post")
  }
  after_update_commit  -> {
    broadcast_replace_later_to("posts", target: ActionView::RecordIdentifier.dom_id(self), partial: "posts/post")
  }
  after_destroy_commit -> {
    broadcast_remove_to("posts", target: ActionView::RecordIdentifier.dom_id(self))
  }
end
```

You can customize the partial or template rendered in the broadcast using:

```ruby
class Post < ApplicationRecord
  # Renders `posts/_list_item.html.erb`
  broadcasts_to -> { "posts" }, partial: "posts/list_item"

  # Renders `posts/update.html.erb`
  broadcasts_to -> { "posts" }, template: "posts/update"

  # Renders `posts/update.turbo_stream.erb`
  broadcasts_to -> { "posts" }, template: "posts/update", formats: :turbo_stream
end
```

The `broadcasts` directive emits Turbo Streams to an inferred stream
name (the pluralized model name for `create`, and the model
instance's stream for `update` and `remove`),

```ruby
class Post < ApplicationRecord
  broadcasts
end
```

This can be expanded as:

```ruby
class Post < ApplicationRecord
  after_create_commit  -> {
    broadcast_append_later_to("posts", target: "posts", partial: "posts/post")
  }
  after_update_commit  -> {
    broadcast_replace_later_to(self, target: ActionView::RecordIdentifier.dom_id(self), partial: "posts/post")
  }
  after_destroy_commit -> {
    broadcast_remove_to(self, target: ActionView::RecordIdentifier.dom_id(self))
  }
end
```

Customize the rendered partial or template using:

```ruby
class Post < ApplicationRecord
  # Renders `posts/_list_item.html.erb`
  broadcasts partial: "posts/list_item"

  # Renders `posts/update.html.erb`
  broadcasts template: "posts/update"

  # Renders `posts/update.turbo_stream.erb`
  broadcasts template: "posts/update", formats: :turbo_stream
end
```

When using morphing page refreshes, the `broadcasts_refreshes` declaration
will trigger Turbo Streams with the action `refresh` whenever a model changes:

```ruby
class Post < ApplicationRecord
  broadcasts_refreshes
end
```

This is equivalent to:

```ruby
class Post < ApplicationRecord
  after_create_commit  -> { broadcast_refresh_later_to("posts") }
  after_update_commit  -> { broadcast_refresh_later_to(dom_id(self)) }
  after_destroy_commit -> { broadcast_refresh_to(dom_id(self)) }
end
```

You can specify a stream name using `broadcasts_refreshes_to`:

```ruby
class Post < ApplicationRecord
  broadcasts_refreshes_to :stream_name

  def stream_name
    "posts"
  end
end
```

See the [API documentation](https://rubydoc.info/github/hotwired/turbo-rails/Turbo/Broadcastable)
for all available helpers.

Stimulus
--------

[Stimulus][] is a lightweight library to manipulate HTML with reusable pieces
of JavaScript logic encapsulated in a JavaScript object, called a _controller_.

Stimulus has an HTML-centric way of writing JavaScript. The markup is connected to the
controller using a range of `data-` attributes.

Here's an example of a Stimulus controller:

```js
// hello_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "name", "output" ]

  greet() {
    this.outputTarget.textContent =
      `Hello, ${this.nameTarget.value}!`
  }
}
```

The above controller uses _targets_, which are named references to elements
in its HTML scope, to grab an input's value and display a greeting. The
`greet()` action reads the `name` _target_ and writes it into the
`output` _target_.

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

Refer to the Stimulus [handbook](https://stimulus.hotwired.dev/handbook/introduction)
and [reference](https://stimulus.hotwired.dev/reference/controllers) for
complete usage information.

### Creating Controllers

The [`stimulus-rails`][] gem provides a generator to create Stimulus controllers:

```bash
$ bin/rails generate stimulus hello
# Generates app/javascript/controllers/hello_controller.js
```

This generates the skeleton of a controller:

```js
// app/javascript/controllers/hello_controller.js

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="hello"
export default class extends Controller {
  connect() {
  }
}
```

[`stimulus-rails`]: https://github.com/hotwired/stimulus-rails

When using an import map to deliver your JavaScript, Rails will
automatically eager load all your Stimulus controllers:

```js
// app/javascript/controllers/index.js

// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
```

In other JavaScript setups, controllers are loaded manually:

```js
// app/javascript/controllers/index.js

import { application } from "./application"

import HelloController from "./hello_controller"
application.register("hello", HelloController)
```

This manifest is automatically updated when you create a controller using
`bin/rails generate stimulus`. Force an update by running:

```bash
$ bin/rails stimulus:manifest:update
```

This might be useful after renaming a controller.

### Using Controllers

In Rails, use Stimulus controllers for client-side use cases where Turbo
doesn't apply. It's best used to modify HTML you already have.

In this section we'll discuss an example use case: implementing a button which
allows a user to dynamically add text fields to a Rails form.

Consider the below form to create a post:

```erb
<%= form_with(model: @post) do |form| %>
  <fieldset>
    <%= form.label :title %>
    <%= form.text_field :title %>
  </fieldset>

  <fieldset>
    <%= form.label :body %>
    <%= form.text_area :body %>
  </fieldset>

  <%= form.submit %>
<% end %>
```

We'd like to allow the user to create one or more _tags_ to associate with
the post. This requires an **Add Tag** button which dynamically adds a
text field to the form where the user can define the tag. This is a perfect
use case for Stimulus.

First, ensure the model and controller can accept
[nested attributes](https://api.rubyonrails.org/classes/ActiveRecord/NestedAttributes/ClassMethods.html#method-i-accepts_nested_attributes_for)
for the tag:

```ruby
class Post < ApplicationRecord
  has_many :tags

  accepts_nested_attributes_for :tags, allow_destroy: true, limit: 5
end
```

```ruby
class PostsController < ApplicationController
  def create
    @post = Post.new(post_params)
    # ...
  end

  private
    def post_params
      params.require(:post).permit(:title, :body, tags_attributes: [:content, :_destroy])
    end
end
```

```ruby
class Tag < ApplicationRecord
  belongs_to :post
end
```

Then, we need to add a `<template>` element to the form which the
Stimulus controller will use to add the text field:

```erb
<%= form_with(model: @post) do |form| %>
  <%# ... %>

  <template>
    <%= form.fields_for :tags, @post.tags.build, child_index: "NEW_RECORD" do |tag| %>
      <fieldset data-new-record="true">
        <%= tag.text_field :content %>
        <%= tag.hidden_field :_destroy %>

        <%= tag.button type: :button do %>
          Remove
        <% end %>
      </fieldset>
    <% end %>
  </template>

  <%= form.submit %>
<% end %>
```

Specifying the `NEW_RECORD` placeholder as the `child_index` allows us to replace
it in the Stimulus controller to prevent clashes in elements' `id` and `name`
attributes.

Next, generate and implement a Stimulus controller to read this `<template>` and
add it to the form:

```bash
$ bin/rails generate stimulus nested_form
```

```js
// app/javascript/controllers/nested_form_controller.js

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="nested-form"
export default class extends Controller {
  static targets = ["container", "template"]

  add(event) {
    event.preventDefault()

    // Replace `NEW_RECORD` with the timestamp to ensure each new element is unique
    let content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime().toString())
    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    event.preventDefault()

    let wrapper = event.target.closest("fieldset")

    // For new `Tag` records, we can simply remove the HTML element
    if (wrapper.dataset.newRecord === "true") {
      wrapper.remove()

    // When a `Tag` record exists, mark it for deletion on the server
    // and hide it in the UI.
    } else {
      wrapper.style.display = "none"

      let input = wrapper.querySelector("input[name*='_destroy']")
      input.value = "1"
    }
  }
}
```

The final step is to wire up the Stimulus controller in the DOM:

```erb#1,5,6,8-10,12,18
<%= form_with(model: @post, data: { controller: "nested-form" }) do |form| %>
  <%# ... %>

  <%# The container to which the text fields will be added %>
  <div data-nested-form-target="container">
  </div>

  <button type="button" data-action="nested-form#add">
    Add tag
  </button>

  <template data-nested-form-target="template">
    <%= form.fields_for :tags, @post.tags.build, child_index: "NEW_RECORD" do |tag| %>
      <fieldset data-new-record="true">
        <%= tag.text_field :content %>
        <%= tag.hidden_field :_destroy %>

        <%= tag.button type: :button, data: { action: "nested-form#remove" }  do %>
          Remove
        <% end %>
      </fieldset>
    <% end %>
  </template>

  <%= form.submit %>
<% end %>
```

The user can now dynamically add tags to their post which will be processed on
the server.

This is just one example where Stimulus fits the bill. Use it wherever you need
to manipulate HTML in your web page. Some more example use cases are:

* Keyboard hotkeys which trigger actions in your app.
* Resize an HTML textarea automatically as a user types.
* A _drag and drop_ interface to upload files.
