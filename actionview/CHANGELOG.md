*   `select` can now be called with a single hash containing options and some HTML options

    Previously this would not work as expected:

    ```erb
    <%= select :post, :author, authors, required: true %>
    ```

    Instead you needed to do this:

    ```erb
    <%= select :post, :author, authors, {}, required: true %>
    ```

    Now, either form is accepted, for the following HTML attributes: `required`, `multiple`, `size`.

    *Alex Ghiculescu*

*   Datetime form helpers (`time_field`, `date_field`, `datetime_field`, `week_field`, `month_field`) now accept an instance of Time/Date/DateTime as `:value` option.

    Before:
    ```erb
    <%= form.datetime_field :written_at, value: Time.current.strftime("%Y-%m-%dT%T") %>
    ```

    After:
    ```erb
    <%= form.datetime_field :written_at, value: Time.current %>
    ```

    *Andrey Samsonov*

*   Choices of `select` can optionally contain html attributes as the last element
    of the child arrays when using grouped/nested collections

    ```erb
    <%= form.select :foo, [["North America", [["United States","US"],["Canada","CA"]], { disabled: "disabled" }]] %>
    # => <select><optgroup label="North America" disabled="disabled"><option value="US">United States</option><option value="CA">Canada</option></optgroup></select>
    ```

    *Chris Gunther*

*   `check_box_tag` and `radio_button_tag` now accept `checked` as a keyword argument

    This is to make the API more consistent with the `FormHelper` variants. You can now
    provide `checked` as a positional or keyword argument:

    ```erb
    = check_box_tag "admin", "1", false
    = check_box_tag "admin", "1", checked: false

    = radio_button_tag 'favorite_color', 'maroon', false
    = radio_button_tag 'favorite_color', 'maroon', checked: false
    ```

    *Alex Ghiculescu*

*   Allow passing a class to `dom_id`.
    You no longer need to call `new` when passing a class to `dom_id`.
    This makes `dom_id` behave like `dom_class` in this regard.
    Apart from saving a few keystrokes, it prevents Ruby from needing
    to instantiate a whole new object just to generate a string.

    Before:
    ```ruby
    dom_id(Post) # => NoMethodError: undefined method `to_key' for Post:Class
    ```

    After:
    ```ruby
    dom_id(Post) # => "new_post"
    ```

    *Goulven Champenois*

*   Report `:locals` as part of the data returned by ActionView render instrumentation.

    Before:
    ```ruby
    {
    identifier: "/Users/adam/projects/notifications/app/views/posts/index.html.erb",
    layout: "layouts/application"
    }
    ```

    After:
    ```ruby
    {
    identifier: "/Users/adam/projects/notifications/app/views/posts/index.html.erb",
    layout: "layouts/application",
    locals: {foo: "bar"}
    }
    ```

    *Aaron Gough*

*   Strip `break_sequence` at the end of `word_wrap`.

    This fixes a bug where `word_wrap` didn't properly strip off break sequences that had printable characters.

    For example, compare the outputs of this template:

    ```erb
    # <%= word_wrap("11 22\n33 44", line_width: 2, break_sequence: "\n# ") %>
    ```

    Before:

    ```
    # 11
    # 22
    #
    # 33
    # 44
    #
    ```

    After:

    ```
    # 11
    # 22
    # 33
    # 44
    ```

    *Max Chernyak*

*   Allow templates to set strict `locals`.

    By default, templates will accept any `locals` as keyword arguments. To define what `locals` a template accepts, add a `locals` magic comment:

    ```erb
    <%# locals: (message:) -%>
    <%= message %>
    ```

    Default values can also be provided:

    ```erb
    <%# locals: (message: "Hello, world!") -%>
    <%= message %>
    ```

    Or `locals` can be disabled entirely:

    ```erb
    <%# locals: () %>
    ```

    *Joel Hawksley*

*   Add `include_seconds` option for `datetime_local_field`

    This allows to omit seconds part in the input field, by passing `include_seconds: false`

    *Wojciech Wnętrzak*

*   Guard against `ActionView::Helpers::FormTagHelper#field_name` calls with nil
    `object_name` arguments. For example:

    ```erb
    <%= fields do |f| %>
      <%= f.field_name :body %>
    <% end %>
    ```

    *Sean Doyle*

*   Strings returned from `strip_tags` are correctly tagged `html_safe?`

    Because these strings contain no HTML elements and the basic entities are escaped, they are safe
    to be included as-is as PCDATA in HTML content. Tagging them as html-safe avoids double-escaping
    entities when being concatenated to a SafeBuffer during rendering.

    Fixes [rails/rails-html-sanitizer#124](https://github.com/rails/rails-html-sanitizer/issues/124)

    *Mike Dalessio*

*   Move `convert_to_model` call from `form_for` into `form_with`

    Now that `form_for` is implemented in terms of `form_with`, remove the
    `convert_to_model` call from `form_for`.

    *Sean Doyle*

*   Fix and add protections for XSS in `ActionView::Helpers` and `ERB::Util`.

    Escape dangerous characters in names of tags and names of attributes in the
    tag helpers, following the XML specification. Rename the option
    `:escape_attributes` to `:escape`, to simplify by applying the option to the
    whole tag.

    *Álvaro Martín Fraguas*

*   Extend audio_tag and video_tag to accept Active Storage attachments.

    Now it's possible to write

    ```ruby
    audio_tag(user.audio_file)
    video_tag(user.video_file)
    ```

    Instead of

    ```ruby
    audio_tag(polymorphic_path(user.audio_file))
    video_tag(polymorphic_path(user.video_file))
    ```

    `image_tag` already supported that, so this follows the same pattern.

    *Matheus Richard*

*   Ensure models passed to `form_for` attempt to call `to_model`.

    *Sean Doyle*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/actionview/CHANGELOG.md) for previous changes.
