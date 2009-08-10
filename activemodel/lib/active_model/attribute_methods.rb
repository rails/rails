module ActiveModel
  class MissingAttributeError < NoMethodError
  end

  module AttributeMethods
    extend ActiveSupport::Concern

    # Declare and check for suffixed attribute methods.
    module ClassMethods
      # Defines an "attribute" method (like +inheritance_column+ or
      # +table_name+). A new (class) method will be created with the
      # given name. If a value is specified, the new method will
      # return that value (as a string). Otherwise, the given block
      # will be used to compute the value of the method.
      #
      # The original method will be aliased, with the new name being
      # prefixed with "original_". This allows the new method to
      # access the original value.
      #
      # Example:
      #
      #   class A < ActiveRecord::Base
      #     define_attr_method :primary_key, "sysid"
      #     define_attr_method( :inheritance_column ) do
      #       original_inheritance_column + "_id"
      #     end
      #   end
      def define_attr_method(name, value=nil, &block)
        sing = metaclass
        sing.send :alias_method, "original_#{name}", name
        if block_given?
          sing.send :define_method, name, &block
        else
          # use eval instead of a block to work around a memory leak in dev
          # mode in fcgi
          sing.class_eval "def #{name}; #{value.to_s.inspect}; end"
        end
      end

      # Declares a method available for all attributes with the given prefix.
      # Uses +method_missing+ and <tt>respond_to?</tt> to rewrite the method.
      #
      #   #{prefix}#{attr}(*args, &block)
      #
      # to
      #
      #   #{prefix}attribute(#{attr}, *args, &block)
      #
      # An <tt>#{prefix}attribute</tt> instance method must exist and accept at least
      # the +attr+ argument.
      #
      # For example:
      #
      #   class Person < ActiveRecord::Base
      #     attribute_method_prefix 'clear_'
      #
      #     private
      #       def clear_attribute(attr)
      #         ...
      #       end
      #   end
      #
      #   person = Person.find(1)
      #   person.name          # => 'Gem'
      #   person.clear_name
      #   person.name          # => ''
      def attribute_method_prefix(*prefixes)
        attribute_method_matchers.concat(prefixes.map { |prefix| AttributeMethodMatcher.new :prefix => prefix })
        undefine_attribute_methods
      end

      # Declares a method available for all attributes with the given suffix.
      # Uses +method_missing+ and <tt>respond_to?</tt> to rewrite the method.
      #
      #   #{attr}#{suffix}(*args, &block)
      #
      # to
      #
      #   attribute#{suffix}(#{attr}, *args, &block)
      #
      # An <tt>attribute#{suffix}</tt> instance method must exist and accept at least
      # the +attr+ argument.
      #
      # For example:
      #
      #   class Person < ActiveRecord::Base
      #     attribute_method_suffix '_short?'
      #
      #     private
      #       def attribute_short?(attr)
      #         ...
      #       end
      #   end
      #
      #   person = Person.find(1)
      #   person.name           # => 'Gem'
      #   person.name_short?    # => true
      def attribute_method_suffix(*suffixes)
        attribute_method_matchers.concat(suffixes.map { |suffix| AttributeMethodMatcher.new :suffix => suffix })
        undefine_attribute_methods
      end

      # Declares a method available for all attributes with the given prefix
      # and suffix. Uses +method_missing+ and <tt>respond_to?</tt> to rewrite
      # the method.
      #
      #   #{prefix}#{attr}#{suffix}(*args, &block)
      #
      # to
      #
      #   #{prefix}attribute#{suffix}(#{attr}, *args, &block)
      #
      # An <tt>#{prefix}attribute#{suffix}</tt> instance method must exist and
      # accept at least the +attr+ argument.
      #
      # For example:
      #
      #   class Person < ActiveRecord::Base
      #     attribute_method_affix :prefix => 'reset_', :suffix => '_to_default!'
      #
      #     private
      #       def reset_attribute_to_default!(attr)
      #         ...
      #       end
      #   end
      #
      #   person = Person.find(1)
      #   person.name                         # => 'Gem'
      #   person.reset_name_to_default!
      #   person.name                         # => 'Gemma'
      def attribute_method_affix(*affixes)
        attribute_method_matchers.concat(affixes.map { |affix| AttributeMethodMatcher.new :prefix => affix[:prefix], :suffix => affix[:suffix] })
        undefine_attribute_methods
      end

      def alias_attribute(new_name, old_name)
        attribute_method_matchers.each do |matcher|
          module_eval <<-STR, __FILE__, __LINE__+1
            def #{matcher.method_name(new_name)}(*args)
              send(:#{matcher.method_name(old_name)}, *args)
            end
          STR
        end
      end

      def define_attribute_methods(attr_names)
        return if attribute_methods_generated?
        attr_names.each do |attr_name|
          attribute_method_matchers.each do |matcher|
            unless instance_method_already_implemented?(matcher.method_name(attr_name))
              generate_method = "define_method_#{matcher.prefix}attribute#{matcher.suffix}"

              if respond_to?(generate_method)
                send(generate_method, attr_name)
              else
                generated_attribute_methods.module_eval <<-STR, __FILE__, __LINE__+1
                  def #{matcher.method_name(attr_name)}(*args)
                    send(:#{matcher.method_missing_target}, '#{attr_name}', *args)
                  end
                STR
              end
            end
          end
        end
      end

      def undefine_attribute_methods
        generated_attribute_methods.module_eval do
          instance_methods.each { |m| undef_method(m) }
        end
        @attribute_methods_generated = nil
      end

      def generated_attribute_methods #:nodoc:
        @generated_attribute_methods ||= begin
          @attribute_methods_generated = true
          mod = Module.new
          include mod
          mod
        end
      end

      def attribute_methods_generated?
        @attribute_methods_generated ? true : false
      end

      protected
        def instance_method_already_implemented?(method_name)
          method_defined?(method_name)
        end

      private
        class AttributeMethodMatcher
          attr_reader :prefix, :suffix

          AttributeMethodMatch = Struct.new(:target, :attr_name)

          def initialize(options = {})
            options.symbolize_keys!
            @prefix, @suffix = options[:prefix] || '', options[:suffix] || ''
            @regex = /^(#{Regexp.escape(@prefix)})(.+?)(#{Regexp.escape(@suffix)})$/
          end

          def match(method_name)
            if matchdata = @regex.match(method_name)
              AttributeMethodMatch.new(method_missing_target, matchdata[2])
            else
              nil
            end
          end

          def method_name(attr_name)
            "#{prefix}#{attr_name}#{suffix}"
          end

          def method_missing_target
            :"#{prefix}attribute#{suffix}"
          end
        end

        def attribute_method_matchers #:nodoc:
          @@attribute_method_matchers ||= []
        end
    end

    # Allows access to the object attributes, which are held in the <tt>@attributes</tt> hash, as though they
    # were first-class methods. So a Person class with a name attribute can use Person#name and
    # Person#name= and never directly use the attributes hash -- except for multiple assigns with
    # ActiveRecord#attributes=. A Milestone class can also ask Milestone#completed? to test that
    # the completed attribute is not +nil+ or 0.
    #
    # It's also possible to instantiate related objects, so a Client class belonging to the clients
    # table with a +master_id+ foreign key can instantiate master through Client#master.
    def method_missing(method_id, *args, &block)
      method_name = method_id.to_s
      if match = match_attribute_method?(method_name)
        guard_private_attribute_method!(method_name, args)
        return __send__(match.target, match.attr_name, *args, &block)
      end
      super
    end

    # A Person object with a name attribute can ask <tt>person.respond_to?(:name)</tt>,
    # <tt>person.respond_to?(:name=)</tt>, and <tt>person.respond_to?(:name?)</tt>
    # which will all return +true+.
    alias :respond_to_without_attributes? :respond_to?
    def respond_to?(method, include_private_methods = false)
      if super
        return true
      elsif !include_private_methods && super(method, true)
        # If we're here then we haven't found among non-private methods
        # but found among all methods. Which means that given method is private.
        return false
      elsif match_attribute_method?(method.to_s)
        return true
      end
      super
    end

    protected
      def attribute_method?(attr_name)
        attributes.include?(attr_name)
      end

    private
      # Returns a struct representing the matching attribute method.
      # The struct's attributes are prefix, base and suffix.
      def match_attribute_method?(method_name)
        self.class.send(:attribute_method_matchers).each do |method|
          if (match = method.match(method_name)) && attribute_method?(match.attr_name)
            return match
          end
        end
        nil
      end

      # prevent method_missing from calling private methods with #send
      def guard_private_attribute_method!(method_name, args)
        if self.class.private_method_defined?(method_name)
          raise NoMethodError.new("Attempt to call private method", method_name, args)
        end
      end

      def missing_attribute(attr_name, stack)
        raise ActiveModel::MissingAttributeError, "missing attribute: #{attr_name}", stack
      end
  end
end
