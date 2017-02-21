## Rails 4.2.8 (February 21, 2017) ##

*   No changes.


## Rails 4.2.7 (July 12, 2016) ##

*   No changes.


## Rails 4.2.6 (March 07, 2016) ##

*   Fix stripping the digest from the automatically generated img tag alt
    attribute when assets are handled by Sprockets >=3.0.

    *Bart de Water*

*   Create a new `ActiveSupport::SafeBuffer` instance when `content_for` is flushed.

    Fixes #19890

    *Yoong Kang Lim*

*   Respect value of `:object` if `:object` is false when rendering.

    Fixes #22260.

    *Yuichiro Kaneko*

*   Generate `week_field` input values using a 1-based index and not a 0-based index
    as per the W3 spec: http://www.w3.org/TR/html-markup/datatypes.html#form.data.week

    *Christoph Geschwind*


## Rails 4.2.5.2 (February 26, 2016) ##

*   Do not allow render with unpermitted parameter.

    Fixes CVE-2016-2098.

    *Arthur Neves*


## Rails 4.2.5.1 (January 25, 2015) ##

*   Adds boolean argument outside_app_allowed to `ActionView::Resolver#find_templates`
    method.

    *Aaron Patterson*


## Rails 4.2.5 (November 12, 2015) ##

*   Fix `mail_to` when called with `nil` as argument.

    *Rafael Mendonça França*

*   `url_for` does not modify its arguments when generating polymorphic URLs.

    *Bernerd Schaefer*


## Rails 4.2.4 (August 24, 2015) ##

* No Changes *


## Rails 4.2.3 (June 25, 2015) ##

*   `translate` should handle `raise` flag correctly in case of both main and default
    translation is missing.

    Fixes #19967

    *Bernard Potocki*

*   `translate` allows `default: [[]]` again for a default value of `[]`.

    Fixes #19640.

    *Adam Prescott*

*   `translate` should accept nils as members of the `:default`
    parameter without raising a translation missing error.  Fixes a
    regression introduced 362557e.

    Fixes #19419

    *Justin Coyne*

*   `number_to_percentage` does not crash with `Float::NAN` or `Float::INFINITY`
    as input when `precision: 0` is used.

    Fixes #19227.

    *Yves Senn*


## Rails 4.2.2 (June 16, 2015) ##

* No Changes *


## Rails 4.2.1 (March 19, 2015) ##

*   Default translations that have a lower precedence than an html safe default,
    but are not themselves safe, should not be marked as html_safe.

    *Justin Coyne*

*   Added an explicit error message, in `ActionView::PartialRenderer`
    for partial `rendering`, when the value of option `as` has invalid characters.

    *Angelo Capilleri*


## Rails 4.2.0 (December 20, 2014) ##

*   Local variable in a partial is now available even if a falsy value is
    passed to `:object` when rendering a partial.

    Fixes #17373.

    *Agis Anastasopoulos*

*   Add support for `:enforce_utf8` option in `form_for`.

    This is the same option that was added in 06388b0 to `form_tag` and allows
    users to skip the insertion of the UTF8 enforcer tag in a form.

    * claudiob *

*   Fix a bug that <%= foo(){ %> and <%= foo()do %> in view templates were not regarded
    as Ruby block calls.

    * Akira Matsuda *

*   Update `select_tag` to work correctly with `:include_blank` option passing a string.

    Fixes #16483.

    *Frank Groeneveld*

*   Changed the meaning of `render "foo/bar"`.

    Previously, calling `render "foo/bar"` in a controller action is equivalent
    to `render file: "foo/bar"`. In Rails 4.2, this has been changed to mean
    `render template: "foo/bar"` instead. If you need to render a file, please
    change your code to use the explicit form (`render file: "foo/bar"`) instead.

    *Jeremy Jackson*

*   Add support for ARIA attributes in tags.

    Example:

        <%= f.text_field :name, aria: { required: "true", hidden: "false" } %>

    now generates:

         <input aria-hidden="false" aria-required="true" id="user_name" name="user[name]" type="text">

    *Paola Garcia Casadiego*

*   Provide a `builder` object when using the `label` form helper in block form.

    The new `builder` object responds to `translation`, allowing I18n fallback support
    when you want to customize how a particular label is presented.

    *Alex Robbin*

*   Add I18n support for input/textarea placeholder text.

    Placeholder I18n follows the same convention as `label` I18n.

    *Alex Robbin*

*   Fix that render layout: 'messages/layout' should also be added to the dependency tracker tree.

    *DHH*

*   Add `PartialIteration` object used when rendering collections.

    The iteration object is available as the local variable
    `#{template_name}_iteration` when rendering partials with collections.

    It gives access to the `size` of the collection being iterated over,
    the current `index` and two convenience methods `first?` and `last?`.

    *Joel Junström*, *Lucas Uyezu*

*   Return an absolute instead of relative path from an asset url in the case
    of the `asset_host` proc returning nil.

    *Jolyon Pawlyn*

*   Fix `html_escape_once` to properly handle hex escape sequences (e.g. &#x1a2b;).

    *John F. Douthat*

*   Added String support for min and max properties for date field helpers.

    *Todd Bealmear*

*   The `highlight` helper now accepts a block to be used instead of the `highlighter`
    option.

    *Lucas Mazza*

*   The `except` and `highlight` helpers now accept regular expressions.

    *Jan Szumiec*

*   Flatten the array parameter in `safe_join`, so it behaves consistently with
    `Array#join`.

    *Paul Grayson*

*   Honor `html_safe` on array elements in tag values, as we do for plain string
    values.

    *Paul Grayson*

*   Add `ActionView::Template::Handler.unregister_template_handler`.

    It performs the opposite of `ActionView::Template::Handler.register_template_handler`.

    *Zuhao Wan*

*   Bring `cache_digest` rake tasks up-to-date with the latest API changes.

    *Jiri Pospisil*

*   Allow custom `:host` option to be passed to `asset_url` helper that
    overwrites `config.action_controller.asset_host` for particular asset.

    *Hubert Łępicki*

*   Deprecate `AbstractController::Base.parent_prefixes`.
    Override `AbstractController::Base.local_prefixes` when you want to change
    where to find views.

    *Nick Sutterer*

*   Take label values into account when doing I18n lookups for model attributes.

    The following:

        # form.html.erb
        <%= form_for @post do |f| %>
          <%= f.label :type, value: "long" %>
        <% end %>

        # en.yml
        en:
          activerecord:
            attributes:
              post/long: "Long-form Post"

    Used to simply return "long", but now it will return "Long-form
    Post".

    *Joshua Cody*

*   Change `asset_path` to use File.join to create proper paths:

    Before:

        https://some.host.com//assets/some.js

    After:

        https://some.host.com/assets/some.js

    *Peter Schröder*

*   Change `favicon_link_tag` default mimetype from `image/vnd.microsoft.icon` to
    `image/x-icon`.

    Before:

        # => favicon_link_tag 'myicon.ico'
        <link href="/assets/myicon.ico" rel="shortcut icon" type="image/vnd.microsoft.icon" />

    After:

        # => favicon_link_tag 'myicon.ico'
        <link href="/assets/myicon.ico" rel="shortcut icon" type="image/x-icon" />

    *Geoffroy Lorieux*

*   Remove wrapping div with inline styles for hidden form fields.

    We are dropping HTML 4.01 and XHTML strict compliance since input tags directly
    inside a form are valid HTML5, and the absence of inline styles help in validating
    for Content Security Policy.

    *Joost Baaij*

*   `collection_check_boxes` respects `:index` option for the hidden field name.

    Fixes #14147.

    *Vasiliy Ermolovich*

*   `date_select` helper with option `with_css_classes: true` does not overwrite other classes.

    *Izumi Wong-Horiuchi*

*   `number_to_percentage` does not crash with `Float::NAN` or `Float::INFINITY`
    as input.

    Fixes #14405.

    *Yves Senn*

*   Add `include_hidden` option to `collection_check_boxes` helper.

    *Vasiliy Ermolovich*

*   Fixed a problem where the default options for the `button_tag` helper are not
    applied correctly.

    Fixes #14254.

    *Sergey Prikhodko*

*   Take variants into account when calculating template digests in ActionView::Digestor.

    The arguments to ActionView::Digestor#digest are now being passed as a hash
    to support variants and allow more flexibility in the future. The support for
    regular (required) arguments is deprecated and will be removed in Rails 5.0 or later.

    *Piotr Chmolowski, Łukasz Strzałkowski*

Please check [4-1-stable](https://github.com/rails/rails/blob/4-1-stable/actionview/CHANGELOG.md) for previous changes.
