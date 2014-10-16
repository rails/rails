*   Attachments can be added while rendering the mail template.

    Fixes #16974.

    *Christian Felder*

*   Added `#deliver_later`, `#deliver_now` and deprecate `#deliver` in favour of
    `#deliver_now`. `#deliver_later` will enqueue a job to render and deliver
    the mail instead of delivering it right at that moment. The job is enqueued
    using the new Active Job framework in Rails, and will use whatever queue is
    configured for Rails.

    *DHH*, *Abdelkader Boudih*, *Cristian Bica*

*   Make `ActionMailer::Previews` methods class methods. Previously they were
    instance methods and `ActionMailer` tries to render a message when they
    are called.

    *Cristian Bica*

*   Deprecate `*_path` helpers in email views. When used they generate
    non-working links and are not the intention of most developers. Instead
    we recommend to use `*_url` helper.

    *Richard Schneeman*

*   Raise an exception when attachments are added after `mail` was called.
    This is a safeguard to prevent invalid emails.

    Fixes #16163.

    *Yves Senn*

*   Add `config.action_mailer.show_previews` configuration option.

    This config option can be used to enable the mail preview in environments
    other than development (such as staging).

    Defaults to `true` in development and false elsewhere.

    *Leonard Garvey*

*   Allow preview interceptors to be registered through
    `config.action_mailer.preview_interceptors`.

    See #15739.

    *Yves Senn*

Please check [4-1-stable](https://github.com/rails/rails/blob/4-1-stable/actionmailer/CHANGELOG.md) for previous changes.
