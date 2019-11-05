## Rails 6.0.1 (November 5, 2019) ##

*   UJS avoids `Element.closest()` for IE 9 compatibility.

    *George Claghorn*


## Rails 6.0.0 (August 16, 2019) ##

*   ActionView::Helpers::SanitizeHelper: support rails-html-sanitizer 1.1.0.

    *Juanito Fatas*


## Rails 6.0.0.rc2 (July 22, 2019) ##

*   Fix `select_tag` so that it doesn't change `options` when `include_blank` is present.

    *Younes SERRAJ*


## Rails 6.0.0.rc1 (April 24, 2019) ##

*   Fix partial caching skips same item issue

    If we render cached collection partials with repeated items, those repeated items
    will get skipped. For example, if you have 5 identical items in your collection, Rails
    only renders the first one when `cached` is set to true. But it should render all
    5 items instead.

    Fixes #35114.

    *Stan Lo*

*   Only clear ActionView cache in development on file changes

    To speed up development mode, view caches are only cleared when files in
    the view paths have changed. Applications which have implemented custom
    `ActionView::Resolver` subclasses may need to add their own cache clearing.

    *John Hawthorn*

*   Fix `ActionView::FixtureResolver` so that it handles template variants correctly.

    *Edward Rudd*


## Rails 6.0.0.beta3 (March 11, 2019) ##

*   Only accept formats from registered mime types

    A lack of filtering on mime types could allow an attacker to read
    arbitrary files on the target server or to perform a denial of service
    attack.

    Fixes CVE-2019-5418
    Fixes CVE-2019-5419

    *John Hawthorn*, *Eileen M. Uchitelle*, *Aaron Patterson*


## Rails 6.0.0.beta2 (February 25, 2019) ##

*   `ActionView::Template.finalize_compiled_template_methods` is deprecated with
    no replacement.

    *tenderlove*

*   `config.action_view.finalize_compiled_template_methods` is deprecated with
    no replacement.

    *tenderlove*

*   Ensure unique DOM IDs for collection inputs with float values.

    Fixes #34974.

    *Mark Edmondson*


## Rails 6.0.0.beta1 (January 18, 2019) ##

*   [Rename npm package](https://github.com/rails/rails/pull/34905) from
    [`rails-ujs`](https://www.npmjs.com/package/rails-ujs) to
    [`@rails/ujs`](https://www.npmjs.com/package/@rails/ujs).

    *Javan Makhmali*

*   Remove deprecated `image_alt` helper.

    *Rafael Mendonça França*

*   Fix the need of `#protect_against_forgery?` method defined in
    `ActionView::Base` subclasses. This prevents the use of forms and buttons.

    *Genadi Samokovarov*

*   Fix UJS permanently showing disabled text in a[data-remote][data-disable-with] elements within forms.

    Fixes #33889.

    *Wolfgang Hobmaier*

*   Prevent non-primary mouse keys from triggering Rails UJS click handlers.
    Firefox fires click events even if the click was triggered by non-primary mouse keys such as right- or scroll-wheel-clicks.
    For example, right-clicking a link such as the one described below (with an underlying ajax request registered on click) should not cause that request to occur.

    ```
    <%= link_to 'Remote', remote_path, class: 'remote', remote: true, data: { type: :json } %>
    ```

    Fixes #34541.

    *Wolfgang Hobmaier*

*   Prevent `ActionView::TextHelper#word_wrap` from unexpectedly stripping white space from the _left_ side of lines.

    For example, given input like this:

    ```
        This is a paragraph with an initial indent,
    followed by additional lines that are not indented,
    and finally terminated with a blockquote:
      "A pithy saying"
    ```

    Calling `word_wrap` should not trim the indents on the first and last lines.

    Fixes #34487.

    *Lyle Mullican*

*   Add allocations to template rendering instrumentation.

    Adds the allocations for template and partial rendering to the server output on render.

    ```
      Rendered posts/_form.html.erb (Duration: 7.1ms | Allocations: 6004)
      Rendered posts/new.html.erb within layouts/application (Duration: 8.3ms | Allocations: 6654)
    Completed 200 OK in 858ms (Views: 848.4ms | ActiveRecord: 0.4ms | Allocations: 1539564)
    ```

    *Eileen M. Uchitelle*, *Aaron Patterson*

*   Respect the `only_path` option passed to `url_for` when the options are passed in as an array

    Fixes #33237.

    *Joel Ambass*

*   Deprecate calling private model methods from view helpers.

    For example, in methods like `options_from_collection_for_select`
    and `collection_select` it is possible to call private methods from
    the objects used.

    Fixes #33546.

    *Ana María Martínez Gómez*

*   Fix issue with `button_to`'s `to_form_params`

    `button_to` was throwing exception when invoked with `params` hash that
    contains symbol and string keys. The reason for the exception was that
    `to_form_params` was comparing the given symbol and string keys.

    The issue is fixed by turning all keys to strings inside
    `to_form_params` before comparing them.

    *Georgi Georgiev*

*   Mark arrays of translations as trusted safe by using the `_html` suffix.

    Example:

        en:
          foo_html:
            - "One"
            - "<strong>Two</strong>"
            - "Three &#128075; &#128578;"

    *Juan Broullon*

*   Add `year_format` option to date_select tag. This option makes it possible to customize year
    names. Lambda should be passed to use this option.

    Example:

        date_select('user_birthday', '', start_year: 1998, end_year: 2000, year_format: ->year { "Heisei #{year - 1988}" })

    The HTML produced:

        <select id="user_birthday__1i" name="user_birthday[(1i)]">
        <option value="1998">Heisei 10</option>
        <option value="1999">Heisei 11</option>
        <option value="2000">Heisei 12</option>
        </select>
        /* The rest is omitted */

    *Koki Ryu*

*   Fix JavaScript views rendering does not work with Firefox when using
    Content Security Policy.

    Fixes #32577.

    *Yuji Yaginuma*

*   Add the `nonce: true` option for `javascript_include_tag` helper to
    support automatic nonce generation for Content Security Policy.
    Works the same way as `javascript_tag nonce: true` does.

    *Yaroslav Markin*

*   Remove `ActionView::Helpers::RecordTagHelper`.

    *Yoshiyuki Hirano*

*   Disable `ActionView::Template` finalizers in test environment.

    Template finalization can be expensive in large view test suites.
    Add a configuration option,
    `action_view.finalize_compiled_template_methods`, and turn it off in
    the test environment.

    *Simon Coffey*

*   Extract the `confirm` call in its own, overridable method in `rails_ujs`.

    Example:

        Rails.confirm = function(message, element) {
          return (my_bootstrap_modal_confirm(message));
        }

    *Mathieu Mahé*

*   Enable select tag helper to mark `prompt` option as `selected` and/or `disabled` for `required`
    field.

    Example:

        select :post,
               :category,
               ["lifestyle", "programming", "spiritual"],
               { selected: "", disabled: "", prompt: "Choose one" },
               { required: true }

    Placeholder option would be selected and disabled.

    The HTML produced:

        <select required="required" name="post[category]" id="post_category">
        <option disabled="disabled" selected="selected" value="">Choose one</option>
        <option value="lifestyle">lifestyle</option>
        <option value="programming">programming</option>
        <option value="spiritual">spiritual</option></select>

    *Sergey Prikhodko*

*   Don't enforce UTF-8 by default.

    With the disabling of TLS 1.0 by most major websites, continuing to run
    IE8 or lower becomes increasingly difficult so default to not enforcing
    UTF-8 encoding as it's not relevant to other browsers.

    *Andrew White*

*   Change translation key of `submit_tag` from `module_name_class_name` to `module_name/class_name`.

    *Rui Onodera*

*   Rails 6 requires Ruby 2.5.0 or newer.

    *Jeremy Daer*, *Kasper Timm Hansen*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/actionview/CHANGELOG.md) for previous changes.
