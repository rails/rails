## Rails 8.0.1 (December 13, 2024) ##

*   No changes.


## Rails 8.0.0.1 (December 10, 2024) ##

*   No changes.


## Rails 8.0.0 (November 07, 2024) ##

*   No changes.


## Rails 8.0.0.rc2 (October 30, 2024) ##

*   No changes.


## Rails 8.0.0.rc1 (October 19, 2024) ##

*   Add `:except_on` option for validations. Grants the ability to _skip_ validations in specified contexts.

    ```ruby
    class User < ApplicationRecord
        #...
        validates :birthday, presence: { except_on: :admin }
        #...
    end

    user = User.new(attributes except birthday)
    user.save(context: :admin)
    ```

    *Drew Bragg*

## Rails 8.0.0.beta1 (September 26, 2024) ##

*   Make `ActiveModel::Serialization#read_attribute_for_serialization` public

    *Sean Doyle*

*   Add a default token generator for password reset tokens when using `has_secure_password`.

    ```ruby
    class User < ApplicationRecord
      has_secure_password
    end

    user = User.create!(name: "david", password: "123", password_confirmation: "123")
    token = user.password_reset_token
    User.find_by_password_reset_token(token) # returns user

    # 16 minutes later...
    User.find_by_password_reset_token(token) # returns nil

    # raises ActiveSupport::MessageVerifier::InvalidSignature since the token is expired
    User.find_by_password_reset_token!(token)
    ```

    *DHH*

*   Add a load hook `active_model_translation` for `ActiveModel::Translation`.

    *Shouichi Kamiya*

*   Add `raise_on_missing_translations` option to `ActiveModel::Translation`.
    When the option is set, `human_attribute_name` raises an error if a translation of the given attribute is missing.

    ```ruby
    # ActiveModel::Translation.raise_on_missing_translations = false
    Post.human_attribute_name("title")
    => "Title"

    # ActiveModel::Translation.raise_on_missing_translations = true
    Post.human_attribute_name("title")
    => Translation missing. Options considered were: (I18n::MissingTranslationData)
        - en.activerecord.attributes.post.title
        - en.attributes.title

                raise exception.respond_to?(:to_exception) ? exception.to_exception : exception
                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    ```

    *Shouichi Kamiya*

*   Introduce `ActiveModel::AttributeAssignment#attribute_writer_missing`

    Provide instances with an opportunity to gracefully handle assigning to an
    unknown attribute:

    ```ruby
    class Rectangle
      include ActiveModel::AttributeAssignment

      attr_accessor :length, :width

      def attribute_writer_missing(name, value)
        Rails.logger.warn "Tried to assign to unknown attribute #{name}"
      end
    end

    rectangle = Rectangle.new
    rectangle.assign_attributes(height: 10) # => Logs "Tried to assign to unknown attribute 'height'"
    ```

    *Sean Doyle*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activemodel/CHANGELOG.md) for previous changes.
