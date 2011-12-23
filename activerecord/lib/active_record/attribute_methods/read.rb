module ActiveRecord
  module AttributeMethods
    module Read
      extend ActiveSupport::Concern

      ATTRIBUTE_TYPES_CACHED_BY_DEFAULT = [:datetime, :timestamp, :time, :date]

      included do
        cattr_accessor :attribute_types_cached_by_default, :instance_writer => false
        self.attribute_types_cached_by_default = ATTRIBUTE_TYPES_CACHED_BY_DEFAULT
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

        def undefine_attribute_methods
          generated_external_attribute_methods.module_eval do
            instance_methods.each { |m| undef_method(m) }
          end

          super
        end

        def type_cast_attribute(attr_name, attributes, cache = {}) #:nodoc:
          return unless attr_name
          attr_name = attr_name.to_s

          if generated_external_attribute_methods.method_defined?(attr_name)
            if attributes.has_key?(attr_name) || attr_name == 'id'
              generated_external_attribute_methods.send(attr_name, attributes[attr_name], attributes, cache, attr_name)
            end
          elsif !attribute_methods_generated?
            # If we haven't generated the caster methods yet, do that and
            # then try again
            define_attribute_methods
            type_cast_attribute(attr_name, attributes, cache)
          else
            # If we get here, the attribute has no associated DB column, so
            # just return it verbatim.
            attributes[attr_name]
          end
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
            cast_code = attribute_cast_code(attr_name)

            generated_attribute_methods.module_eval <<-STR, __FILE__, __LINE__ + 1
              def __temp__
                #{internal_attribute_access_code(attr_name, cast_code)}
              end
              alias_method '#{attr_name}', :__temp__
              undef_method :__temp__
            STR

            generated_external_attribute_methods.module_eval <<-STR, __FILE__, __LINE__ + 1
              def __temp__(v, attributes, attributes_cache, attr_name)
                #{external_attribute_access_code(attr_name, cast_code)}
              end
              alias_method '#{attr_name}', :__temp__
              undef_method :__temp__
            STR
          end

        private
          def cacheable_column?(column)
            attribute_types_cached_by_default.include?(column.type)
          end

          def internal_attribute_access_code(attr_name, cast_code)
            access_code = "(v=@attributes[attr_name]) && #{cast_code}"

            unless attr_name == primary_key
              access_code.insert(0, "missing_attribute(attr_name, caller) unless @attributes.has_key?(attr_name); ")
            end

            if cache_attribute?(attr_name)
              access_code = "@attributes_cache[attr_name] ||= (#{access_code})"
            end

            "attr_name = '#{attr_name}'; #{access_code}"
          end

          def external_attribute_access_code(attr_name, cast_code)
            access_code = "v && #{cast_code}"

            if cache_attribute?(attr_name)
              access_code = "attributes_cache[attr_name] ||= (#{access_code})"
            end

            access_code
          end

          def attribute_cast_code(attr_name)
            columns_hash[attr_name].type_cast_code('v')
          end
      end

      # Returns the value of the attribute identified by <tt>attr_name</tt> after it has been typecast (for example,
      # "2004-12-12" in a data column is cast to a date object, like Date.new(2004, 12, 12)).
      def read_attribute(attr_name)
        self.class.type_cast_attribute(attr_name, @attributes, @attributes_cache)
      end

      private
        def attribute(attribute_name)
          read_attribute(attribute_name)
        end
    end
  end
end
