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
