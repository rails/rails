## Rails 7.1.5.2 (August 13, 2025) ##

*   No changes.


## Rails 7.1.5.1 (December 10, 2024) ##

*   Update vendored trix version to 2.1.10

    *John Hawthorn*


## Rails 7.1.5 (October 30, 2024) ##

*   No changes.


## Rails 7.1.4.2 (October 23, 2024) ##

*   No changes.


## Rails 7.1.4.1 (October 15, 2024) ##

*   Avoid backtracing in plain_text_for_blockquote_node

    [CVE-2024-47888]

    *John Hawthorn*

## Rails 7.1.4 (August 22, 2024) ##

*   Strip `content` attribute if the key is present but the value is empty

    *Jeremy Green*

*   Only sanitize `content` attribute when present in attachments.

    *Petrik de Heus*


## Rails 7.1.3.4 (June 04, 2024) ##

*   Sanitize ActionText HTML ContentAttachment in Trix edit view
    [CVE-2024-32464]

    *Aaron Patterson*

## Rails 7.1.3.3 (May 16, 2024) ##

*   Upgrade Trix to 2.1.1 to fix [CVE-2024-34341](https://github.com/basecamp/trix/security/advisories/GHSA-qjqp-xr96-cj99).

    *Rafael Mendonça França*


## Rails 7.1.3.2 (February 21, 2024) ##

*   No changes.


## Rails 7.1.3.1 (February 21, 2024) ##

*   No changes.


## Rails 7.1.3 (January 16, 2024) ##

*   No changes.


## Rails 7.1.2 (November 10, 2023) ##

*   Compile ESM package that can be used directly in the browser as `actiontext.esm.js`.

    *Matias Grunberg*

*   Fix using actiontext.js with Sprockets.

    *Matias Grunberg*

*   Upgrade Trix to 2.0.7.

    *Hartley McGuire*

*   Fix using Trix with Sprockets.

    *Hartley McGuire*


## Rails 7.1.1 (October 11, 2023) ##

*   No changes.


## Rails 7.1.0 (October 05, 2023) ##

*   No changes.


## Rails 7.1.0.rc2 (October 01, 2023) ##

*   No changes.


## Rails 7.1.0.rc1 (September 27, 2023) ##

*   No changes.


## Rails 7.1.0.beta1 (September 13, 2023) ##

*   Use `Rails::HTML5::SafeListSanitizer` by default in the Rails 7.1 configuration if it is
    supported.

    Action Text's sanitizer can be configured by setting
    `config.action_text.sanitizer_vendor`. Supported values are `Rails::HTML4::Sanitizer` or
    `Rails::HTML5::Sanitizer`.

    The Rails 7.1 configuration will set this to `Rails::HTML5::Sanitizer` when it is supported, and
    fall back to `Rails::HTML4::Sanitizer`. Previous configurations default to
    `Rails::HTML4::Sanitizer`.

    As a result of this change, the defaults for `ActionText::ContentHelper.allowed_tags` and
    `.allowed_attributes` are applied at runtime, so the value of these attributes is now 'nil'
    unless set by the application. You may call `sanitizer_allowed_tags` or
    `sanitizer_allowed_attributes` to inspect the tags and attributes being allowed by the
    sanitizer.

    *Mike Dalessio*

*   Attachables now can override default attachment missing template.

    When rendering Action Text attachments where the underlying attachable model has
    been removed, a fallback template is used. You now can override this template on
    a per-model basis. For example, you could render a placeholder image for a file
    attachment or the text "Deleted User" for a User attachment.

    *Matt Swanson*, *Joel Drapper*

*   Update bundled Trix version from `1.3.1` to `2.0.4`.

    *Sarah Ridge*, *Sean Doyle*

*   Apply `field_error_proc` to `rich_text_area` form fields.

    *Kaíque Kandy Koga*

*   Action Text attachment URLs rendered in a background job (a la Turbo
    Streams) now use `Rails.application.default_url_options` and
    `Rails.application.config.force_ssl` instead of `http://example.org`.

    *Jonathan Hefner*

*   Support `strict_loading:` option for `has_rich_text` declaration

    *Sean Doyle*

*   Update ContentAttachment so that it can encapsulate arbitrary HTML content in a document.

    *Jamis Buck*

*   Fix an issue that caused the content layout to render multiple times when a
    rich_text field was updated.

    *Jacob Herrington*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/actiontext/CHANGELOG.md) for previous changes.
