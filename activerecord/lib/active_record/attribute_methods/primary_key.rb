require "set"

module ActiveRecord
  module AttributeMethods
    module PrimaryKey
      extend ActiveSupport::Concern

      # Returns this record's primary key value wrapped in an array if one is
      # available.
      def to_key
        sync_with_transaction_state
        key = id
        [key] if key
      end

      # Returns the primary key value.
      def id
        if pk = self.class.primary_key
          sync_with_transaction_state
          _read_attribute(pk)
        end
      end

      # Sets the primary key value.
      def id=(value)
        sync_with_transaction_state
        write_attribute(self.class.primary_key, value) if self.class.primary_key
      end

      # Queries the primary key value.
      def id?
        sync_with_transaction_state
        query_attribute(self.class.primary_key)
      end

      # Returns the primary key value before type cast.
      def id_before_type_cast
        sync_with_transaction_state
        read_attribute_before_type_cast(self.class.primary_key)
      end

      # Returns the primary key previous value.
      def id_was
        sync_with_transaction_state
        attribute_was(self.class.primary_key)
      end

      def id_in_database
        sync_with_transaction_state
        attribute_in_database(self.class.primary_key)
      end

      private

        def attribute_method?(attr_name)
          attr_name == "id" || super
        end

        module ClassMethods
          ID_ATTRIBUTE_METHODS = %w(id id= id? id_before_type_cast id_was id_in_database).to_set

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
            @primary_key = reset_primary_key unless defined? @primary_key
            @primary_key
          end

          # Returns a quoted version of the primary key name, used to construct
          # SQL statements.
          def quoted_primary_key
            @quoted_primary_key ||= connection.quote_column_name(primary_key)
          end

          def reset_primary_key #:nodoc:
            if self == base_class
              self.primary_key = get_primary_key(base_class.name)
            else
              self.primary_key = base_class.primary_key
            end
          end

          def get_primary_key(base_name) #:nodoc:
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
            @primary_key        = value && value.to_s
            @quoted_primary_key = nil
            @attributes_builder = nil
          end

          private

            def suppress_composite_primary_key(pk)
              return pk unless pk.is_a?(Array)

              warn <<-WARNING.strip_heredoc
                WARNING: Active Record does not support composite primary key.

                #{table_name} has composite primary key. Composite primary key is ignored.
              WARNING
            end
        end
    end
  end
end
