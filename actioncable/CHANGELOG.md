*   The Action Cable client now ensures successful channel subscriptions:

    * The client maintains a set of pending subscriptions until either
    the server confirms the subscription or the channel is torn down.
    * Rectifies the race condition where an unsubscribe is rapidly followed
    by a subscribe (on the same channel identifier) and the requests are
    handled out of order by the ActionCable server, thereby ignoring the
    subscribe command.

    *Daniel Spinosa*

*   The Action Cable client now includes safeguards to prevent a "thundering
    herd" of client reconnects after server connectivity loss:

    * The client will wait a random amount between 1x and 3x of the stale
      threshold after the server's last ping before making the first
      reconnection attempt.
    * Subsequent reconnection attempts now use exponential backoff instead of
      logarithmic backoff.  To allow the delay between reconnection attempts to
      increase slowly at first, the default exponentiation base is < 2.
    * Random jitter is applied to each delay between reconnection attempts.

    *Jonathan Hefner*

Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/actioncable/CHANGELOG.md) for previous changes.
