# frozen_string_literal: true

# :markup: markdown
module ActiveRecord
  module AttributeMethods
    # Active Record Attribute Methods Primary Key
    # ===========================================
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
          ID_ATTRIBUTE_METHODS = %w(id id= id? id_before_type_cast id_was id_in_database id_for_database).to_set.freeze

          def instance_method_already_implemented?(method_name)
            super || primary_key && ID_ATTRIBUTE_METHODS.include?(method_name)
          end

          def dangerous_attribute_method?(method_name)
            super && !ID_ATTRIBUTE_METHODS.include?(method_name)
          end

          # Defines the primary key field -- can be overridden in subclasses.
          # Overwriting will negate any effect of the `primary_key_prefix_type`
          # setting, though.
          def primary_key
            primary_key_definition.name
          end

          def composite_primary_key? # :nodoc:
            primary_key_definition&.composite?
          end

          def primary_key_definition # :nodoc:
            @primary_key_definition || load_primary_key_definition
          end

          # Returns a quoted version of the primary key name.
          def quoted_primary_key
            adapter_class.quote_column_name(primary_key)
          end

          def reset_primary_key # :nodoc:
            ActiveSupport::Ractors.on_main(self) do
              if base_class?
                self.primary_key = get_primary_key(base_class.name)
              else
                self.primary_key = base_class.primary_key
              end
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
          # ```
          # class Project < ActiveRecord::Base
          #   self.primary_key = 'sysid'
          # end
          # ```
          def primary_key=(value)
            @primary_key_definition = ActiveRecord::Key.for(value)
            @primary_key_inherited = false

            include CompositePrimaryKey if primary_key_definition.composite?

            # Only invalidate loaded contexts; initial schema loading can resolve the primary key.
            ([self] + descendants).each do |model|
              model.clear_inherited_primary_key
              model.reload_schema_from_cache(false) if model.schema_loaded?
              # Regenerate so the id_value reader is replaced by an alias.
              model.undefine_attribute_methods if primary_key_definition.composite? && model.attribute_methods_generated?
            end
          end

          protected
            def clear_inherited_primary_key # :nodoc:
              @primary_key_definition = nil if @primary_key_inherited
            end

          private
            # Subclasses inherit the primary key of the closest ancestor that
            # has one, otherwise it is resolved from the schema.
            def load_primary_key_definition
              ActiveSupport::Ractors.on_main(self) do
                definition = inherited_primary_key_definition
                definition ||= base_class.primary_key_definition unless base_class?

                if definition
                  @primary_key_definition = definition
                  @primary_key_inherited = true
                else
                  reset_primary_key
                end

                @primary_key_definition
              end
            end

            def inherited_primary_key_definition
              klass = self
              while klass != Base
                klass = klass.superclass
                definition = klass.instance_variable_get(:@primary_key_definition)
                return definition if definition
              end
              nil
            end
        end
    end
  end
end
