*   Allow each model to decide whether to raise an error on missing translations.

    `ActiveModel::Translation` now allows each model to decide whether to raise
    an error on missing translations by defining class method
    `raise_on_missing_translations`.

    ```ruby
    class ApplicationRecord < ActiveRecord::Base
      self.raise_on_missing_translations = true
    end

    class Post < ApplicationRecord
    end

    class User < ApplicationRecord
      self.raise_on_missing_translations = false
    end

    Post.human_attribute_name(:title)
    # => Translation missing. Options considered were: (I18n::MissingTranslationData)
    #     - en.activerecord.attributes.post.title
    #     - en.attributes.title
    #
    #             raise exception.respond_to?(:to_exception) ? exception.to_exception : exception
    #                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

    User.human_attribute_name(:name)
    # => "Name"
    ```

    *Shouichi Kamiya*

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
