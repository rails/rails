module ActiveRecord
  module AttributeMethods
    module Write
      WriterMethodCache = Class.new {
        include Mutex_m

        def initialize
          super
          @module = Module.new
          @method_cache = {}
        end

        def [](name)
          synchronize do
            @method_cache.fetch(name) {
              safe_name = name.unpack('h*').first
              temp_method = "__temp__#{safe_name}="

              ActiveRecord::AttributeMethods::AttrNames.set_name_cache safe_name, name

              @module.module_eval <<-STR, __FILE__, __LINE__ + 1
                def #{temp_method}(value)
                  name = ::ActiveRecord::AttributeMethods::AttrNames::ATTR_#{safe_name}
                  write_attribute(name, value)
                end
              STR

              @method_cache[name] = @module.instance_method temp_method
            }
          end
        end
      }.new

      extend ActiveSupport::Concern

      included do
        attribute_method_suffix "="
      end

      module ClassMethods
        protected

        # See define_method_attribute in read.rb for an explanation of
        # this code.
        def define_method_attribute=(name)
          method = WriterMethodCache[name]
          generated_attribute_methods.module_eval {
            define_method "#{name}=", method
          }
        end
      end

      # Updates the attribute identified by <tt>attr_name</tt> with the
      # specified +value+. Empty strings for fixnum and float columns are
      # turned into +nil+.
      def write_attribute(attr_name, value)
        attr_name = attr_name.to_s
        attr_name = self.class.primary_key if attr_name == 'id' && self.class.primary_key
        @attributes_cache.delete(attr_name)
        column = column_for_attribute(attr_name)

        # If we're dealing with a binary column, write the data to the cache
        # so we don't attempt to typecast multiple times.
        if column && column.binary?
          @attributes_cache[attr_name] = value
        end

        if column || @attributes.has_key?(attr_name)
          @attributes[attr_name] = type_cast_attribute_for_write(column, value)
        else
          raise ActiveModel::MissingAttributeError, "can't write unknown attribute `#{attr_name}'"
        end
      end
      alias_method :raw_write_attribute, :write_attribute

      private
      # Handle *= for method_missing.
      def attribute=(attribute_name, value)
        write_attribute(attribute_name, value)
      end

      def type_cast_attribute_for_write(column, value)
        return value unless column

        column.type_cast_for_write value
      end
    end
  end
end
