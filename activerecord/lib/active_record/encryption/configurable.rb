# frozen_string_literal: true

module ActiveRecord
  module Encryption
    # Configuration API for ActiveRecord::Encryption
    module Configurable
      extend ActiveSupport::Concern

      included do
        mattr_reader :config, default: Config.new
        mattr_accessor :encrypted_attribute_declaration_listeners
      end

      class_methods do
        # Expose getters for context properties
        Context::PROPERTIES.each do |name|
          delegate name, to: :context
        end

        def configure(primary_key: nil, deterministic_key: nil, key_derivation_salt: nil, **properties) # :nodoc:
          config.primary_key = primary_key
          config.deterministic_key = deterministic_key
          config.key_derivation_salt = key_derivation_salt

          # Set the default for this property here instead of in +Config#set_defaults+ as this needs
          # to happen *after* the keys have been set.
          properties[:support_sha1_for_non_deterministic_encryption] = true if properties[:support_sha1_for_non_deterministic_encryption].nil?

          properties.each do |name, value|
            ActiveRecord::Encryption.config.send "#{name}=", value if ActiveRecord::Encryption.config.respond_to?("#{name}=")
          end

          ActiveRecord::Encryption.reset_default_context

          properties.each do |name, value|
            ActiveRecord::Encryption.context.send "#{name}=", value if ActiveRecord::Encryption.context.respond_to?("#{name}=")
          end
        end

        # Register callback to be invoked when an encrypted attribute is declared.
        #
        # === Example
        #
        #   ActiveRecord::Encryption.on_encrypted_attribute_declared do |klass, attribute_name|
        #     ...
        #   end
        def on_encrypted_attribute_declared(&block)
          self.encrypted_attribute_declaration_listeners ||= Concurrent::Array.new
          self.encrypted_attribute_declaration_listeners << block
        end

        def encrypted_attribute_was_declared(klass, name) # :nodoc:
          self.encrypted_attribute_declaration_listeners&.each do |block|
            block.call(klass, name)
          end
        end
      end
    end
  end
end
