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
