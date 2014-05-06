## Rails 4.1.1 (May 6, 2014) ##

*   No changes.


## Rails 4.1.0 (April 8, 2014) ##

*   Support the use of underscored symbols when registering interceptors and
    observers like we do elsewhere within Rails.

    *Andrew White*

*   Add the ability to intercept emails before previewing in a similar fashion
    to how emails can be intercepted before delivery.

    Fixes #13622.

    Example:

        class CSSInlineStyler
          def self.previewing_email(message)
            # inline CSS styles
          end
        end

        ActionMailer::Base.register_preview_interceptor CSSInlineStyler

    *Andrew White*

*   Add mailer previews feature based on 37 Signals mail_view gem.

    *Andrew White*

*   Calling `mail()` without arguments serves as getter for the current mail
    message and keeps previously set headers.

    Fixes #13090.

    Example:

        class MailerWithCallback < ActionMailer::Base
          after_action :a_callback

          def welcome
            mail subject: "subject", to: ["joe@example.com"]
          end

          def a_callback
            mail # => returns the current mail message
          end
        end

    *Yves Senn*

*   Instrument the generation of Action Mailer messages. The time it takes to
    generate a message is written to the log.

    *Daniel Schierbeck*

*   Invoke mailer defaults as procs only if they are procs, do not convert with
    `to_proc`. That an object is convertible to a proc does not mean it's meant
    to be always used as a proc.

    Fixes #11533.

    *Alex Tsukernik*

Please check [4-0-stable](https://github.com/rails/rails/blob/4-0-stable/actionmailer/CHANGELOG.md) for previous changes.
