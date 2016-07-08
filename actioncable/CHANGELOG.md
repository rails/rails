*  Protect against concurrent writes to a websocket connection from
   multiple threads; the underlying OS write is not always threadsafe.

   *Tinco Andringa*

*  Add ActiveSupport::Notifications hook to Broadcaster#broadcast

   *Matthew Wear*

*  Close hijacked socket when connection is shut down.

   Fixes #25613.

   *Tinco Andringa*


Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/actioncable/CHANGELOG.md) for previous changes.
