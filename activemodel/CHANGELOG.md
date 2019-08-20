*   Add *_previously_was attribute methods when dirty tracking. Example:

        pirate.update(catchphrase: "Ahoy!")
        pirate.previous_changes["catchphrase"] # => ["Thar She Blows!", "Ahoy!"]
        pirate.catchphrase_previously_was # => "Thar She Blows!"

    *DHH*

Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/activemodel/CHANGELOG.md) for previous changes.
