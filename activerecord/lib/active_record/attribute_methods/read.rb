require 'active_support/core_ext/module/method_transplanting'

module ActiveRecord
  module AttributeMethods
    module Read
      ReaderMethodCache = Class.new(AttributeMethodCache) {
        private
        # We want to generate the methods via module_eval rather than
        # define_method, because define_method is slower on dispatch.
        # Evaluating many similar methods may use more memory as the instruction
        # sequences are duplicated and cached (in MRI).  define_method may
        # be slower on dispatch, but if you're careful about the closure
        # created, then define_method will consume much less memory.
        #
        # But sometimes the database might return columns with
        # characters that are not allowed in normal method names (like
        # 'my_column(omg)'. So to work around this we first define with
        # the __temp__ identifier, and then use alias method to rename
        # it to what we want.
        #
        # We are also defining a constant to hold the frozen string of
        # the attribute name. Using a constant means that we do not have
        # to allocate an object on each call to the attribute method.
        # Making it frozen means that it doesn't get duped when used to
        # key the @attributes_cache in read_attribute.
        def method_body(method_name, const_name)
          <<-EOMETHOD
          def #{method_name}
            name = ::ActiveRecord::AttributeMethods::AttrNames::ATTR_#{const_name}
            read_attribute(name) { |n| missing_attribute(n, caller) }
          end
          EOMETHOD
        end
      }.new

      extend ActiveSupport::Concern

      ATTRIBUTE_TYPES_CACHED_BY_DEFAULT = [:datetime, :timestamp, :time, :date]

      included do
        class_attribute :attribute_types_cached_by_default, instance_writer: false
        self.attribute_types_cached_by_default = ATTRIBUTE_TYPES_CACHED_BY_DEFAULT
      end

      module ClassMethods
        # +cache_attributes+ allows you to declare which converted attribute
        # values should be cached. Usually caching only pays off for attributes
        # with expensive conversion methods, like time related columns (e.g.
        # +created_at+, +updated_at+).
        def cache_attributes(*attribute_names)
          cached_attributes.merge attribute_names.map { |attr| attr.to_s }
        end

        # Returns the attributes which are cached. By default time related columns
        # with datatype <tt>:datetime, :timestamp, :time, :date</tt> are cached.
        def cached_attributes
          @cached_attributes ||= columns.select { |c| cacheable_column?(c) }.map { |col| col.name }.to_set
        end

        # Returns +true+ if the provided attribute is being cached.
        def cache_attribute?(attr_name)
          cached_attributes.include?(attr_name)
        end

        protected

        if Module.methods_transplantable?
          def define_method_attribute(name)
            method = ReaderMethodCache[name]
            generated_attribute_methods.module_eval { define_method name, method }
          end
        else
          def define_method_attribute(name)
            safe_name = name.unpack('h*').first
            temp_method = "__temp__#{safe_name}"

            ActiveRecord::AttributeMethods::AttrNames.set_name_cache safe_name, name

            generated_attribute_methods.module_eval <<-STR, __FILE__, __LINE__ + 1
              def #{temp_method}
                name = ::ActiveRecord::AttributeMethods::AttrNames::ATTR_#{safe_name}
                read_attribute(name) { |n| missing_attribute(n, caller) }
              end
            STR

            generated_attribute_methods.module_eval do
              alias_method name, temp_method
              undef_method temp_method
            end
          end
        end

        private

        def cacheable_column?(column)
          if attribute_types_cached_by_default == ATTRIBUTE_TYPES_CACHED_BY_DEFAULT
            ! serialized_attributes.include? column.name
          else
            attribute_types_cached_by_default.include?(column.type)
          end
        end
      end

      # Returns the value of the attribute identified by <tt>attr_name</tt> after
      # it has been typecast (for example, "2004-12-12" in a date column is cast
      # to a date object, like Date.new(2004, 12, 12)).
      def read_attribute(attr_name)
        # If it's cached, just return it
        # We use #[] first as a perf optimization for non-nil values. See https://gist.github.com/jonleighton/3552829.
        name = attr_name.to_s
        @attributes_cache[name] || @attributes_cache.fetch(name) {
          column = @column_types_override[name] if @column_types_override
          column ||= @column_types[name]

          return @attributes.fetch(name) {
            if name == 'id' && self.class.primary_key != name
              read_attribute(self.class.primary_key)
            end
          } unless column

          value = @attributes.fetch(name) {
            return block_given? ? yield(name) : nil
          }

          if self.class.cache_attribute?(name)
            @attributes_cache[name] = column.type_cast(value)
          else
            column.type_cast value
          end
        }
      end

      private

      def attribute(attribute_name)
        read_attribute(attribute_name)
      end
    end
  end
end
