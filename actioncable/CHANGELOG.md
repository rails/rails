*   Improved error formatting for runtime errors when handling websocket
    requests.

    *Elias Fatsi*

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
