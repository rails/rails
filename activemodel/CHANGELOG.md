*   Fix `normalizes` re-applying normalizations on every validation of an
    unpersisted record, and speed up validation of normalized attributes.

    The in-place mutation check re-ran the normalizer on every `valid?` of an
    unpersisted record: wasteful for idempotent normalizers and compounded the
    result for non-idempotent ones. Normalizations are now re-applied only on a
    genuine in-place mutation.

    *Yaroslav Markin*

*   Limit the size of strings `ActiveModel::Type::Integer` will coerce with `to_i`.

    Calling `to_i` on very long strings can take a long time and could be used as
    a DoS vector. Integer casting now only considers the first `_limit * 4` bytes
    of a string (16 bytes for a default 4-byte integer, 32 bytes for an 8-byte
    bigint), which is enough to hold the maximum representable value plus a sign
    or a short slug suffix.

    *Aaron Patterson*, *Jean Boussier*


## Rails 8.1.3 (March 24, 2026) ##

*   Fix Ruby 4.0 delegator warning when calling inspect on attributes.

    *Hammad Khan*

*   Fix `NoMethodError` when deserialising `Type::Integer` objects marshalled under Rails 8.0.

    The performance optimisation that replaced `@range` with `@max`/`@min`
    broke Marshal compatibility. Objects serialised under 8.0 (with `@range`)
    and deserialised under 8.1 (expecting `@max`/`@min`) would crash with
    `undefined method '<=' for nil` because `Marshal.load` restores instance
    variables without calling `initialize`.

    *Edward Woodcock*


## Rails 8.1.2.1 (March 23, 2026) ##

*   No changes.


## Rails 8.1.2 (January 08, 2026) ##

*   No changes.


## Rails 8.1.1 (October 28, 2025) ##

*   No changes.


## Rails 8.1.0 (October 22, 2025) ##

*   Add `reset_token: { expires_in: ... }` option to `has_secure_password`.

    Allows configuring the expiry duration of password reset tokens (default remains 15 minutes for backwards compatibility).

    ```ruby
    has_secure_password reset_token: { expires_in: 1.hour }
    ```

    *Jevin Sew*, *Abeid Ahmed*

*   Add `except_on:` option for validation callbacks.

    *Ben Sheldon*

*   Backport `ActiveRecord::Normalization` to `ActiveModel::Attributes::Normalization`

    ```ruby
    class User
      include ActiveModel::Attributes
      include ActiveModel::Attributes::Normalization

      attribute :email, :string

      normalizes :email, with: -> email { email.strip.downcase }
    end

    user = User.new
    user.email =    " CRUISE-CONTROL@EXAMPLE.COM\n"
    user.email # => "cruise-control@example.com"
    ```

    *Sean Doyle*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activemodel/CHANGELOG.md) for previous changes.
