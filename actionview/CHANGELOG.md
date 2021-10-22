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

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/actionview/CHANGELOG.md) for previous changes.
