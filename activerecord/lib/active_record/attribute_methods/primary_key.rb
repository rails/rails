# frozen_string_literal: true

module ActiveRecord
  module AttributeMethods
    # = Active Record Attribute Methods Primary Key
    module PrimaryKey
      extend ActiveSupport::Concern

      # Returns this record's primary key value wrapped in an array if one is
      # available.
      def to_key
        key = id
        Array(key) if key
      end

      # Returns the primary key column's value. If the primary key is composite,
      # returns an array of the primary key column values.
      def id
        _read_attribute(@primary_key)
      end

      def primary_key_values_present? # :nodoc:
        !!id
      end

      # Sets the primary key column's value. If the primary key is composite,
      # raises TypeError when the set value not enumerable.
      def id=(value)
        _write_attribute(@primary_key, value)
      end

      # Queries the primary key column's value. If the primary key is composite,
      # all primary key column values must be queryable.
      def id?
        _query_attribute(@primary_key)
      end

      # Returns the primary key column's value before type cast. If the primary key is composite,
      # returns an array of primary key column values before type cast.
      def id_before_type_cast
        attribute_before_type_cast(@primary_key)
      end

      # Returns the primary key column's previous value. If the primary key is composite,
      # returns an array of primary key column previous values.
      def id_was
        attribute_was(@primary_key)
      end

      # Returns the primary key column's value from the database. If the primary key is composite,
      # returns an array of primary key column values from database.
      def id_in_database
        attribute_in_database(@primary_key)
      end

      def id_for_database # :nodoc:
        @attributes[@primary_key].value_for_database
      end

      private
        def attribute_method?(attr_name)
          attr_name == "id" || super
        end

        module ClassMethods
          ID_ATTRIBUTE_METHODS = %w(id id= id? id_before_type_cast id_was id_in_database id_for_database).to_set
          PRIMARY_KEY_NOT_SET = BasicObject.new

          def instance_method_already_implemented?(method_name)
            super || primary_key && ID_ATTRIBUTE_METHODS.include?(method_name)
          end

          def dangerous_attribute_method?(method_name)
            super && !ID_ATTRIBUTE_METHODS.include?(method_name)
          end

          # Defines the primary key field -- can be overridden in subclasses.
          # Overwriting will negate any effect of the +primary_key_prefix_type+
          # setting, though.
          def primary_key
            reset_primary_key if PRIMARY_KEY_NOT_SET.equal?(@primary_key)
            @primary_key
          end

          def composite_primary_key? # :nodoc:
            reset_primary_key if PRIMARY_KEY_NOT_SET.equal?(@primary_key)
            @composite_primary_key
          end

          # Returns a quoted version of the primary key name.
          def quoted_primary_key
            adapter_class.quote_column_name(primary_key)
          end

          def reset_primary_key # :nodoc:
            if base_class?
              self.primary_key = get_primary_key(base_class.name)
            else
              self.primary_key = base_class.primary_key
            end
          end

          def get_primary_key(base_name) # :nodoc:
            if base_name && primary_key_prefix_type == :table_name
              base_name.foreign_key(false)
            elsif base_name && primary_key_prefix_type == :table_name_with_underscore
              base_name.foreign_key
            elsif ActiveRecord::Base != self && table_exists?
              schema_cache.primary_keys(table_name)
            else
              "id"
            end
          end

          # Sets the name of the primary key column.
          #
          #   class Project < ActiveRecord::Base
          #     self.primary_key = 'sysid'
          #   end
          #
          # You can also define the #primary_key method yourself:
          #
          #   class Project < ActiveRecord::Base
          #     def self.primary_key
          #       'foo_' + super
          #     end
          #   end
          #
          #   Project.primary_key # => "foo_id"
          def primary_key=(value)
            @primary_key = if value.is_a?(Array)
              @composite_primary_key = true
              include CompositePrimaryKey
              @primary_key = value.map { |v| -v.to_s }.freeze
            elsif value
              -value.to_s
            end
            @attributes_builder = nil
          end

          private
            def inherited(base)
              super
              base.class_eval do
                @primary_key = PRIMARY_KEY_NOT_SET
                @composite_primary_key = false
                @attributes_builder = nil
              end
            end
        end
    end
  end
end
