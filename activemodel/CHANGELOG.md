*   Calls to `human_attribute_name` on an `ActiveModel` now pass attributes as strings instead of symbols in some cases.
    
    This is in line with examples in Rails docs and puts the code in line with the intention -
    the potential use of strings or symbols.
    It is recommended to cast the attribute input to your desired type as it may be a string or symbol

*   Add *_previously_was attribute methods when dirty tracking. Example:

        pirate.update(catchphrase: "Ahoy!")
        pirate.previous_changes["catchphrase"] # => ["Thar She Blows!", "Ahoy!"]
        pirate.catchphrase_previously_was # => "Thar She Blows!"

    *DHH*

Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/activemodel/CHANGELOG.md) for previous changes.
