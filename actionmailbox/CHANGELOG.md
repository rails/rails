## Rails 6.1.5 (March 09, 2022) ##

*   Add `attachments` to the list of permitted parameters for inbound emails conductor.

    When using the conductor to test inbound emails with attachments, this prevents an
    unpermitted parameter warning in default configurations, and prevents errors for
    applications that set:

    ```ruby
    config.action_controller.action_on_unpermitted_parameters = :raise
    ```

    *David Jones*, *Dana Henke*


## Rails 6.1.4.7 (March 08, 2022) ##

*   No changes.


## Rails 6.1.4.6 (February 11, 2022) ##

*   No changes.


## Rails 6.1.4.5 (February 11, 2022) ##

*   No changes.


## Rails 6.1.4.4 (December 15, 2021) ##

*   No changes.


## Rails 6.1.4.3 (December 14, 2021) ##

*   No changes.


## Rails 6.1.4.2 (December 14, 2021) ##

*   No changes.


## Rails 6.1.4.1 (August 19, 2021) ##

*   No changes.


## Rails 6.1.4 (June 24, 2021) ##

*   No changes.


## Rails 6.1.3.2 (May 05, 2021) ##

*   No changes.


## Rails 6.1.3.1 (March 26, 2021) ##

*   No changes.


## Rails 6.1.3 (February 17, 2021) ##

*   No changes.


## Rails 6.1.2.1 (February 10, 2021) ##

*   No changes.


## Rails 6.1.2 (February 09, 2021) ##

*   No changes.


## Rails 6.1.1 (January 07, 2021) ##

*   No changes.


## Rails 6.1.0 (December 09, 2020) ##

*   Change default queue name of the incineration (`:action_mailbox_incineration`) and
    routing (`:action_mailbox_routing`) jobs to be the job adapter's default (`:default`).

    *Rafael Mendonça França*

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
