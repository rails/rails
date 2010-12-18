module ActiveRecord
  module AttributeMethods
    module PrimaryKey
      extend ActiveSupport::Concern

      # Returns this record's primary key value wrapped in an Array
      # or nil if the record is a new_record?
      def to_key
        new_record? ? nil : [ id ]
      end

      module ClassMethods
        # Defines the primary key field -- can be overridden in subclasses. Overwriting will negate any effect of the
        # primary_key_prefix_type setting, though.
        def primary_key
          reset_primary_key
        end

        def reset_primary_key #:nodoc:
          key = get_primary_key(base_class.name)
          set_primary_key(key)
          key
        end

        def get_primary_key(base_name) #:nodoc:
          key = 'id'
          case primary_key_prefix_type
            when :table_name
              key = base_name.to_s.foreign_key(false)
            when :table_name_with_underscore
              key = base_name.to_s.foreign_key
          end
          key
        end

        # Sets the name of the primary key column to use to the given value,
        # or (if the value is nil or false) to the value returned by the given
        # block.
        #
        #   class Project < ActiveRecord::Base
        #     set_primary_key "sysid"
        #   end
        def set_primary_key(value = nil, &block)
          define_attr_method :primary_key, value, &block
        end
        alias :primary_key= :set_primary_key
      end
    end
  end
end
