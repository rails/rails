*   The JavaScript WebSocket client will no longer try to reconnect
    when you call `reject_unauthorized_connection` on the connection.

    *Mick Staugaard*

*   `ActionCable.Connection#getState` now references the configurable
    `ActionCable.adapters.WebSocket` property rather than the `WebSocket` global
    variable, matching the behavior of `ActionCable.Connection#open`.

    *Richard Macklin*

*   The ActionCable javascript package has been converted from CoffeeScript
    to ES2015, and we now publish the source code in the npm distribution.

    This allows ActionCable users to depend on the javascript source code
    rather than the compiled code, which can produce smaller javascript bundles.

    This change includes some breaking changes to optional parts of the
    ActionCable javascript API:

    - Configuration of the WebSocket adapter and logger adapter have been moved
      from properties of `ActionCable` to properties of `ActionCable.adapters`.
      If you are currently configuring these adapters you will need to make
      these changes when upgrading:

      ```diff
      -    ActionCable.WebSocket = MyWebSocket
      +    ActionCable.adapters.WebSocket = MyWebSocket
      ```
      ```diff
      -    ActionCable.logger = myLogger
      +    ActionCable.adapters.logger = myLogger
      ```

    - The `ActionCable.startDebugging()` and `ActionCable.stopDebugging()`
      methods have been removed and replaced with the property
      `ActionCable.logger.enabled`. If you are currently using these methods you
      will need to make these changes when upgrading:

      ```diff
      -    ActionCable.startDebugging()
      +    ActionCable.logger.enabled = true
      ```
      ```diff
      -    ActionCable.stopDebugging()
      +    ActionCable.logger.enabled = false
      ```

    *Richard Macklin*

*   Add `id` option to redis adapter so now you can distinguish
    ActionCable's redis connections among others. Also, you can set
    custom id in options.

    Before:
    ```
    $ redis-cli client list
    id=669 addr=127.0.0.1:46442 fd=8 name= age=18 ...
    ```

    After:
    ```
    $ redis-cli client list
    id=673 addr=127.0.0.1:46516 fd=8 name=ActionCable-PID-19413 age=2 ...
    ```

    *Ilia Kasianenko*

*   Rails 6 requires Ruby 2.5.0 or newer.

    *Jeremy Daer*, *Kasper Timm Hansen*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/actioncable/CHANGELOG.md) for previous changes.
