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
          if base_class == self
            generated_attribute_methods.module_eval do
              public_methods(false).each do |m|
                singleton_class.send(:undef_method, m) if m.to_s =~ /^cast_/
              end
            end
          end

          super
        end

        protected
          # Where possible, generate the method by evalling a string, as this will result in
          # faster accesses because it avoids the block eval and then string eval incurred
          # by the second branch.
          #
          # The second, slower, branch is necessary to support instances where the database
          # returns columns with extra stuff in (like 'my_column(omg)').
          def define_method_attribute(attr_name)
            access_code = attribute_access_code(attr_name)
            cast_code   = "v && (#{attribute_cast_code(attr_name)})"

            if attr_name =~ ActiveModel::AttributeMethods::NAME_COMPILABLE_REGEXP
              generated_attribute_methods.module_eval <<-STR, __FILE__, __LINE__
                def #{attr_name}
                  #{access_code}
                end

                def self.cast_#{attr_name}(v)
                  #{cast_code}
                end

                alias _#{attr_name} #{attr_name}
              STR
            else
              generated_attribute_methods.module_eval do
                define_method(attr_name) do
                  eval(access_code)
                end

                singleton_class.send(:define_method, "cast_#{attr_name}") do |v|
                  eval(cast_code)
                end

                alias_method("_#{attr_name}", attr_name)
              end
            end
          end

        private
          def cacheable_column?(column)
            attribute_types_cached_by_default.include?(column.type)
          end

          def attribute_access_code(attr_name)
            access_code = "(v=@attributes['#{attr_name}']) && #{attribute_cast_code(attr_name)}"

            unless attr_name == self.primary_key
              access_code.insert(0, "missing_attribute('#{attr_name}', caller) unless @attributes.has_key?('#{attr_name}'); ")
            end

            if cache_attribute?(attr_name)
              access_code = "@attributes_cache['#{attr_name}'] ||= (#{access_code})"
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
        attr_name = attr_name.to_s
        caster    = "cast_#{attr_name}"
        methods   = self.class.generated_attribute_methods

        if methods.respond_to?(caster)
          if @attributes.has_key?(attr_name)
            @attributes_cache[attr_name] || methods.send(caster, @attributes[attr_name])
          end
        else
          _read_attribute attr_name
        end
      end

      def _read_attribute(attr_name)
        attr_name = attr_name.to_s
        attr_name = self.class.primary_key if attr_name == 'id'

        unless @attributes[attr_name].nil?
          type_cast_attribute(column_for_attribute(attr_name), @attributes[attr_name])
        end
      end

      private
        def type_cast_attribute(column, value)
          if column
            column.type_cast(value)
          else
            value
          end
        end

        def attribute(attribute_name)
          read_attribute(attribute_name)
        end
    end
  end
end
