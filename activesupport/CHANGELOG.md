*   Trigger `ActiveSupport::ActionableError` from existing errors.

    Triggers let's you re-raise an actionable error from an existing one, if it
    matches a certain condition. Here is how Action Mailbox uses triggers to
    raise an actionable error when the `action_mailbox_inbound_emails` table
    does not exist.

    ```ruby
    class InstallError < Error
      include ActiveSupport::ActionableError

      def initialize(message = nil)
        super(message || <<~MESSAGE)
          Action Mailbox does not appear to be installed. Do you want to
          install it now?
        MESSAGE
      end

      trigger on: ActiveRecord::StatementInvalid, if: -> error do
        error.message.match?(InboundEmail.table_name)
      end

      action "Install now" do
        Rails::Command.invoke("active_storage:install")
        Rails::Command.invoke("db:migrate")j
      end
    end
    ```

    *Genadi Samokovarov*

*   Allow the on_rotation proc used when decrypting/verifying a message to be
    be passed at the constructor level.

    Before:

	crypt = ActiveSupport::MessageEncryptor.new('long_secret')
	crypt.decrypt_and_verify(encrypted_message, on_rotation: proc { ... })
	crypt.decrypt_and_verify(another_encrypted_message, on_rotation: proc { ... })

    After:

	crypt = ActiveSupport::MessageEncryptor.new('long_secret', on_rotation: proc { ... })
	crypt.decrypt_and_verify(encrypted_message)
	crypt.decrypt_and_verify(another_encrypted_message)

    *Edouard Chin*

*   `delegate_missing_to` would raise a `DelegationError` if the object
    delegated to was `nil`. Now the `allow_nil` option has been added to enable
    the user to specify they want `nil` returned in this case.

    *Matthew Tanous*

*   `truncate` would return the original string if it was too short to be truncated
    and a frozen string if it were long enough to be truncated. Now truncate will
    consistently return an unfrozen string regardless. This behavior is consistent
    with `gsub` and `strip`.

    Before:

        'foobar'.truncate(5).frozen?
        # => true
        'foobar'.truncate(6).frozen?
        # => false

    After:

        'foobar'.truncate(5).frozen?
        # => false
        'foobar'.truncate(6).frozen?
        # => false

    *Jordan Thomas*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/activesupport/CHANGELOG.md) for previous changes.
