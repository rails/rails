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
