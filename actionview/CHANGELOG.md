## Rails 5.0.2 (March 01, 2017) ##

*   Allow render locals to be assigned to instance variables in a view.

    Fixes #27480.

    *Andrew White*

*   Return correct object name in form helper method after `fields_for`.

    Fixes #26931.

    *Yuji Yaginuma*


## Rails 5.0.1 (December 21, 2016) ##

*   No changes.


## Rails 5.0.1.rc2 (December 10, 2016) ##

*   Restore support for locals named `_`, `arg`, `args`, and `block`.

    Fixes #27302.

    *Toshimaru*


## Rails 5.0.1.rc1 (December 01, 2016) ##

*   Fix support to `ActionController::Parameters` in `button_to`.

    *Jon Moss*

*   Render now accepts any keys for locals, including reserved words

    Only locals with valid variable names get set directly. Others
    will still be available in local_assigns.

    Example of render with reserved words:

    ```erb
    <%= render "example", class: "text-center", message: "Hello world!" %>

    <!-- _example.html.erb: -->
    <%= tag.div class: local_assigns[:class] do %>
      <p><%= message %></p>
    <% end %>
    ```

    *Peter Schilling*, *Matthew Draper*

*   Changed partial rendering with a collection to allow collections which
    implement `to_a`.

    Extracting the collection option had an optimization to avoid unnecessary
    queries of ActiveRecord Relations by calling `#to_ary` on the given
    collection. Instances of `Enumerator` or `Enumerable` are valid
    collections, but they do not implement `#to_ary`. By changing this to
    `#to_a`, they will now be extracted and rendered as expected.

    *Steven Harman*

*   Fix `ActionView::Helpers#current_page?` to work properly even with
    a trailing slash.

    Fixes #19472.

    *Stan Lo*


## Rails 5.0.0 (June 30, 2016) ##

*   Changed partial rendering with a collection to allow collections which
    implement `to_a`.

    Extracting the collection option had an optimization to avoid unnecessary
    queries of ActiveRecord Relations by calling `#to_ary` on the given
    collection. Instances of `Enumerator` or `Enumerable` are valid
    collections, but they do not implement `#to_ary`. By changing this to
    `#to_a`, they will now be extracted and rendered as expected.

    *Steven Harman*

*   Change `datetime_field` and `datetime_field_tag` to generate `datetime-local` fields.

    As a new specification of the HTML 5 the text field type `datetime` will no longer exist
    and it is recomended to use `datetime-local`.
    Ref: https://html.spec.whatwg.org/multipage/forms.html#local-date-and-time-state-(type=datetime-local)

    *Herminio Torres*

*   Raw template handler (which is also the default template handler in Rails 5) now outputs
    HTML-safe strings.

    In Rails 5 the default template handler was changed to the raw template handler. Because
    the ERB template handler escaped strings by default this broke some applications that
    expected plain JS or HTML files to be rendered unescaped. This fixes the issue caused
    by changing the default handler by changing the Raw template handler to output HTML-safe
    strings.

    *Eileen M. Uchitelle*

*   `select_tag`'s `include_blank` option for generation for blank option tag, now adds an empty space label,
     when the value as well as content for option tag are empty, so that we confirm with html specification.
     Ref: https://www.w3.org/TR/html5/forms.html#the-option-element.

    Generation of option before:

    ```html
    <option value=""></option>
    ```

    Generation of option after:

    ```html
    <option value="" label=" "></option>
    ```

    *Vipul A M *

*   `date_select` helper `:with_css_classes` option now accepts a hash of strings
    for `:year`, `:month`, `:day`, `:hour`, `:minute`, `:second` that will extend
    the select type with the given css class value.

    ```erb
    <%= f.date_select :birthday, with_css_classes: { month: "my-month", year: "my-year" } %>
    ```

    ```html
    <select id="user_birthday_3i" name="user[birthday(3i)]">…</select>
    <select id="user_birthday_2i" name="user[birthday(2i)]" class="my-month">…</select>
    <select id="user_birthday_1i" name="user[birthday(1i)]" class="my-year">…</select>
    ```

    *Matthias Neumayr*

*   Add `to_sentence` helper that is a HTML-safe aware version of `Array#to_sentence`.

    *Neil Matatall*

*   Added log "Rendering ...", when starting to render a template to log that
    we have started rendering something. This helps to easily identify the origin
    of queries in the log whether they came from controller or views.

    *Vipul A M and Prem Sichanugrist*

*   Collection rendering can cache and fetch multiple partials at once.

    Collections rendered as:

    ```ruby
    <%= render partial: 'notifications/notification', collection: @notifications, as: :notification, cached: true %>
    ```

    will read several partials from cache at once. The templates in the collection
    that haven't been cached already will automatically be written to cache. Works
    great alongside individual template fragment caching. For instance if the
    template the collection renders is cached like:

    ```ruby
    # notifications/_notification.html.erb
    <% cache notification do %>
      <%# ... %>
    <% end %>
    ```

    Then any collection renders shares that cache when attempting to read multiple
    ones at once.

    *Kasper Timm Hansen*

*   Add support for nested hashes/arrays to `:params` option of `button_to` helper.

    *James Coleman*

*   Fix stripping the digest from the automatically generated img tag alt
    attribute when assets are handled by Sprockets >=3.0.

    *Bart de Water*

*   Create a new `ActiveSupport::SafeBuffer` instance when `content_for` is flushed.

    Fixes #19890.

    *Yoong Kang Lim*

*   Fix `collection_radio_buttons` hidden_field name and make it appear
    before the actual input radio tags to make the real value override
    the hidden when passed.

    Fixes #22773.

    *Santiago Pastorino*

*   `ActionView::TestCase::Controller#params` returns an instance of
    `ActionController::Parameters`.

    *Justin Coyne*

*   Fix regression in `submit_tag` when a symbol is used as label argument.

    *Yuuji Yaginuma*

*   `I18n.translate` helper will wrap the missing translation keys
     in a <span> tag only if `debug_missing_translation` configuration
     be true. Default value is `true`. For example in `application.rb`:

       # in order to turn off missing key wrapping
       config.action_view.debug_missing_translation = false

     *Sameer Rahmani*

*   Respect value of `:object` if `:object` is false when rendering.

    Fixes #22260.

    *Yuichiro Kaneko*

*   Generate `week_field` input values using a 1-based index and not a 0-based index
    as per the W3 spec: http://www.w3.org/TR/html-markup/datatypes.html#form.data.week

    *Christoph Geschwind*

*   Allow `host` option in `javascript_include_tag` and `stylesheet_link_tag` helpers

    *Grzegorz Witek*

*   Restrict `url_for :back` to valid, non-JavaScript URLs. GH#14444

    *Damien Burke*

*   Allow `date_select` helper selected option to accept hash like the default options.

    *Lecky Lao*

*   Collection input propagates input's `id` to the label's `for` attribute when
    using html options as the last element of collection.

    *Vasiliy Ermolovich*

*   Add a `hidden_field` on the `collection_radio_buttons` to avoid raising an error
    when the only input on the form is the `collection_radio_buttons`.

    *Mauro George*

*   `url_for` does not modify its arguments when generating polymorphic URLs.

    *Bernerd Schaefer*

*   `number_to_currency` and `number_with_delimiter` now accept a custom `delimiter_pattern` option
    to handle placement of delimiter, to support currency formats like INR.

    Example:

        number_to_currency(1230000, delimiter_pattern: /(\d+?)(?=(\d\d)+(\d)(?!\d))/, unit: '₹', format: "%u %n")
        # => '₹ 12,30,000.00'

    *Vipul A M*

*   Make `disable_with` the default behavior for submit tags. Disables the
    button on submit to prevent double submits.

    *Justin Schiff*

*   Add a break_sequence option to word_wrap so you can specify a custom break.

    *Mauricio Gomez*

*   Add wildcard matching to explicit dependencies.

    Turns:

    ```erb
    <% # Template Dependency: recordings/threads/events/subscribers_changed %>
    <% # Template Dependency: recordings/threads/events/completed %>
    <% # Template Dependency: recordings/threads/events/uncompleted %>
    ```

    Into:

    ```erb
    <% # Template Dependency: recordings/threads/events/* %>
    ```

    *Kasper Timm Hansen*

*   Allow defining explicit collection caching using a `# Template Collection: ...`
    directive inside templates.

    *Dov Murik*

*   Asset helpers raise `ArgumentError` when `nil` is passed as a source.

    *Anton Kolomiychuk*

*   Always attach the template digest to the cache key for collection caching
    even when `virtual_path` is not available from the view context.
    Which could happen if the rendering was done directly in the controller
    and not in a template.

    Fixes #20535.

    *Roque Pinel*

*   Improve detection of partial templates eligible for collection caching,
    now allowing multi-line comments at the beginning of the template file.

    *Dov Murik*

*   Raise an `ArgumentError` when a false value for `include_blank` is passed to a
    required select field (to comply with the HTML5 spec).

    *Grey Baker*

*   Do not put partial name to `local_assigns` when rendering without
    an object or a collection.

    *Henrik Nygren*

*   Remove `:rescue_format` option for `translate` helper since it's no longer
    supported by I18n.

    *Bernard Potocki*

*   `translate` should handle `raise` flag correctly in case of both main and default
    translation is missing.

    Fixes #19967.

    *Bernard Potocki*

*   Load the `default_form_builder` from the controller on initialization, which overrides
    the global config if it is present.

    *Kevin McPhillips*

*   Accept lambda as `child_index` option in `fields_for` method.

    *Karol Galanciak*

*   `translate` allows `default: [[]]` again for a default value of `[]`.

    Fixes #19640.

    *Adam Prescott*

*   `translate` should accept nils as members of the `:default`
    parameter without raising a translation missing error.

    Fixes #19419.

    *Justin Coyne*

*   `number_to_percentage` does not crash with `Float::NAN` or `Float::INFINITY`
    as input when `precision: 0` is used.

    Fixes #19227.

    *Yves Senn*

*   Fixed the translation helper method to accept different default values types
    besides String.

    *Ulisses Almeida*

*   Fixed a dependency tracker bug that caused template dependencies not
    count layouts as dependencies for partials.

    *Juho Leinonen*

*   Extracted `ActionView::Helpers::RecordTagHelper` to external gem
    (`record_tag_helper`) and added removal notices.

    *Todd Bealmear*

*   Allow to pass an integer value to `size` option in `image_tag` and `video_tag`.

    This makes the behavior more consistent with `width` or `height` options.

    *Mehdi Lahmam*

*   Partial template name does no more have to be a valid Ruby identifier.

    There used to be a naming rule that the partial name should start with
    underscore, and should be followed by any combination of letters, numbers
    and underscores.
    But now we can give our partials any name starting with underscore, such as
    _🍔.html.erb.

    *Akira Matsuda*

*   Change the default template handler from `ERB` to `Raw`.

    Files without a template handler in their extension will be rendered using the raw
    handler instead of ERB.

    *Rafael Mendonça França*

*   Remove deprecated `AbstractController::Base::parent_prefixes`.

    *Rafael Mendonça França*

*   Default translations that have a lower precedence than a html safe default,
    but are not themselves safe, should not be marked as html_safe.

    *Justin Coyne*

*   Make possible to use blocks with short version of `render "partial"` helper.

    *Nikolay Shebanov*

*   Add a `hidden_field` on the `file_field` to avoid raising an error when the only
    input on the form is the `file_field`.

    *Mauro George*

*   Add support for Reply-To field in `mail_to` helper.

    *Mark Dodwell*

*   Add an explicit error message, in `ActionView::PartialRenderer` for partial
    `rendering`, when the value of option `as` has invalid characters.

    *Angelo Capilleri*

*   Allow entries without a link tag in `AtomFeedHelper`.

    *Daniel Gomez de Souza*

Please check [4-2-stable](https://github.com/rails/rails/blob/4-2-stable/actionview/CHANGELOG.md) for previous changes.
