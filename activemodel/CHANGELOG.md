*   Allow `:if` and `:unless` inside the `:include` hash passed to
    `ActiveModel::Serialization#serializable_hash`, so associations can
    be added conditionally (method, proc, or boolean).

    ```ruby
    # Example – include notes only for admins
    user.serializable_hash(include: { notes: { if: :admin? } })
    ```

    *Zakaria Fatahi*

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
