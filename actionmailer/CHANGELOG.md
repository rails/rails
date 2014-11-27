*   `MailerGenerator` now generates layouts by default. The HTML mailer layout
    now includes `<html>` and `<body>` tags which improve the spam rating in
    some spam detection engines. Mailers now inherit from `ApplicationMailer`
    which sets the default layout.

    *Andy Jeffries*

*   `link_to` and `url_for` now generate URLs by default in templates.
    Passing `only_path: false` is no longer needed.

    Fixes #16497 and #16589.

    *Xavier Noria*, *Richard Schneeman*

*   Attachments can now be added while rendering the mail template.

    Fixes #16974.

    *Christian Felder*

*   Add `#deliver_later` and `#deliver_now` methods and deprecate `#deliver` in
    favor of `#deliver_now`. `#deliver_later` will enqueue a job to render and
    deliver the mail instead of delivering it immediately. The job is enqueued
    using the new Active Job framework in Rails and will use the queue that you
    have configured in Rails.

    *DHH*, *Abdelkader Boudih*, *Cristian Bica*

*   `ActionMailer::Previews` are now class methods instead of instance methods.

    *Cristian Bica*

*   Deprecate `*_path` helpers in email views. They generated broken links in
    email views and were not the intention of most developers. The `*_url`
    helper is recommended instead.

    *Richard Schneeman*

*   Raise an exception when attachments are added after `mail` is called.
    This is a safeguard to prevent invalid emails.

    Fixes #16163.

    *Yves Senn*

*   Add `config.action_mailer.show_previews` configuration option.

    This configuration option can be used to enable the mail preview in
    environments other than development (such as staging).

    Defaults to `true` in development and `false` elsewhere.

    *Leonard Garvey*

*   Allow preview interceptors to be registered through
    `config.action_mailer.preview_interceptors`.

    See #15739.

    *Yves Senn*

Please check [4-1-stable](https://github.com/rails/rails/blob/4-1-stable/actionmailer/CHANGELOG.md)
for previous changes.
