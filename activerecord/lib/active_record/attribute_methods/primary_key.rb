require 'set'

module ActiveRecord
  module AttributeMethods
    module PrimaryKey
      extend ActiveSupport::Concern

      # Returns this record's primary key value wrapped in an Array if one is
      # available.
      def to_key
        sync_with_transaction_state
        key = self.id
        [key] if key
      end

      # Returns the primary key value.
      def id
        sync_with_transaction_state
        read_attribute(self.class.primary_key)
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

      protected

      def attribute_method?(attr_name)
        attr_name == 'id' || super
      end

      module ClassMethods
        def define_method_attribute(attr_name)
          super

          if attr_name == primary_key && attr_name != 'id'
            generated_attribute_methods.send(:alias_method, :id, primary_key)
          end
        end

        ID_ATTRIBUTE_METHODS = %w(id id= id? id_before_type_cast).to_set

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
          return 'id' if base_name.blank?

          case primary_key_prefix_type
          when :table_name
            base_name.foreign_key(false)
          when :table_name_with_underscore
            base_name.foreign_key
          else
            if ActiveRecord::Base != self && table_exists?
              connection.schema_cache.primary_keys[table_name]
            else
              'id'
            end
          end
        end

        # Sets the name of the primary key column.
        #
        #   class Project < ActiveRecord::Base
        #     self.primary_key = 'sysid'
        #   end
        #
        # You can also define the +primary_key+ method yourself:
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
        end
      end
    end
  end
end
