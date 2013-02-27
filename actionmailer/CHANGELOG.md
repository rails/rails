## unreleased ##

*   No changes.


## Rails 3.2.13 (Feb 17, 2013) ##

*   No changes.


## Rails 3.2.12 (Feb 11, 2013) ##

*   No changes.


## Rails 3.2.11 (Jan 8, 2013) ##

*   No changes.


## Rails 3.2.10 (Jan 2, 2013) ##

*   No changes.


## Rails 3.2.9 (Nov 12, 2012) ##

*   The return value from mailer methods is no longer relevant. This fixes a bug,
    which was introduced with 3.2.9.
    Backport #8450
    Fix #8448

        class ExampleMailer < ActionMailer::Base
          # in 3.2.9, returning a falsy value from a mailer action, prevented the email from beeing sent.
          # With 3.2.10 the return value is no longer relevant. If you call mail() the email will be sent.
          def nil_returning_mailer_action
            mail()
            nil
          end
        end

    *Yves Senn*


## Rails 3.2.9 (Nov 12, 2012) ##

*   Do not render views when mail() isn't called.
    Fix #7761

    *Yves Senn*


## Rails 3.2.8 (Aug 9, 2012) ##

*   No changes.


## Rails 3.2.7 (Jul 26, 2012) ##

*   No changes.


## Rails 3.2.6 (Jun 12, 2012) ##

*   No changes.


## Rails 3.2.5 (Jun 1, 2012) ##

*   No changes.


## Rails 3.2.4 (May 31, 2012) ##

*   No changes.


## Rails 3.2.3 (March 30, 2012) ##

*   Upgrade mail version to 2.4.3 *ML*


## Rails 3.2.2 (March 1, 2012) ##

*   No changes.


## Rails 3.2.1 (January 26, 2012) ##

*   No changes.


## Rails 3.2.0 (January 20, 2012) ##

*   Upgrade mail version to 2.4.0 *ML*

*   Remove Old ActionMailer API *Josh Kalderimis*

Please check [3-1-stable](https://github.com/rails/rails/blob/3-1-stable/actionmailer/CHANGELOG.md) for previous changes.
