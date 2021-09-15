## Rails 7.0.0.alpha2 (September 15, 2021) ##

*   No changes.


## Rails 7.0.0.alpha1 (September 15, 2021) ##

*   Make the Action Text + Trix JavaScript and CSS available through the asset pipeline.

    *DHH*

*   OpenSSL constants are now used for Digest computations.

    *Dirkjan Bussink*

*   Add support for passing `form:` option to `rich_text_area_tag` and
    `rich_text_area` helpers to specify the `<input type="hidden" form="...">`
    value.

    *Sean Doyle*

*   Add `config.action_text.attachment_tag_name`, to specify the HTML tag that contains attachments.

    *Mark VanLandingham*

*   Expose how we render the HTML _surrounding_ rich text content as an
    extensible `layouts/action_view/contents/_content.html.erb` template to
    encourage user-land customizations, while retaining private API control over how
    the rich text itself is rendered by `action_text/contents/_content.html.erb`
    partial.

    *Sean Doyle*

*   Add `with_all_rich_text` method to eager load all rich text associations on a model at once.

    *Matt Swanson*, *DHH*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/actiontext/CHANGELOG.md) for previous changes.
