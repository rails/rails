*   Fix memory leak when ActionView::Resolver.caching? is false.

    *Max Melentiev*

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
    Example :
        Rails.confirm = function(message, element) {
          return (my_bootstrap_modal_confirm(message));
        }

    *Mathieu Mahé*

*   Enable select tag helper to mark `prompt` option as `selected` and/or `disabled` for `required`
    field. Example:

        select :post,
               :category,
               ["lifestyle", "programming", "spiritual"],
               { selected: "", disabled: "", prompt: "Choose one" },
               { required: true }

    Placeholder option would be selected and disabled. The HTML produced:

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

*   Rails 6 requires Ruby 2.4.1 or newer.

    *Jeremy Daer*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/actionview/CHANGELOG.md) for previous changes.
