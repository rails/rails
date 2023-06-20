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

        def install_auto_filtered_parameters_hook(app) # :nodoc:
          ActiveRecord::Encryption.on_encrypted_attribute_declared do |klass, encrypted_attribute_name|
            filter = [("#{klass.model_name.element}" if klass.name), encrypted_attribute_name.to_s].compact.join(".")
            unless excluded_from_filter_parameters?(filter)
              app.config.filter_parameters << filter unless app.config.filter_parameters.include?(filter)
              klass.filter_attributes += [encrypted_attribute_name]
            end
          end
        end

        private
          def excluded_from_filter_parameters?(filter_parameter)
            ActiveRecord::Encryption.config.excluded_from_filter_parameters.find { |excluded_filter| excluded_filter.to_s == filter_parameter }
          end
      end
    end
  end
end
