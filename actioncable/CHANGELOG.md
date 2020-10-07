## Rails 6.0.3.4 (October 07, 2020) ##

*   No changes.


## Rails 6.0.3.3 (September 09, 2020) ##

*   No changes.


## Rails 6.0.3.2 (June 17, 2020) ##

*   No changes.


## Rails 6.0.3.1 (May 18, 2020) ##

*   No changes.


## Rails 6.0.3 (May 06, 2020) ##

*   No changes.


## Rails 6.0.2.2 (March 19, 2020) ##

*   No changes.


## Rails 6.0.2.1 (December 18, 2019) ##

*   No changes.


## Rails 6.0.2 (December 13, 2019) ##

*   No changes.


## Rails 6.0.1 (November 5, 2019) ##

*   No changes.


## Rails 6.0.0 (August 16, 2019) ##

*   No changes.


## Rails 6.0.0.rc2 (July 22, 2019) ##

*   No changes.


## Rails 6.0.0.rc1 (April 24, 2019) ##

*   No changes.


## Rails 6.0.0.beta3 (March 11, 2019) ##

*   No changes.


## Rails 6.0.0.beta2 (February 25, 2019) ##

*   PostgreSQL subscription adapters now support `channel_prefix` option in cable.yml

    Avoids channel name collisions when multiple apps use the same database for Action Cable.

    *Vladimir Dementyev*

*   Allow passing custom configuration to `ActionCable::Server::Base`.

    You can now create a standalone Action Cable server with a custom configuration
    (e.g. to run it in isolation from the default one):

    ```ruby
    config = ActionCable::Server::Configuration.new
    config.cable = { adapter: "redis", channel_prefix: "custom_" }

    CUSTOM_CABLE = ActionCable::Server::Base.new(config: config)
    ```

    Then you can mount it in the `routes.rb` file:

    ```ruby
    Rails.application.routes.draw do
      mount CUSTOM_CABLE => "/custom_cable"
      # ...
    end
    ```

    *Vladimir Dementyev*

*   Add `:action_cable_connection` and `:action_cable_channel` load hooks.

    You can use them to extend `ActionCable::Connection::Base` and `ActionCable::Channel::Base`
    functionality:

    ```ruby
    ActiveSupport.on_load(:action_cable_channel) do
      # do something in the context of ActionCable::Channel::Base
    end
    ```

    *Vladimir Dementyev*

*   Add `Channel::Base#broadcast_to`.

    You can now call `broadcast_to` within a channel action, which equals to
    the `self.class.broadcast_to`.

    *Vladimir Dementyev*

*   Make `Channel::Base.broadcasting_for` a public API.

    You can use `.broadcasting_for` to generate a unique stream identifier within
    a channel for the specified target (e.g. Active Record model):

    ```ruby
    ChatChannel.broadcasting_for(model) # => "chat:<model.to_gid_param>"
    ```

    *Vladimir Dementyev*


## Rails 6.0.0.beta1 (January 18, 2019) ##

*   [Rename npm package](https://github.com/rails/rails/pull/34905) from
    [`actioncable`](https://www.npmjs.com/package/actioncable) to
    [`@rails/actioncable`](https://www.npmjs.com/package/@rails/actioncable).

    *Javan Makhmali*

*   Merge [`action-cable-testing`](https://github.com/palkan/action-cable-testing) to Rails.

    *Vladimir Dementyev*

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
