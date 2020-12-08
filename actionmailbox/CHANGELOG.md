*   Change default queue name of the incineration (`:action_mailbox_incineration`) and
    routing (`:action_mailbox_routing`) jobs to be the job adapter's default (`:default`).

    *Rafael Mendonça França*


## Rails 6.1.0.rc2 (December 01, 2020) ##

*   No changes.


## Rails 6.1.0.rc1 (November 02, 2020) ##

*   Sendgrid ingress now passes through the envelope recipient as `X-Original-To`.

    *Mark Haussmann*

*   Update Mandrill inbound email route to respond appropriately to HEAD requests for URL health checks from Mandrill.

    *Bill Cromie*

*   Add way to deliver emails via source instead of filling out a form through the conductor interface.

    *DHH*

*   Mailgun ingress now passes through the envelope recipient as `X-Original-To`.

    *Rikki Pitt*

*   Deprecate `Rails.application.credentials.action_mailbox.api_key` and `MAILGUN_INGRESS_API_KEY` in favor of `Rails.application.credentials.action_mailbox.signing_key` and `MAILGUN_INGRESS_SIGNING_KEY`.

    *Matthijs Vos*

*   Allow easier creation of multi-part emails from the `create_inbound_email_from_mail` and `receive_inbound_email_from_mail` test helpers.

    *Michael Herold*

*   Fix Bcc header not being included with emails from `create_inbound_email_from` test helpers.

    *jduff*

*   Add `ApplicationMailbox.mailbox_for` to expose mailbox routing.

    *James Dabbs*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/actionmailbox/CHANGELOG.md) for previous changes.
