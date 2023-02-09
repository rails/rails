*   Raise `NoMethodError` in `ActiveModel::Type::Value#as_json` to avoid unpredictable
    results.

    *Vasiliy Ermolovich*

*   Custom attribute types that inherit from Active Model built-in types and do
    not override the `serialize` method will now benefit from an optimization
    when serializing attribute values for the database.

    For example, with a custom type like the following:

    ```ruby
    class DowncasedString < ActiveModel::Type::String
      def cast(value)
        super&.downcase
      end
    end

    ActiveRecord::Type.register(:downcased_string, DowncasedString)

    class User < ActiveRecord::Base
      attribute :email, :downcased_string
    end

    user = User.new(email: "FooBar@example.com")
    ```

    Serializing the `email` attribute for the database will be roughly twice as
    fast.  More expensive `cast` operations will likely see greater improvements.

    *Jonathan Hefner*

*   `has_secure_password` now supports password challenges via a
    `password_challenge` accessor and validation.

    A password challenge is a safeguard to verify that the current user is
    actually the password owner.  It can be used when changing sensitive model
    fields, such as the password itself.  It is different than a password
    confirmation, which is used to prevent password typos.

    When `password_challenge` is set, the validation checks that the value's
    digest matches the *currently persisted* `password_digest` (i.e.
    `password_digest_was`).

    This allows a password challenge to be done as part of a typical `update`
    call, just like a password confirmation.  It also allows a password
    challenge error to be handled in the same way as other validation errors.

    For example, in the controller, instead of:

    ```ruby
    password_params = params.require(:password).permit(
      :password_challenge,
      :password,
      :password_confirmation,
    )

    password_challenge = password_params.delete(:password_challenge)
    @password_challenge_failed = !current_user.authenticate(password_challenge)

    if !@password_challenge_failed && current_user.update(password_params)
      # ...
    end
    ```

    You can now write:

    ```ruby
    password_params = params.require(:password).permit(
      :password_challenge,
      :password,
      :password_confirmation,
    ).with_defaults(password_challenge: "")

    if current_user.update(password_params)
      # ...
    end
    ```

    And, in the view, instead of checking `@password_challenge_failed`, you can
    render an error for the `password_challenge` field just as you would for
    other form fields, including utilizing `config.action_view.field_error_proc`.

    *Jonathan Hefner*

*   Support infinite ranges for `LengthValidator`s `:in`/`:within` options

    ```ruby
    validates_length_of :first_name, in: ..30
    ```

    *fatkodima*

*   Add support for beginless ranges to inclusivity/exclusivity validators:

    ```ruby
    validates_inclusion_of :birth_date, in: -> { (..Date.today) }
    ```

    *Bo Jeanes*

*   Make validators accept lambdas without record argument

    ```ruby
    # Before
    validates_comparison_of :birth_date, less_than_or_equal_to: ->(_record) { Date.today }

    # After
    validates_comparison_of :birth_date, less_than_or_equal_to: -> { Date.today }
    ```

    *fatkodima*

*   Fix casting long strings to `Date`, `Time` or `DateTime`

    *fatkodima*

*   Use different cache namespace for proxy calls

    Models can currently have different attribute bodies for the same method
    names, leading to conflicts. Adding a new namespace `:active_model_proxy`
    fixes the issue.

    *Chris Salzberg*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/activemodel/CHANGELOG.md) for previous changes.
