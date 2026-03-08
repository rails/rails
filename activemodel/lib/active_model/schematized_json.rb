# frozen_string_literal: true

require "active_support/core_ext/hash/reverse_merge"
require "active_support/core_ext/symbol/starts_ends_with"

module ActiveModel
  module SchematizedJson
    extend ActiveSupport::Concern

    module ClassMethods
      # Provides a schema-enforced access object for a JSON attribute. This allows you to assign values
      # directly from the UI as strings, and still have them set with the correct JSON type in the database.
      #
      # Only the three basic JSON types are supported: boolean, integer, and string. No nesting either.
      # These types can either be set by referring to them by their symbol or by setting a default value.
      # Default values are set when a new model is instantiated and on +before_save+ (if defined).
      #
      # Examples:
      #
      #   class Account < ApplicationRecord
      #     has_json :settings, restrict_creation_to_admins: true, max_invites: 10, greeting: "Hello!"
      #     has_json :flags, beta: false, staff: :boolean
      #   end
      #
      #   a = Account.new
      #   a.settings.restrict_creation_to_admins? # => true
      #   a.settings.max_invites = "100" # => Set to integer 100
      #   a.settings = { "restrict_creation_to_admins" => "false", "max_invites" => "500", "greeting" => "goodbye" }
      #   a.settings.greeting # => "goodbye"
      #   a.flags.staff # => nil
      #   a.flags.staff? # => false
      def has_json(attr, **schema)
        define_method(attr) do
          # Ensure the attribute is set if nil, so we can pass the reference to the accessor for defaults.
          _write_attribute(attr.to_s, {}) if attribute(attr.to_s).nil?

          # No memoization used in order to stay compatible with #reload (and because it's such a thin accessor).
          ActiveModel::SchematizedJson::DataAccessor.new(schema, data: attribute(attr.to_s))
        end

        define_method("#{attr}=") { |data| public_send(attr).assign_data_with_type_casting(data) }

        # Ensure default values are set before saving by relying on DataAccessor instantiation to do it.
        before_save -> { send(attr) } if respond_to?(:before_save)
      end

      # Like +has_json+ but each schema key also becomes its own set of accessor methods.
      #
      #   class Account < ApplicationRecord
      #     has_delegated_json :flags, beta: false, staff: :boolean
      #   end
      #
      #   a = Account.new
      #   a.beta? # => false
      #   a.beta = true
      #   a.beta # => true
      def has_delegated_json(attr, **schema)
        has_json attr, **schema

        schema.keys.each do |schema_key|
          define_method(schema_key)       { public_send(attr).public_send(schema_key) }
          define_method("#{schema_key}?") { public_send(attr).public_send("#{schema_key}?") }
          define_method("#{schema_key}=") { |value| send(attr).public_send("#{schema_key}=", value) }
        end
      end
    end

    # :nodoc:
    class DataAccessor
      def initialize(schema, data:)
        @schema, @data = schema, data
        update_data_with_schema_defaults
      end

      def assign_data_with_type_casting(new_data)
        new_data.each { |k, v| public_send "#{k}=", v }
      end

      private
        def method_missing(method_name, *args, **kwargs)
          key = method_name.to_s.remove(/(\?|=)/)

          if @schema.key? key.to_sym
            if method_name.ends_with?("?")
              @data[key].present?
            elsif method_name.ends_with?("=")
              @data[key] = lookup_schema_type_for(key).cast(args.first)
            else
              @data[key]
            end
          else
            super
          end
        end

        def respond_to_missing?(method_name, include_private = false)
          @schema.key?(method_name.to_s.remove(/[?=]/).to_sym) || super
        end

        def lookup_schema_type_for(key)
          type_or_default_value = @schema[key.to_sym]

          case type_or_default_value
          when :boolean, :integer, :string
            ActiveModel::Type.lookup type_or_default_value
          when TrueClass, FalseClass
            ActiveModel::Type.lookup :boolean
          when Integer
            ActiveModel::Type.lookup :integer
          when String
            ActiveModel::Type.lookup :string
          else
            raise ArgumentError, "Only boolean, integer, or strings are allowed as JSON schema types"
          end
        end

        # Types that are declared using real values, like true/false, 5, or "hello", will be used as defaults.
        # Types that are declared using symbols, like :boolean, :integer, :string, will be nulled out.
        def update_data_with_schema_defaults
          @data.reverse_merge!(@schema.to_h { |attr, type| [ attr.to_s, type.is_a?(Symbol) ? nil : type ] })
        end
    end
  end
end
