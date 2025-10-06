*   Add `reset_token: { expires_in: ... }` option to `has_secure_password`.

    Allows configuring the expiry duration of password reset tokens (default remains 15 minutes for backwards compatibility).

    ```ruby
    has_secure_password reset_token: { expires_in: 1.hour }
    ```

    *Jevin Sew*, *Abeid Ahmed*

## Rails 8.1.0.beta1 (September 04, 2025) ##

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
