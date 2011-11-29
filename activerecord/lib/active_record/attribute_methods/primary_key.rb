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
          if self == base_class
            self.primary_key = get_primary_key(base_class.name)
          else
            self.primary_key = base_class.primary_key
          end
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

        def original_primary_key #:nodoc:
          deprecated_original_property_getter :primary_key
        end

        # Sets the name of the primary key column.
        #
        #   class Project < ActiveRecord::Base
        #     self.primary_key = "sysid"
        #   end
        #
        # You can also define the primary_key method yourself:
        #
        #   class Project < ActiveRecord::Base
        #     def self.primary_key
        #       "foo_" + super
        #     end
        #   end
        #   Project.primary_key # => "foo_id"
        def primary_key=(value)
          @original_primary_key = @primary_key if defined?(@primary_key)
          @primary_key          = value && value.to_s
          @quoted_primary_key   = nil
        end

        def set_primary_key(value = nil, &block) #:nodoc:
          deprecated_property_setter :primary_key, value, block
          @quoted_primary_key = nil
        end
      end
    end
  end
end
