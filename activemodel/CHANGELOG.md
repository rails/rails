*   Add `has_json` and `has_delegated_json` to provide schema-enforced access to JSON attributes.

    ```ruby
    class Account < ApplicationRecord
      has_json :settings, restrict_creation_to_admins: true, max_invites: 10, greeting: "Hello!"
      has_delegated_json :flags, beta: false, staff: :boolean
    end

    a = Account.new
    a.settings.restrict_creation_to_admins? # => true
    a.settings.max_invites = "100" # => Set to integer 100
    a.settings = { "restrict_creation_to_admins" => "false", "max_invites" => "500", "greeting" => "goodbye" }
    a.settings.greeting # => "goodbye"
    a.staff # => nil
    a.staff = true
    a.staff? # => true
    ```

    *DHH*

*   Changes `ActiveModel::Validations#read_attribute_for_validation` to return `nil` if the record doesn't
    respond to the attribute instead of raising an error.

    This change allows adding errors to custom attributes with symbol messages.

    ```ruby
    user = User.new # User model has no `address` attribute

    user.errors.add(:address, :invalid)

    user.errors.messages
    ```

    Previously, calling `messages` would raise an error because `address` attribute can't be read.
    Now it returns the localized error message.

    *Lovro Bikić*

*   Add built-in Argon2 support for `has_secure_password`.

    `has_secure_password` now supports Argon2 as a built-in algorithm:

    ```ruby
    class User < ActiveRecord::Base
      has_secure_password algorithm: :argon2
    end
    ```

    To use Argon2, add `gem "argon2", "~> 2.3"` to your Gemfile.

    Argon2 has no password length limit, unlike BCrypt's 72-byte restriction.

    *Justin Bull*, *Guillermo Iguaran*

*   Add ActiveModel::SecurePassword.register_algorithm to register new algorithms for `has_secure_password` by symbol:

    `ActiveModel::SecurePassword.register_algorithm` can be used to register new algorithms:

    ```ruby
    ActiveModel::SecurePassword.register_algorithm :custom_password, CustomPassword
    ```

    ```ruby
    class User < ActiveRecord::Base
      has_secure_password algorithm: :custom_password
    end
    ```

    BCrypt is pre-registered as `:bcrypt` in the algorithms registry.

    *Justin Bull*, *Guillermo Iguaran*

*   `has_secure_password` can support different password hashing algorithms (if defined) using the `:algorithm` option:

    ```ruby
    class CustomPassword
      def hash_password(unencrypted_password)
        CustomHashingLibrary.create(unencrypted_password)
      end

      def verify_password(password, digest)
        CustomHashingLibrary.verify(password, digest)
      end

      def password_salt(digest)
        CustomHashingLibrary.salt(digest)
      end

      def validate(record, attribute)
        # ...
      end

      def algorithm_name
        :custom
      end
    end
    ```

    ```ruby
    class User < ActiveRecord::Base
      has_secure_password algorithm: CustomPassword.new
    end
    ```

    *Justin Bull*, *Lucas Mazza*

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

*   Add error type support arguments to `ActiveModel::Errors#messages_for` and `ActiveModel::Errors#full_messages_for`

    ```ruby
    person = Person.create()
    person.errors.full_messages_for(:name, :invalid)
    # => ["Name is invalid"]

    person.errors.messages_for(:name, :invalid)
    # => ["is invalid"]
    ```

    *Eugene Bezludny*

*   Make `ActiveModel::Serializers::JSON#from_json` compatible with `#assign_attributes`

    *Sean Doyle*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activemodel/CHANGELOG.md) for previous changes.
