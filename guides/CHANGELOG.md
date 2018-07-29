*   Wrap ActionCable incoming messages with the application reloader if it's checking for changes.

    That allows handling code changes between the execution of Action Cable commands without triggering an HTTP request.

*   Rails 6 requires Ruby 2.4.1 or newer.

    *Jeremy Daer*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/guides/CHANGELOG.md) for previous changes.
