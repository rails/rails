## Rails 7.0.3.1 (July 12, 2022) ##

*   No changes.


## Rails 7.0.3 (May 09, 2022) ##

*   Ensure models passed to `form_for` attempt to call `to_model`.

    *Sean Doyle*

## Rails 7.0.2.4 (April 26, 2022) ##

*   Fix and add protections for XSS in `ActionView::Helpers` and `ERB::Util`.

    Escape dangerous characters in names of tags and names of attributes in the
    tag helpers, following the XML specification. Rename the option
    `:escape_attributes` to `:escape`, to simplify by applying the option to the
    whole tag.

    *Álvaro Martín Fraguas*

## Rails 7.0.2.3 (March 08, 2022) ##

*   No changes.


## Rails 7.0.2.2 (February 11, 2022) ##

*   No changes.


## Rails 7.0.2.1 (February 11, 2022) ##

*   No changes.


## Rails 7.0.2 (February 08, 2022) ##

*   Ensure `preload_link_tag` preloads JavaScript modules correctly.

    *Máximo Mussini*

*   Fix `stylesheet_link_tag` and similar helpers are being used to work in objects with
    a `response` method.

    *dark-panda*


## Rails 7.0.1 (January 06, 2022) ##

*   Fix `button_to` to work with a hash parameter as URL.

    *MingyuanQin*

*   Fix `link_to` with a model passed as an argument twice.

    *Alex Ghiculescu*


## Rails 7.0.0 (December 15, 2021) ##

*   Support `include_hidden:` option in calls to
    `ActionView::Helper::FormBuilder#file_field` with `multiple: true` to
    support submitting an empty collection of files.

    ```ruby
    form.file_field :attachments, multiple: true
    # => <input type="hidden" autocomplete="off" name="post[attachments][]" value="">
         <input type="file" multiple="multiple" id="post_attachments" name="post[attachments][]">

    form.file_field :attachments, multiple: true, include_hidden: false
    # => <input type="file" multiple="multiple" id="post_attachments" name="post[attachments][]">
    ```

    *Sean Doyle*

*   Fix `number_with_precision(raise: true)` always raising even on valid numbers.

    *Pedro Moreira*


## Rails 7.0.0.rc3 (December 14, 2021) ##

*   No changes.


## Rails 7.0.0.rc2 (December 14, 2021) ##

*   No changes.

## Rails 7.0.0.rc1 (December 06, 2021) ##

*   Support `fields model: [@nested, @model]` the same way as `form_with model:
    [@nested, @model]`.

    *Sean Doyle*

*   Infer HTTP verb `[method]` from a model or Array with model as the first
    argument to `button_to` when combined with a block:

    ```ruby
    button_to(Workshop.find(1)){ "Update" }
    #=> <form method="post" action="/workshops/1" class="button_to">
    #=>   <input type="hidden" name="_method" value="patch" autocomplete="off" />
    #=>   <button type="submit">Update</button>
    #=> </form>

    button_to([ Workshop.find(1), Session.find(1) ]) { "Update" }
    #=> <form method="post" action="/workshops/1/sessions/1" class="button_to">
    #=>   <input type="hidden" name="_method" value="patch" autocomplete="off" />
    #=>   <button type="submit">Update</button>
    #=> </form>
    ```

    *Sean Doyle*

*   Support passing a Symbol as the first argument to `FormBuilder#button`:

    ```ruby
    form.button(:draft, value: true)
    # => <button name="post[draft]" value="true" type="submit">Create post</button>

    form.button(:draft, value: true) do
      content_tag(:strong, "Save as draft")
    end
    # =>  <button name="post[draft]" value="true" type="submit">
    #       <strong>Save as draft</strong>
    #     </button>
    ```

    *Sean Doyle*

*   Introduce the `field_name` view helper, along with the
    `FormBuilder#field_name` counterpart:

    ```ruby
    form_for @post do |f|
      f.field_tag :tag, name: f.field_name(:tag, multiple: true)
      # => <input type="text" name="post[tag][]">
    end
    ```

    *Sean Doyle*

*   Execute the `ActionView::Base.field_error_proc` within the context of the
    `ActionView::Base` instance:

    ```ruby
    config.action_view.field_error_proc = proc { |html| content_tag(:div, html, class: "field_with_errors") }
    ```

    *Sean Doyle*

*   Add support for `button_to ..., authenticity_token: false`

    ```ruby
    button_to "Create", Post.new, authenticity_token: false
    # => <form class="button_to" method="post" action="/posts"><button type="submit">Create</button></form>

    button_to "Create", Post.new, authenticity_token: true
    # => <form class="button_to" method="post" action="/posts"><button type="submit">Create</button><input type="hidden" name="form_token" value="abc123..." autocomplete="off" /></form>

    button_to "Create", Post.new, authenticity_token: "secret"
    # => <form class="button_to" method="post" action="/posts"><button type="submit">Create</button><input type="hidden" name="form_token" value="secret" autocomplete="off" /></form>
    ```

    *Sean Doyle*

*   Support rendering `<form>` elements _without_ `[action]` attributes by:

    * `form_with url: false` or `form_with ..., html: { action: false }`
    * `form_for ..., url: false` or `form_for ..., html: { action: false }`
    * `form_tag false` or `form_tag ..., action: false`
    * `button_to "...", false` or `button_to(false) { ... }`

    *Sean Doyle*

*   Add `:day_format` option to `date_select`

        date_select("article", "written_on", day_format: ->(day) { day.ordinalize })
        # generates day options like <option value="1">1st</option>\n<option value="2">2nd</option>...

    *Shunichi Ikegami*

*   Allow `link_to` helper to infer link name from `Model#to_s` when it
    is used with a single argument:

        link_to @profile
        #=> <a href="/profiles/1">Eileen</a>

    This assumes the model class implements a `to_s` method like this:

        class Profile < ApplicationRecord
          # ...
          def to_s
            name
          end
        end

    Previously you had to supply a second argument even if the `Profile`
    model implemented a `#to_s` method that called the `name` method.

        link_to @profile, @profile.name
        #=> <a href="/profiles/1">Eileen</a>

    *Olivier Lacan*

*   Support svg unpaired tags for `tag` helper.

        tag.svg { tag.use('href' => "#cool-icon") }
        # => <svg><use href="#cool-icon"></svg>

    *Oleksii Vasyliev*


## Rails 7.0.0.alpha2 (September 15, 2021) ##

*   No changes.


## Rails 7.0.0.alpha1 (September 15, 2021) ##

*   Improves the performance of ActionView::Helpers::NumberHelper formatters by avoiding the use of
    exceptions as flow control.

    *Mike Dalessio*

*   `preload_link_tag` properly inserts `as` attributes for files with `image` MIME types, such as JPG or SVG.

    *Nate Berkopec*

*   Add `weekday_options_for_select` and `weekday_select` helper methods. Also adds `weekday_select` to `FormBuilder`.

    *Drew Bragg*, *Dana Kashubeck*, *Kasper Timm Hansen*

*   Add `caching?` helper that returns whether the current code path is being cached and `uncacheable!` to denote helper methods that can't participate in fragment caching.

    *Ben Toews*, *John Hawthorn*, *Kasper Timm Hansen*, *Joel Hawksley*

*   Add `include_seconds` option for `time_field`.

        <%= form.time_field :foo, include_seconds: false %>
        # => <input value="16:22" type="time" />

    Default includes seconds:

        <%= form.time_field :foo %>
        # => <input value="16:22:01.440" type="time" />

    This allows you to take advantage of [different rendering options](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input/time#time_value_format) in some browsers.

    *Alex Ghiculescu*

*   Improve error messages when template file does not exist at absolute filepath.

    *Ted Whang*

*   Add `:country_code` option to `sms_to` for consistency with `phone_to`.

    *Jonathan Hefner*

*   OpenSSL constants are now used for Digest computations.

    *Dirkjan Bussink*

*   The `translate` helper now passes `default` values that aren't
    translation keys through `I18n.translate` for interpolation.

    *Jonathan Hefner*

*   Adds option `extname` to `stylesheet_link_tag` to skip default
    `.css` extension appended to the stylesheet path.

    Before:

    ```ruby
    stylesheet_link_tag "style.less"
    # <link href="/stylesheets/style.less.scss" rel="stylesheet">
    ```

    After:

    ```ruby
    stylesheet_link_tag "style.less", extname: false, skip_pipeline: true, rel: "stylesheet/less"
    # <link href="/stylesheets/style.less" rel="stylesheet/less">
    ```

    *Abhay Nikam*

*   Deprecate `render` locals to be assigned to instance variables.

    *Petrik de Heus*

*   Remove legacy default `media=screen` from `stylesheet_link_tag`.

    *André Luis Leal Cardoso Junior*

*   Change `ActionView::Helpers::FormBuilder#button` to transform `formmethod`
    attributes into `_method="$VERB"` Form Data to enable varied same-form actions:

        <%= form_with model: post, method: :put do %>
          <%= form.button "Update" %>
          <%= form.button "Delete", formmethod: :delete %>
        <% end %>
        <%# => <form action="posts/1">
            =>   <input type="hidden" name="_method" value="put">
            =>   <button type="submit">Update</button>
            =>   <button type="submit" formmethod="post" name="_method" value="delete">Delete</button>
            => </form>
        %>

    *Sean Doyle*

*   Change `ActionView::Helpers::UrlHelper#button_to` to *always* render a
    `<button>` element, regardless of whether or not the content is passed as
    the first argument or as a block.

        <%= button_to "Delete", post_path(@post), method: :delete %>
        # => <form action="/posts/1"><input type="hidden" name="_method" value="delete"><button type="submit">Delete</button></form>

        <%= button_to post_path(@post), method: :delete do %>
          Delete
        <% end %>
        # => <form action="/posts/1"><input type="hidden" name="_method" value="delete"><button type="submit">Delete</button></form>

    *Sean Doyle*, *Dusan Orlovic*

*   Add `config.action_view.preload_links_header` to allow disabling of
    the `Link` header being added by default when using `stylesheet_link_tag`
    and `javascript_include_tag`.

    *Andrew White*

*   The `translate` helper now resolves `default` values when a `nil` key is
    specified, instead of always returning `nil`.

    *Jonathan Hefner*

*   Add `config.action_view.image_loading` to configure the default value of
    the `image_tag` `:loading` option.

    By setting `config.action_view.image_loading = "lazy"`, an application can opt in to
    lazy loading images sitewide, without changing view code.

    *Jonathan Hefner*

*   `ActionView::Helpers::FormBuilder#id` returns the value
    of the `<form>` element's `id` attribute. With a `method` argument, returns
    the `id` attribute for a form field with that name.

        <%= form_for @post do |f| %>
          <%# ... %>

          <% content_for :sticky_footer do %>
            <%= form.button(form: f.id) %>
          <% end %>
        <% end %>

    *Sean Doyle*

*   `ActionView::Helpers::FormBuilder#field_id` returns the value generated by
    the FormBuilder for the given attribute name.

        <%= form_for @post do |f| %>
          <%= f.label :title %>
          <%= f.text_field :title, aria: { describedby: f.field_id(:title, :error) } %>
          <%= tag.span("is blank", id: f.field_id(:title, :error) %>
        <% end %>

    *Sean Doyle*

*   Add `tag.attributes` to transform a Hash into HTML Attributes, ready to be
    interpolated into ERB.

        <input <%= tag.attributes(type: :text, aria: { label: "Search" }) %> >
        # => <input type="text" aria-label="Search">

    *Sean Doyle*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/actionview/CHANGELOG.md) for previous changes.
