*   Allow passing method name or proc to `allow_nil` and `allow_blank`

    ```ruby
    class EnrollmentForm
      include ActiveModel::Validations

      attr_accessor :course

      validates :course,
                inclusion: { in: :open_courses },
                allow_nil: :saving_progress?
    end
    ```

    *Richard Lynch*

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
