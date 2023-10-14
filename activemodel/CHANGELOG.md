*   Introduce `ActiveModel::Base`

    Add an Active Record-like interface to classes that use `ActiveModel::Model`:

    ```ruby
    class Session < ActiveModel::Base
      attr_accessor :email, :password, :request

      validates :email, :password, presence: true

      def save!
        # ...
      end
    end

    session = Session.new(email: "", password: "secret", request: request)
    session.persisted? # => false
    session.save! # => raises ActiveModel::ValidationError
    session.update! email: "user@example.com" # => true
    session.persisted? # => true
    session.email = "user@example.com"
    User.find_signed(request.cookies[:signed_user_id]) == User.authenticate_by(email: "user@example.com", password: "secret") # => true
    ```

    *Sean Doyle*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activemodel/CHANGELOG.md) for previous changes.
