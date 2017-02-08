module ActiveRecord
  module AttributeMethods
    module Read
      extend ActiveSupport::Concern

      module ClassMethods
        protected

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
        # key the @attributes in read_attribute.
        def define_method_attribute(name)
          safe_name = name.unpack('h*'.freeze).first
          temp_method = "__temp__#{safe_name}"

          ActiveRecord::AttributeMethods::AttrNames.set_name_cache safe_name, name

          generated_attribute_methods.module_eval <<-STR, __FILE__, __LINE__ + 1
            def #{temp_method}
              name = ::ActiveRecord::AttributeMethods::AttrNames::ATTR_#{safe_name}
              _read_attribute(name) { |n| missing_attribute(n, caller) }
            end
          STR

          generated_attribute_methods.module_eval do
            alias_method name, temp_method
            undef_method temp_method
          end
        end
      end

      # Returns the value of the attribute identified by <tt>attr_name</tt> after
      # it has been typecast (for example, "2004-12-12" in a date column is cast
      # to a date object, like Date.new(2004, 12, 12)).
      def read_attribute(attr_name, &block)
        name = attr_name.to_s
        name = self.class.primary_key if name == "id".freeze && self.class.primary_key
        _read_attribute(name, &block)
      end

      # This method exists to avoid the expensive primary_key check internally, without
      # breaking compatibility with the read_attribute API
      if defined?(JRUBY_VERSION)
        # This form is significantly faster on JRuby, and this is one of our biggest hotspots.
        # https://github.com/jruby/jruby/pull/2562
        def _read_attribute(attr_name, &block) # :nodoc
          @attributes.fetch_value(attr_name.to_s, &block)
        end
      else
        def _read_attribute(attr_name) # :nodoc:
          @attributes.fetch_value(attr_name.to_s) { |n| yield n if block_given? }
        end
      end

      alias :attribute :_read_attribute
      private :attribute

    end
  end
end
