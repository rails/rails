# frozen_string_literal: true

module ActiveRecord
  module Encryption
    # Configuration API for +ActiveRecord::Encryption+
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

        def configure(primary_key:, deterministic_key:, key_derivation_salt:, **properties) # :nodoc:
          config.primary_key = primary_key
          config.deterministic_key = deterministic_key
          config.key_derivation_salt = key_derivation_salt

          context.key_provider = ActiveRecord::Encryption::DerivedSecretKeyProvider.new(primary_key)

          properties.each do |name, value|
            [:context, :config].each do |configurable_object_name|
              configurable_object = ActiveRecord::Encryption.send(configurable_object_name)
              configurable_object.send "#{name}=", value if configurable_object.respond_to?("#{name}=")
            end
          end
        end

        # Register callback to be invoked when an encrypted attribute is declared.
        #
        # === Example:
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

        def install_auto_filtered_parameters_hook(application) # :nodoc:
          ActiveRecord::Encryption.on_encrypted_attribute_declared do |klass, encrypted_attribute_name|
            application.config.filter_parameters << encrypted_attribute_name unless ActiveRecord::Encryption.config.excluded_from_filter_parameters.include?(encrypted_attribute_name)
          end
        end
      end
    end
  end
end
