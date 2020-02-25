*   `*_previously_changed?` accepts `:from` and `:to` keyword arguments like `*_changed?`.

        topic.update!(status: :archived)
        topic.status_previously_changed?(from: "active", to: "archived")
        # => true

    *George Claghorn*

*   Raise FrozenError when trying to write attributes that aren't backed by the database on an object that is frozen:

        class Animal
          include ActiveModel::Attributes
          attribute :age
        end

        animal = Animal.new
        animal.freeze
        animal.age = 25 # => FrozenError, "can't modify a frozen Animal"

    *Josh Brody*

*   Add `*_previously_was` attribute methods when dirty tracking. Example:

        pirate.update(catchphrase: "Ahoy!")
        pirate.previous_changes["catchphrase"] # => ["Thar She Blows!", "Ahoy!"]
        pirate.catchphrase_previously_was # => "Thar She Blows!"

    *DHH*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/activemodel/CHANGELOG.md) for previous changes.
