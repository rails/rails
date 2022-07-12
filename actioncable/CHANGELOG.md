## Rails 6.1.6.1 (July 12, 2022) ##

*   No changes.


## Rails 6.1.5.1 (April 26, 2022) ##

*   No changes.


## Rails 6.1.5 (March 09, 2022) ##

*   The Action Cable client now ensures successful channel subscriptions:

    * The client maintains a set of pending subscriptions until either
      the server confirms the subscription or the channel is torn down.
    * Rectifies the race condition where an unsubscribe is rapidly followed
      by a subscribe (on the same channel identifier) and the requests are
      handled out of order by the ActionCable server, thereby ignoring the
      subscribe command.

    *Daniel Spinosa*

*   Truncate broadcast logging messages.

    *J Smith*


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

*   Fix `ArgumentError` with ruby 3.0 on `RemoteConnection#disconnect`.

    *Vladislav*


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

*   `ActionCable::Connection::Base` now allows intercepting unhandled exceptions
    with `rescue_from` before they are logged, which is useful for error reporting
    tools and other integrations.

    *Justin Talbott*

*   Add `ActionCable::Channel#stream_or_reject_for` to stream if record is present, otherwise reject the connection

    *Atul Bhosale*

*   Add `ActionCable::Channel#stop_stream_from` and `#stop_stream_for` to unsubscribe from a specific stream.

    *Zhang Kang*

*   Add PostgreSQL subscription connection identificator.

    Now you can distinguish Action Cable PostgreSQL subscription connections among others.
    Also, you can set custom `id` in `cable.yml` configuration.

    ```sql
    SELECT application_name FROM pg_stat_activity;
    /*
        application_name
    ------------------------
    psql
    ActionCable-PID-42
    (2 rows)
    */
    ```

    *Sergey Ponomarev*

*   Subscription confirmations and rejections are now logged at the `DEBUG` level instead of `INFO`.

    *DHH*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/actioncable/CHANGELOG.md) for previous changes.
