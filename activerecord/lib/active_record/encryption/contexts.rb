# frozen_string_literal: true

module ActiveRecord
  module Encryption
    # +ActiveRecord::Encryption+ uses encryption contexts to configure the different entities used to
    # encrypt/decrypt at a given moment in time.
    #
    # By default, the library uses a default encryption context. This is the +Context+ that gets configured
    # initially via +config.active_record.encryption+ options. Library users can define nested encryption contexts
    # when running blocks of code.
    #
    # See +Context+.
    module Contexts
      extend ActiveSupport::Concern

      included do
        mattr_reader :default_context, default: Context.new
        thread_mattr_accessor :custom_contexts
      end

      class_methods do
        # Configures a custom encryption context to use when running the provided block of code.
        #
        # It supports overriding all the properties defined in +Context+.
        #
        # Example:
        #
        #     ActiveRecord::Encryption.with_encryption_context(encryptor: ActiveRecord::Encryption::NullEncryptor.new) do
        #       ...
        #     end
        #
        # Encryption contexts can be nested.
        def with_encryption_context(properties)
          self.custom_contexts ||= []
          self.custom_contexts << default_context.dup
          properties.each do |key, value|
            self.current_custom_context.send("#{key}=", value)
          end

          yield
        ensure
          self.custom_contexts.pop
        end

        # Runs the provided block in an encryption context where encryption is disabled:
        #
        # * Reading encrypted content will return its ciphertexts.
        # * Writing encrypted content will write its clear text.
        def without_encryption(&block)
          with_encryption_context encryptor: ActiveRecord::Encryption::NullEncryptor.new, &block
        end

        # Runs the provided block in an encryption context where:
        #
        # * Reading encrypted content will return its ciphertext.
        # * Writing encrypted content will fail.
        def protecting_encrypted_data(&block)
          with_encryption_context encryptor: ActiveRecord::Encryption::EncryptingOnlyEncryptor.new, frozen_encryption: true, &block
        end

        # Returns the current context. By default it will return the current context.
        def context
          self.current_custom_context || self.default_context
        end

        def current_custom_context
          self.custom_contexts&.last
        end
      end
    end
  end
end
