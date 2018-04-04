*   Disable `ActionView::Template` finalizers in test environment

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
