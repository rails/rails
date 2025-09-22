## Rails 8.0.3 (September 22, 2025) ##

*   Fixed compatibility with `redis` gem `5.4.1`

    *Jean Boussier*

*   Fixed a possible race condition in `stream_from`.

    *OuYangJinTing*


## Rails 8.0.2.1 (August 13, 2025) ##

*   No changes.


## Rails 8.0.2 (March 12, 2025) ##

*   No changes.


## Rails 8.0.1 (December 13, 2024) ##

*   Ensure the Postgresql adapter always use a dedicated connection even during system tests.

    Fix an issue with the Action Cable Postgresql adapter causing deadlock or various weird
    pg client error during system tests.

    *Jean Boussier*


## Rails 8.0.0.1 (December 10, 2024) ##

*   No changes.


## Rails 8.0.0 (November 07, 2024) ##

*   No changes.


## Rails 8.0.0.rc2 (October 30, 2024) ##

*   No changes.


## Rails 8.0.0.rc1 (October 19, 2024) ##

*   No changes.


## Rails 8.0.0.beta1 (September 26, 2024) ##

*   Add an `identifier` to the event payload for the ActiveSupport::Notification `transmit_subscription_confirmation.action_cable` and `transmit_subscription_rejection.action_cable`.

    *Keith Schacht*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/actioncable/CHANGELOG.md) for previous changes.
