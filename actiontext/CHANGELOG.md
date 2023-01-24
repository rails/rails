## Rails 7.0.4.2 (January 24, 2023) ##

*   No changes.


## Rails 7.0.4.1 (January 17, 2023) ##

*   No changes.


## Rails 7.0.4 (September 09, 2022) ##

*   No changes.


## Rails 7.0.3.1 (July 12, 2022) ##

*   No changes.


## Rails 7.0.3 (May 09, 2022) ##

*   No changes.


## Rails 7.0.2.4 (April 26, 2022) ##

*   No changes.


## Rails 7.0.2.3 (March 08, 2022) ##

*   No changes.


## Rails 7.0.2.2 (February 11, 2022) ##

*   No changes.


## Rails 7.0.2.1 (February 11, 2022) ##

*   No changes.


## Rails 7.0.2 (February 08, 2022) ##

*   No changes.


## Rails 7.0.1 (January 06, 2022) ##

*   No changes.


## Rails 7.0.0 (December 15, 2021) ##

*   No changes.


## Rails 7.0.0.rc3 (December 14, 2021) ##

*   No changes.


## Rails 7.0.0.rc2 (December 14, 2021) ##

*   No changes.

## Rails 7.0.0.rc1 (December 06, 2021) ##

*   Fix an issue with how nested lists were displayed when converting to plain text

    *Matt Swanson*

*   Allow passing in a custom `direct_upload_url` or `blob_url_template` to `rich_text_area_tag`.

    *Lucas Mansur*


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
