module ActiveRecord
  ActiveSupport.on_load(:active_record_config) do
    mattr_accessor :attribute_types_cached_by_default, instance_accessor: false
  end

  module AttributeMethods
    module Read
      extend ActiveSupport::Concern

      ATTRIBUTE_TYPES_CACHED_BY_DEFAULT = [:datetime, :timestamp, :time, :date]

      included do
        config_attribute :attribute_types_cached_by_default
      end

      module ClassMethods
        # +cache_attributes+ allows you to declare which converted attribute values should
        # be cached. Usually caching only pays off for attributes with expensive conversion
        # methods, like time related columns (e.g. +created_at+, +updated_at+).
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

        # We want to generate the methods via module_eval rather than define_method,
        # because define_method is slower on dispatch and uses more memory (because it
        # creates a closure).
        #
        # But sometimes the database might return columns with characters that are not
        # allowed in normal method names (like 'my_column(omg)'. So to work around this
        # we first define with the __temp__ identifier, and then use alias method to
        # rename it to what we want.
        def define_method_attribute(attr_name)
          generated_attribute_methods.module_eval <<-STR, __FILE__, __LINE__ + 1
            def __temp__
              read_attribute(:'#{attr_name}') { |n| missing_attribute(n, caller) }
            end
            alias_method '#{attr_name}', :__temp__
            undef_method :__temp__
          STR
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

      ActiveRecord::Model.attribute_types_cached_by_default = ATTRIBUTE_TYPES_CACHED_BY_DEFAULT

      # Returns the value of the attribute identified by <tt>attr_name</tt> after it has been typecast (for example,
      # "2004-12-12" in a data column is cast to a date object, like Date.new(2004, 12, 12)).
      def read_attribute(attr_name)
        return unless attr_name
        name_sym = attr_name.to_sym

        # If it's cached, just return it
        # We use #[] first as a perf optimization for non-nil values. See https://gist.github.com/3552829.
        @attributes_cache[name_sym] || @attributes_cache.fetch(name_sym) {
          name = attr_name.to_s

          column = @columns_hash.fetch(name) {
            return @attributes.fetch(name) {
              if name_sym == :id && self.class.primary_key != name
                read_attribute(self.class.primary_key)
              end
            }
          }

          value = @attributes.fetch(name) {
            return block_given? ? yield(name) : nil
          }

          if self.class.cache_attribute?(name)
            @attributes_cache[name_sym] = column.type_cast(value)
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
