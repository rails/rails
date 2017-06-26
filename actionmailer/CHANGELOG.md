## Rails 5.1.2 (June 26, 2017) ##

*   No changes.


## Rails 5.1.1 (May 12, 2017) ##

*   No changes.


## Rails 5.1.0 (April 27, 2017) ##

*   Add `:args` to `process.action_mailer` event.

    *Yuji Yaginuma*

*   Add parameterized invocation of mailers as a way to share before filters and defaults between actions.
    See `ActionMailer::Parameterized` for a full example of the benefit.

    *DHH*

*   Allow lambdas to be used as lazy defaults in addition to procs.

    *DHH*

*   Mime type: allow to custom content type when setting body in headers
    and attachments.

    Example:

        def test_emails
          attachments["invoice.pdf"] = "This is test File content"
          mail(body: "Hello there", content_type: "text/html")
        end

    *Minh Quy*

*   Exception handling: use `rescue_from` to handle exceptions raised by
    mailer actions, by message delivery, and by deferred delivery jobs.

    *Jeremy Daer*

Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/actionmailer/CHANGELOG.md) for previous changes.
