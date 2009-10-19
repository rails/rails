module ActiveRecord
  module AttributeMethods
    module Read
      extend ActiveSupport::Concern

      ATTRIBUTE_TYPES_CACHED_BY_DEFAULT = [:datetime, :timestamp, :time, :date]

      included do
        attribute_method_suffix ""

        cattr_accessor :attribute_types_cached_by_default, :instance_writer => false
        self.attribute_types_cached_by_default = ATTRIBUTE_TYPES_CACHED_BY_DEFAULT

        # Undefine id so it can be used as an attribute name
        undef_method(:id) if method_defined?(:id)
      end

      module ClassMethods
        # +cache_attributes+ allows you to declare which converted attribute values should
        # be cached. Usually caching only pays off for attributes with expensive conversion
        # methods, like time related columns (e.g. +created_at+, +updated_at+).
        def cache_attributes(*attribute_names)
          attribute_names.each {|attr| cached_attributes << attr.to_s}
        end

        # Returns the attributes which are cached. By default time related columns
        # with datatype <tt>:datetime, :timestamp, :time, :date</tt> are cached.
        def cached_attributes
          @cached_attributes ||=
            columns.select{|c| attribute_types_cached_by_default.include?(c.type)}.map{|col| col.name}.to_set
        end

        # Returns +true+ if the provided attribute is being cached.
        def cache_attribute?(attr_name)
          cached_attributes.include?(attr_name)
        end

        protected
          def define_method_attribute(attr_name)
            define_read_method(attr_name.to_sym, attr_name, columns_hash[attr_name])

            if attr_name == primary_key && attr_name != "id"
              define_read_method(:id, attr_name, columns_hash[attr_name])
            end
          end

        private

          # Define an attribute reader method.  Cope with nil column.
          def define_read_method(symbol, attr_name, column)
            access_code = "_attributes['#{attr_name}']"
            unless attr_name.to_s == self.primary_key.to_s
              access_code = access_code.insert(0, "missing_attribute('#{attr_name}', caller) unless _attributes.key?('#{attr_name}'); ")
            end

            if cache_attribute?(attr_name)
              access_code = "@attributes_cache['#{attr_name}'] ||= (#{access_code})"
            end
            generated_attribute_methods.module_eval("def #{symbol}; #{access_code}; end", __FILE__, __LINE__)
          end
      end

      # Returns the value of the attribute identified by <tt>attr_name</tt> after it has been typecast (for example,
      # "2004-12-12" in a data column is cast to a date object, like Date.new(2004, 12, 12)).
      def read_attribute(attr_name)
        _attributes[attr_name]
      end

      private
        def attribute(attribute_name)
          read_attribute(attribute_name)
        end
    end
  end
end
