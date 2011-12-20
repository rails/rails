module ActiveRecord
  module AttributeMethods
    module PrimaryKey
      extend ActiveSupport::Concern

      # Returns this record's primary key value wrapped in an Array if one is available
      def to_key
        key = self.id
        [key] if key
      end

      # Returns the primary key value
      def id
        read_attribute(self.class.primary_key)
      end

      # Sets the primary key value
      def id=(value)
        write_attribute(self.class.primary_key, value)
      end

      # Queries the primary key value
      def id?
        query_attribute(self.class.primary_key)
      end

      module ClassMethods
        def define_method_attribute(attr_name)
          super

          if attr_name == primary_key && attr_name != 'id'
            generated_attribute_methods.send(:alias_method, :id, primary_key)
            generated_external_attribute_methods.module_eval <<-CODE, __FILE__, __LINE__
              def id(v, attributes, attributes_cache, attr_name)
                attr_name = '#{primary_key}'
                send(attr_name, attributes[attr_name], attributes, attributes_cache, attr_name)
              end
            CODE
          end
        end

        def dangerous_attribute_method?(method_name)
          super && !['id', 'id=', 'id?'].include?(method_name)
        end

        # Defines the primary key field -- can be overridden in subclasses. Overwriting will negate any effect of the
        # primary_key_prefix_type setting, though.
        def primary_key
          @primary_key = reset_primary_key unless defined? @primary_key
          @primary_key
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
            if ActiveRecord::Base != self && table_exists?
              connection.schema_cache.primary_keys[table_name]
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
