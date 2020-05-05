*   Change `serialize` so it does not raise.

    `serialize` should be responsible for validation and serialization. We should check whether values are serializable before serializing them. Out-of-range integers will no longer raise a `RangeError` with this change. They will now return `nil` if the value is not serializable.

    *Aaron Patterson*, *Eileen M. Uchitelle*

*   Deprecate marshalling load from legacy attributes format.

    *Ryuta Kamizono*

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

*   Encapsulate each validation error as an Error object.

    The `ActiveModel`’s `errors` collection is now an array of these Error
    objects, instead of messages/details hash.

    For each of these `Error` object, its `message` and `full_message` methods
    are for generating error messages. Its `details` method would return error’s
    extra parameters, found in the original `details` hash.

    The change tries its best at maintaining backward compatibility, however
    some edge cases won’t be covered, like `errors#first` will return `ActiveModel::Error` and manipulating
    `errors.messages` and `errors.details` hashes directly will have no effect. Moving forward,
    please convert those direct manipulations to use provided API methods instead.

    The list of deprecated methods and their planned future behavioral changes at the next major release are:

    * `errors#slice!` will be removed.
    * `errors#each` with the `key, value` two-arguments block will stop working, while the `error` single-argument block would return `Error` object.
    * `errors#values` will be removed.
    * `errors#keys` will be removed.
    * `errors#to_xml` will be removed.
    * `errors#to_h` will be removed, and can be replaced with `errors#to_hash`.
    * Manipulating `errors` itself as a hash will have no effect (e.g. `errors[:foo] = 'bar'`).
    * Manipulating the hash returned by `errors#messages` (e.g. `errors.messages[:foo] = 'bar'`) will have no effect.
    * Manipulating the hash returned by `errors#details` (e.g. `errors.details[:foo].clear`) will have no effect.

    *lulalala*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/activemodel/CHANGELOG.md) for previous changes.
