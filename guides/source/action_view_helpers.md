**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Action View Helpers
====================

After reading this guide, you will know:

* How to format dates, strings, and numbers.
* How to link to images, videos, stylesheets, etc.
* How to sanitize content.
* How to localize content.

--------------------------------------------------------------------------------

Overview of Helpers Provided by Action View
-------------------------------------------

WIP: Not all the helpers are listed here. For a full list see the [API
documentation](https://api.rubyonrails.org/classes/ActionView/Helpers.html)

The following is only a brief overview summary of the helpers available in
Action View. It's recommended that you review the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers.html),
which covers all of the helpers in more detail, but this should serve as a good
starting point.

### AssetTagHelper

This module provides methods for generating HTML that links views to assets such
as images, JavaScript files, stylesheets, and feeds.

By default, Rails links to these assets on the current host in the public
folder, but you can direct Rails to link to assets from a dedicated assets
server by setting [`config.asset_host`][] in the application configuration,
typically in `config/environments/production.rb`. For example, let's say your
asset host is `assets.example.com`:

```ruby
config.asset_host = "assets.example.com"
image_tag("rails.png")
# => <img src="http://assets.example.com/images/rails.png" />
```

[`config.asset_host`]: configuring.html#config-asset-host

#### audio_tag

Generate an HTML audio tag with source(s), either as a single tag for a string
source or nested source tags within an array for multiple sources. The `sources`
can be full paths, files in your public audios directory, or Active Storage
attachments.

```ruby
audio_tag("sound")
# => <audio src="/audios/sound"></audio>
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/AssetTagHelper.html#method-i-audio_tag)
for more information.

#### auto_discovery_link_tag

Returns a link tag that browsers and feed readers can use to auto-detect an RSS,
Atom, or JSON feed.

```ruby
auto_discovery_link_tag(:rss, "http://www.example.com/feed.rss", { title: "RSS Feed" })
# => <link rel="alternate" type="application/rss+xml" title="RSS Feed" href="http://www.example.com/feed.rss" />
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/AssetTagHelper.html#method-i-auto_discovery_link_tag)
for more information.

#### favicon_link_tag

Returns a link tag for a favicon managed by the asset pipeline. The `source` can
be a full path or a file that exists in your assets directory.

```ruby
favicon_link_tag
# => <link href="/assets/favicon.ico" rel="icon" type="image/x-icon" />
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/AssetTagHelper.html#method-i-favicon_link_tag)
for more information.

#### image_tag

Returns an HTML image tag for the source. The source can be a full path or a
file that exists in your `app/assets/images` directory.

```ruby
image_tag("icon.png") # => <img src="/assets/icon.png" />
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/AssetTagHelper.html#method-i-image_tag)
for more information.

INFO: Internally, `image_tag` uses [`image_path` from the AssetUrlHelpers](https://edgeapi.rubyonrails.org/classes/ActionView/Helpers/AssetUrlHelper.html#method-i-image_path) to build the image path. <br><br> If you want to use an image from a different directory, you can use the `image_path` helper to get the path to the image and then use the `image_tag` helper to generate the HTML `image_tag(image_path("icons/icon.png"))`

#### javascript_include_tag

Returns an HTML script tag for each of the sources provided. You can pass in the
filename (`.js` extension is optional) of JavaScript files that exist in your
`app/assets/javascripts` directory for inclusion into the current page or you
can pass the full path relative to your document root.

```ruby
javascript_include_tag "common"
# => <script src="/assets/common.js"></script>
```

You can modify the HTML attributes of the script tag by passing a hash as the last argument.

```ruby
javascript_include_tag "common", async: true
# => <script src="/assets/common.js" async="async"></script>
```

Some of the most common attributes are `async` and `defer`, where `async` will allow the script to be loaded in parallel to be parsed and evaluated as soon as possible and `defer` will indicate that the script is meant to be executed after the document has been parsed.

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/AssetTagHelper.html#method-i-javascript_include_tag)
for more information.

INFO: Internally, `javascript_include_tag` uses [`javascript_path` from the AssetUrlHelpers](https://edgeapi.rubyonrails.org/classes/ActionView/Helpers/AssetUrlHelper.html#method-i-javascript_path) to build the script path. <br><br>
If you want to include a JavaScript file from a different directory, you can use the `javascript_path` helper to get the path to the JavaScript file and then use the `javascript_include_tag` helper to generate the HTML `javascript_include_tag(javascript_path("common.js"))`

#### picture_tag

Returns an HTML picture tag for the source. It supports passing a String, an
Array, or a Block.

```ruby
picture_tag("icon.webp", "icon.png")
```

This generates the following HTML:

```html
<picture>
  <source srcset="/assets/icon.webp" type="image/webp" />
  <source srcset="/assets/icon.png" type="image/png" />
  <img src="/assets/icon.png" />
</picture>
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/AssetTagHelper.html#method-i-picture_tag)
for more information.

#### preload_link_tag

Returns a link tag that browsers can use to preload the source. The source can
be the path of a resource managed by the asset pipeline, a full path, or a URI.

```ruby
preload_link_tag "application.css"
# => <link rel="preload" href="/assets/application.css" as="style" type="text/css" />
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/AssetTagHelper.html#method-i-preload_link_tag)
for more information.

#### stylesheet_link_tag

Returns a stylesheet link tag for the sources specified as arguments. If you
don't specify an extension, `.css` will be appended automatically.

```ruby
stylesheet_link_tag "application"
# => <link href="/assets/application.css" rel="stylesheet" />
```

You can modify the link attributes by passing a hash as the last argument.

```ruby
stylesheet_link_tag "application", media: "all"
# => <link href="/assets/application.css" media="all" rel="stylesheet" />
```

`media` is used to specify the media type for the link. The most common media types are `all`, `screen`, `print`, and `speech`.

INFO: Internally, `stylesheet_link_tag` uses [`stylesheet_path` from the AssetUrlHelpers](https://edgeapi.rubyonrails.org/classes/ActionView/Helpers/AssetUrlHelper.html#method-i-stylesheet_path) to build the stylesheet path. <br><br>
If you want to include a stylesheet file from a different directory, you can use the `stylesheet_path` helper to get the path to the stylesheet file and then use the `stylesheet_link_tag` helper to generate the HTML `stylesheet_link_tag(stylesheet_path("common.js"))`

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/AssetTagHelper.html#method-i-stylesheet_link_tag)
for more information.


#### video_tag

Generate an HTML video tag with source(s), either as a single tag for a string
source or nested source tags within an array for multiple sources. The `sources`
can be full paths, files in your public videos directory, or Active Storage
attachments.

```ruby
video_tag("trailer")
# => <video src="/videos/trailer"></video>

video_tag(["trailer.ogg", "trailer.flv"])
# => <video><source src="/videos/trailer.ogg" /><source src="/videos/trailer.flv" /></video>
```

When the last parameter is a hash you can add HTML attributes using that parameter.

```ruby
video_tag("trailer", controls: true)
```
`controls` is a boolean attribute that indicates whether the video should have controls.

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/AssetTagHelper.html#method-i-video_tag)
for more information.

INFO: Internally, `video_tag` uses [`video_path` from the AssetUrlHelpers](https://edgeapi.rubyonrails.org/classes/ActionView/Helpers/AssetUrlHelper.html#method-i-video_path) to build the video path. <br><br>
If you want to include a video file from a different directory, you can use the `video_path` helper to get the path to the video file and then use the `video_tag` helper to generate the HTML `video_tag(video_path("trailers/trailer.mp4"))`

### AtomFeedHelper

#### atom_feed

This helper makes building an Atom feed easy. Here's a full usage example:

**config/routes.rb**

```ruby
resources :articles
```

**app/controllers/articles_controller.rb**

```ruby
def index
  @articles = Article.all

  respond_to do |format|
    format.html
    format.atom
  end
end
```

**app/views/articles/index.atom.builder**

```ruby
atom_feed do |feed|
  feed.title("Articles Index")
  feed.updated(@articles.first.created_at)

  @articles.each do |article|
    feed.entry(article) do |entry|
      entry.title(article.title)
      entry.content(article.body, type: 'html')

      entry.author do |author|
        author.name(article.author_name)
      end
    end
  end
end
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/AtomFeedHelper.html#method-i-atom_feed)
for more information.

### BenchmarkHelper

#### benchmark

Allows you to measure the execution time of a block in a template and records
the result to the log. Wrap this block around expensive operations or possible
bottlenecks to get a time reading for the operation.

```html+erb
<% benchmark "Process data files" do %>
  <%= expensive_files_operation %>
<% end %>
```

This would add something like "Process data files (0.34523)" to the log, which
you can then use to compare timings when optimizing your code.

See the [API
Documentation](https://api.rubyonrails.org/classes/ActiveSupport/Benchmarkable.html#method-i-benchmark)
for more information.

### CacheHelper

#### cache

A method for caching fragments of a view rather than an entire action or page.
This technique is useful for caching pieces like menus, lists of news topics,
static HTML fragments, and so on. This method takes a block that contains the
content you wish to cache. See [`AbstractController::Caching::Fragments`][] for
more information.

```erb
<% cache do %>
  <%= render "application/footer" %>
<% end %>
```

[`AbstractController::Caching::Fragments`]:
    https://api.rubyonrails.org/classes/AbstractController/Caching/Fragments.html

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/CacheHelper.html#method-i-cache)
for more information.

### CaptureHelper

#### capture

The `capture` method allows you to extract part of a template into a variable.
You can then use this variable anywhere in your templates or layout.

```html+erb
<% @greeting = capture do %>
  <p>Welcome! The date and time is <%= Time.now %></p>
<% end %>
```

The captured variable can then be used anywhere else.

```html+erb
<html>
  <head>
    <title>Welcome!</title>
  </head>
  <body>
    <%= @greeting %>
  </body>
</html>
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/CaptureHelper.html#method-i-capture)
for more information.

#### content_for

Calling `content_for` stores a block of markup in an identifier for later use.
You can make subsequent calls to the stored content in other templates or the
layout by passing the identifier as an argument to `yield`.

For example, let's say we have a standard application layout, but also a special
page that requires certain JavaScript that the rest of the site doesn't need. We
can use `content_for` to include this JavaScript on our special page without
fattening up the rest of the site.

**app/views/layouts/application.html.erb**

```html+erb
<html>
  <head>
    <title>Welcome!</title>
    <%= yield :special_script %>
  </head>
  <body>
    <p>Welcome! The date and time is <%= Time.now %></p>
  </body>
</html>
```

**app/views/articles/special.html.erb**

```html+erb
<p>This is a special page.</p>

<% content_for :special_script do %>
  <script>alert('Hello!')</script>
<% end %>
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/CaptureHelper.html#method-i-content_for)
for more information.

### DateHelper

#### distance_of_time_in_words

Reports the approximate distance in time between two Time or Date objects or
integers as seconds. Set `include_seconds` to true if you want more detailed
approximations.

```ruby
distance_of_time_in_words(Time.now, Time.now + 15.seconds)
# => less than a minute
distance_of_time_in_words(Time.now, Time.now + 15.seconds, include_seconds: true)
# => less than 20 seconds
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/DateHelper.html#method-i-distance_of_time_in_words)
for more information.

#### time_ago_in_words

Like `distance_of_time_in_words`, but where `to_time` is fixed to `Time.now`.

```ruby
time_ago_in_words(3.minutes.from_now) # => 3 minutes
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/DateHelper.html#method-i-time_ago_in_words)
for more information.

### DebugHelper

#### debug

Returns a `pre` tag that has object dumped by YAML. This creates a very readable
way to inspect an object.

```ruby
my_hash = { 'first' => 1, 'second' => 'two', 'third' => [1, 2, 3] }
debug(my_hash)
```

```html
<pre class='debug_dump'>---
first: 1
second: two
third:
- 1
- 2
- 3
</pre>
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/DebugHelper.html#method-i-debug)
for more information.

### FormHelper

Form helpers are designed to make working with models much easier compared to
using just standard HTML elements by providing a set of methods for creating
forms based on your models. This helper generates the HTML for forms, providing
a method for each sort of input (e.g., text, password, select, and so on). When
the form is submitted (i.e., when the user hits the submit button or form.submit
is called via JavaScript), the form inputs will be bundled into the params
object and passed back to the controller.

You can learn more about form helpers in the [Action View Form Helpers
Guide](form_helpers.html).

### JavaScriptHelper

Provides functionality for working with JavaScript in your views.

#### escape_javascript

Escape carrier returns and single and double quotes for JavaScript segments.

#### javascript_tag

Returns a JavaScript tag wrapping the provided code.

```ruby
javascript_tag "alert('All is good')"
```

```html
<script>
//<![CDATA[
alert('All is good')
//]]>
</script>
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/JavaScriptHelper.html#method-i-javascript_tag)
for more information.

### NumberHelper

Provides methods for converting numbers into formatted strings. Methods are
provided for phone numbers, currency, percentage, precision, positional
notation, and file size.

#### number_to_currency

Formats a number into a currency string (e.g., $13.65).

```ruby
number_to_currency(1234567890.50) # => $1,234,567,890.50
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/NumberHelper.html#method-i-number_to_currency)
for more information.

#### number_to_human

Pretty prints (formats and approximates) a number so it is more readable by
users; useful for numbers that can get very large.

```ruby
number_to_human(1234)    # => 1.23 Thousand
number_to_human(1234567) # => 1.23 Million
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/NumberHelper.html#method-i-number_to_human)
for more information.

#### number_to_human_size

Formats the bytes in size into a more understandable representation; useful for
reporting file sizes to users.

```ruby
number_to_human_size(1234)    # => 1.21 KB
number_to_human_size(1234567) # => 1.18 MB
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/NumberHelper.html#method-i-number_to_human_size)
for more information.

#### number_to_percentage

Formats a number as a percentage string.

```ruby
number_to_percentage(100, precision: 0) # => 100%
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/NumberHelper.html#method-i-number_to_percentage)
for more information.

#### number_to_phone

Formats a number into a phone number (US by default).

```ruby
number_to_phone(1235551234) # => 123-555-1234
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/NumberHelper.html#method-i-number_to_phone)
for more information.

#### number_with_delimiter

Formats a number with grouped thousands using a delimiter.

```ruby
number_with_delimiter(12345678) # => 12,345,678
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/NumberHelper.html#method-i-number_with_delimiter)
for more information.

#### number_with_precision

Formats a number with the specified level of `precision`, which defaults to 3.

```ruby
number_with_precision(111.2345)               # => 111.235
number_with_precision(111.2345, precision: 2) # => 111.23
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/NumberHelper.html#method-i-number_with_precision)
for more information.

### SanitizeHelper

The SanitizeHelper module provides a set of methods for scrubbing text of
undesired HTML elements.

#### sanitize

This sanitize helper will HTML encode all tags and strip all attributes that
aren't specifically allowed.

```ruby
sanitize @article.body
```

If either the `:attributes` or `:tags` options are passed, only the mentioned
attributes and tags are allowed and nothing else.

```ruby
sanitize @article.body, tags: %w(table tr td), attributes: %w(id class style)
```

To change defaults for multiple uses, for example adding table tags to the
default:

```ruby
class Application < Rails::Application
  config.action_view.sanitized_allowed_tags = 'table', 'tr', 'td'
end
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/SanitizeHelper.html#method-i-sanitize)
for more information.

#### sanitize_css(style)

Sanitizes a block of CSS code.

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/SanitizeHelper.html#method-i-sanitize_css)
for more information.

#### strip_links(html)

Strips all link tags from text leaving just the link text.

```ruby
strip_links('<a href="https://rubyonrails.org">Ruby on Rails</a>')
# => Ruby on Rails
```

```ruby
strip_links('emails to <a href="mailto:me@email.com">me@email.com</a>.')
# => emails to me@email.com.
```

```ruby
strip_links('Blog: <a href="http://myblog.com/">Visit</a>.')
# => Blog: Visit.
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/SanitizeHelper.html#method-i-strip_links)
for more information.

#### strip_tags(html)

Strips all HTML tags from the html, including comments. This functionality is
powered by the rails-html-sanitizer gem.

```ruby
strip_tags("Strip <i>these</i> tags!")
# => Strip these tags!
```

```ruby
strip_tags("<b>Bold</b> no more!  <a href='more.html'>See more</a>")
# => Bold no more!  See more
```

NB: The output may still contain unescaped '<', '>', '&' characters and confuse
browsers.

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/SanitizeHelper.html#method-i-strip_tags)
for more information.

### UrlHelper

Provides methods to make links and get URLs that depend on the routing
subsystem.

#### url_for

Returns the URL for the set of `options` provided.

##### Examples

```ruby
url_for @profile
# => /profiles/1

url_for [ @hotel, @booking, page: 2, line: 3 ]
# => /hotels/1/bookings/1?line=3&page=2

url_for @post # given a composite primary key [:blog_id, :id]
# => /posts/1_2
```

#### link_to

Links to a URL derived from `url_for` under the hood. Primarily used to create
RESTful resource links, which for this example, boils down to when passing
models to `link_to`.

**Examples**

```ruby
link_to "Profile", @profile
# => <a href="/profiles/1">Profile</a>

link_to "Book", @book # given a composite primary key [:author_id, :id]
# => <a href="/books/2_1">Book</a>
```

You can use a block as well if your link target can't fit in the name parameter.
ERB example:

```html+erb
<%= link_to @profile do %>
  <strong><%= @profile.name %></strong> -- <span>Check it out!</span>
<% end %>
```

would output:

```html
<a href="/profiles/1">
  <strong>David</strong> -- <span>Check it out!</span>
</a>
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/UrlHelper.html#method-i-link_to)
for more information.

#### button_to

Generates a form that submits to the passed URL. The form has a submit button
with the value of the `name`.

##### Examples

```html+erb
<%= button_to "Sign in", sign_in_path %>
```

would roughly output something like:

```html
<form method="post" action="/sessions" class="button_to">
  <input type="submit" value="Sign in" />
</form>
```

See the [API
Documentation](https://api.rubyonrails.org/classes/ActionView/Helpers/UrlHelper.html#method-i-button_to)
for more information.

### CsrfHelper

Returns meta tags "csrf-param" and "csrf-token" with the name of the cross-site
request forgery protection parameter and token, respectively.

```erb
<%= csrf_meta_tags %>
```

NOTE: Regular forms generate hidden fields so they do not use these tags. More
details can be found in the [Rails Security
Guide](security.html#cross-site-request-forgery-csrf).
