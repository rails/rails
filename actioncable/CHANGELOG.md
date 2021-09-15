## Rails 7.0.0.alpha2 (September 15, 2021) ##

*   No changes.


## Rails 7.0.0.alpha1 (September 15, 2021) ##

*   Compile ESM package that can be used directly in the browser as actioncable.esm.js.

    *DHH*

*   Move action_cable.js to actioncable.js to match naming convention used for other Rails frameworks, and use JS console to communicate the deprecation.

    *DHH*

*   Stop transpiling the UMD package generated as actioncable.js and drop the IE11 testing that relied on that.

    *DHH*

*   Truncate broadcast logging messages.

    *J Smith*

*   OpenSSL constants are now used for Digest computations.

    *Dirkjan Bussink*

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
