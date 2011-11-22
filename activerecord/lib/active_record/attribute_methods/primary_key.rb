module ActiveRecord
  module AttributeMethods
    module PrimaryKey
      extend ActiveSupport::Concern

      # Returns this record's primary key value wrapped in an Array if one is available
      def to_key
        key = send(self.class.primary_key)
        [key] if key
      end

      module ClassMethods
        # Defines the primary key field -- can be overridden in subclasses. Overwriting will negate any effect of the
        # primary_key_prefix_type setting, though.
        def primary_key
          @primary_key ||= reset_primary_key
        end

        # Returns a quoted version of the primary key name, used to construct SQL statements.
        def quoted_primary_key
          @quoted_primary_key ||= connection.quote_column_name(primary_key)
        end

        def reset_primary_key #:nodoc:
          key = self == base_class ? get_primary_key(base_class.name) :
            base_class.primary_key

          set_primary_key(key)
          key
        end

        def get_primary_key(base_name) #:nodoc:
          return 'id' unless base_name && !base_name.blank?

          case primary_key_prefix_type
          when :table_name
            base_name.foreign_key(false)
          when :table_name_with_underscore
            base_name.foreign_key
          else
            if ActiveRecord::Base != self && connection.table_exists?(table_name)
              connection.primary_key(table_name)
            else
              'id'
            end
          end
        end

        attr_accessor :original_primary_key

        # Attribute writer for the primary key column
        def primary_key=(value)
          @quoted_primary_key = nil
          @primary_key = value
        end

        # Sets the name of the primary key column to use to the given value,
        # or (if the value is nil or false) to the value returned by the given
        # block.
        #
        #   class Project < ActiveRecord::Base
        #     set_primary_key "sysid"
        #   end
        def set_primary_key(value = nil, &block)
          @quoted_primary_key = nil
          @primary_key ||= ''
          self.original_primary_key = @primary_key
          value &&= value.to_s
          self.primary_key = block_given? ? instance_eval(&block) : value
        end
      end
    end
  end
end
