# frozen_string_literal: true

require "set"

module ActiveRecord
  module AttributeMethods
    module PrimaryKey
      extend ActiveSupport::Concern

      # Returns this record's primary key value wrapped in an array if one is
      # available.
      def to_key
        key = primary_key_value
        [key] if key
      end

      # If +use_id_as_attribute+ is set, this method will return the
      # +id+ attribute from the database. If it is not set, it returns
      # the primary key column's value. The latter is deprecated.
      def id
        if ActiveRecord.use_id_as_attribute
          _read_attribute("id")
        else
          if primary_key_is_not_id?
            # deprecation
            ActiveRecord.deprecator.warn(<<-MSG.squish)
              You are using a custom primary key and calling `id` to access it.

              Returning the primary key's value when calling `id` is deprecated. In Rails
              7.2 this method will return the value from the database for the `id` attribute
              if defined. To get the primary key's value, use `primary_key_value`.
            MSG
          end

          primary_key_value
        end
      end

      # Returns the primary key column's value.
      def primary_key_value
        if @primary_key.is_a?(Array)
          @primary_key.map { |pk| _read_attribute(pk) }
        else
          _read_attribute(@primary_key)
        end
      end

      def primary_key_values_present? # :nodoc:
        return primary_key_value.all? if self.class.composite_primary_key?

        !!primary_key_value
      end

      # If +use_id_as_attribute+ is set, this method will set the
      # +id+ attribute in the database. If it is not set, it sets
      # the primary key column's value. The latter is deprecated.
      def id=(value)
        if ActiveRecord.use_id_as_attribute
          _write_attribute("id", value)
        else
          if primary_key_is_not_id?
            ActiveRecord.deprecator.warn(<<-MSG.squish)
              You are using a custom primary key and calling `id=` to set it.

              Setting the primary key's value when calling `id=` is deprecated. In Rails
              7.2 this method will set the value from the database for the `id` attribute
              if defined. To set the primary key's value, use `primary_key_value=`.
            MSG
          end

          self.primary_key_value = value
        end
      end

      # Sets the primary key column's value.
      def primary_key_value=(value)
        if self.class.composite_primary_key?
          @primary_key.zip(value) { |attr, value| _write_attribute(attr, value) }
        else
          _write_attribute(@primary_key, value)
        end
      end

      # If +use_id_as_attribute+ is set, this method will query the
      # +id+ column's value. Otherwise this will query the primary key
      # column's value. If you are using a custom primary key, use the
      # +primary_key_value?+ method to avoid the deprecation warning.
      def id?
        if ActiveRecord.use_id_as_attribute
          query_attribute(ID_COLUMN)
        else
          if primary_key_is_not_id?
            ActiveRecord.deprecator.warn(<<-MSG.squish)
              Calling `id?` for a custom primary key is deprecated. In
              7.2 this method will query the `id` column's value. To
              query the primary key column's value use `primary_key_value?`
            MSG
          end

          primary_key_value?
        end
      end

      # Queries the primary key column's value.
      def primary_key_value?
        query_attribute(@primary_key)
      end

      # If +use_id_as_attribute+ is set, this method will return the
      # +id+ column's value before type casting. Otherwise this will
      # return the primary key's value before type casting. If you are
      # using a custom primary key, use the +primary_key_before_type_cast+
      # method to avoid the deprecation warning.
      def id_before_type_cast
        if ActiveRecord.use_id_as_attribute
          attribute_before_type_cast(ID_COLUMN)
        else
          if primary_key_is_not_id?
            ActiveRecord.deprecator.warn(<<-MSG.squish)
              Calling `primary_key_before_type_cast` for a custom primary key is
              deprecated. In 7.2 this method will return the value before type casting
              for the `id` attribute. To get the value before type casting for the primary
              key's use `primary_key_before_type_cast`.
            MSG
          end

          primary_key_before_type_cast
        end
      end

      # Returns the primary key column's value before type cast.
      def primary_key_before_type_cast
        attribute_before_type_cast(@primary_key)
      end

      # If +use_id_as_attribute+ is set, this method will return the
      # +id+ column's previous value. Otherwise this will return the
      # primary key's previous value. If you are using a custom primary
      # key, use the +primary_key_was+ method instead to avoid the
      # deprecation warning.
      def id_was
        if ActiveRecord.use_id_as_attribute
          attribute_was(ID_COLUMN)
        else
          if primary_key_is_not_id?
            ActiveRecord.deprecator.warn(<<-MSG.squish)
              Calling `id_was` for a custom primary key is deprecated. In 7.2
              this method will return the previous value for the `id` attribute. To
              get the primary key's previous value use `primary_key_was`.
            MSG
          end

          primary_key_was
        end
      end

      # Returns the primary key column's previous value.
      def primary_key_was
        attribute_was(@primary_key)
      end

      # If +use_id_as_attribute+ is set, this method will return the
      # +id+ attribute in the database. Otherwise this will return the
      # primary key value in the database. If you are using a custom primary
      # key, use the +primary_key_in_database+ method instead to avoid the
      # deprecation warning.
      def id_in_database
        if ActiveRecord.use_id_as_attribute
          attribute_in_database(ID_COLUMN)
        else
          if primary_key_is_not_id?
            ActiveRecord.deprecator.warn(<<-MSG.squish)
              Calling `id_in_database` for a custom primary key is deprecated. In 7.2
              this method will return the database value for the `id` attribute. To
              get the primary key from the database use `primary_key_in_database`.
            MSG
          end

          primary_key_in_database
        end
      end

      # Returns the primary key column's value from the database.
      def primary_key_in_database
        attribute_in_database(@primary_key)
      end

      def id_for_database # :nodoc:
        if ActiveRecord.use_id_as_attribute
          @attributes[ID_COLUMN].value_for_database
        else
          if primary_key_is_not_id?
            ActiveRecord.deprecator.warn(<<-MSG.squish)
              Calling `id_for_database` for a custom primary key is deprecated. In 7.2
              this method will use the database value for the `id` attribute. To
              use the primary key value for the database use `primary_key_for_database`.
            MSG
          end

          primary_key_for_database
        end
      end

      def primary_key_for_database # :nodoc:
        @attributes[@primary_key].value_for_database
      end

      private
        def primary_key_is_not_id?
          @primary_key != "id" #|| @primary_key != "ID"
        end

        def attribute_method?(attr_name)
          attr_name == "id" || super
        end

        module ClassMethods
          ID_ATTRIBUTE_METHODS = %w(id id= id? id_before_type_cast id_was id_in_database id_for_database).to_set
          PRIMARY_KEY_NOT_SET = BasicObject.new
          ID_COLUMN = "id"

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
            if PRIMARY_KEY_NOT_SET.equal?(@primary_key)
              @primary_key = reset_primary_key
            end
            @primary_key
          end

          def composite_primary_key? # :nodoc:
            primary_key.is_a?(Array)
          end

          # Returns a quoted version of the primary key name, used to construct
          # SQL statements.
          def quoted_primary_key
            @quoted_primary_key ||= connection.quote_column_name(primary_key)
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
            else
              if ActiveRecord::Base != self && table_exists?
                pk = connection.schema_cache.primary_keys(table_name)
                suppress_composite_primary_key(pk)
              else
                "id"
              end
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
            @primary_key        = derive_primary_key(value)
            @quoted_primary_key = nil
            @attributes_builder = nil
          end

          private
            def derive_primary_key(value)
              return unless value

              return -value.to_s unless value.is_a?(Array)

              value.map { |v| -v.to_s }.freeze
            end

            def inherited(base)
              super
              base.class_eval do
                @primary_key = PRIMARY_KEY_NOT_SET
                @quoted_primary_key = nil
              end
            end

            def suppress_composite_primary_key(pk)
              return pk unless pk.is_a?(Array)

              warn <<~WARNING
                WARNING: Active Record does not support composite primary key.

                #{table_name} has composite primary key. Composite primary key is ignored.
              WARNING
            end
        end
    end
  end
end
