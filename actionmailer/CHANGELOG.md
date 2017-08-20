*   Add an `:only` option to `assert_enqueued_emails` and `assert_no_enqueued_emails`
    to filter delivery job.

    *Yuji Yaginuma*

*   Allow Action Mailer classes to configure their delivery job.

        class MyMailer < ApplicationMailer
          self.delivery_job = MyCustomDeliveryJob

          ...
        end

    *Matthew Mongeau*


Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/actionmailer/CHANGELOG.md) for previous changes.
