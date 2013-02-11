require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/class/inheritable_attributes'

module ActiveModel
  class MissingAttributeError < NoMethodError
  end
  # == Active Model Attribute Methods
  #
  # <tt>ActiveModel::AttributeMethods</tt> provides a way to add prefixes and suffixes
  # to your methods as well as handling the creation of Active Record like class methods
  # such as +table_name+.
  #
  # The requirements to implement ActiveModel::AttributeMethods are to:
  #
  # * <tt>include ActiveModel::AttributeMethods</tt> in your object
  # * Call each Attribute Method module method you want to add, such as
  #   attribute_method_suffix or attribute_method_prefix
  # * Call <tt>define_attribute_methods</tt> after the other methods are
  #   called.
  # * Define the various generic +_attribute+ methods that you have declared
  #
  # A minimal implementation could be:
  #
  #   class Person
  #     include ActiveModel::AttributeMethods
  #
  #     attribute_method_affix  :prefix => 'reset_', :suffix => '_to_default!'
  #     attribute_method_suffix '_contrived?'
  #     attribute_method_prefix 'clear_'
  #     define_attribute_methods ['name']
  #
  #     attr_accessor :name
  #
  #     private
  #
  #     def attribute_contrived?(attr)
  #       true
  #     end
  #
  #     def clear_attribute(attr)
  #       send("#{attr}=", nil)
  #     end
  #
  #     def reset_attribute_to_default!(attr)
  #       send("#{attr}=", "Default Name")
  #     end
  #   end
  #
  # Note that whenever you include ActiveModel::AttributeMethods in your class,
  # it requires you to implement an <tt>attributes</tt> method which returns a hash
  # with each attribute name in your model as hash key and the attribute value as
  # hash value.
  #
  # Hash keys must be strings.
  #
  module AttributeMethods
    extend ActiveSupport::Concern

    COMPILABLE_REGEXP = /^[a-zA-Z_]\w*[!?=]?$/

    module ClassMethods
      # Defines an "attribute" method (like +inheritance_column+ or +table_name+).
      # A new (class) method will be created with the given name. If a value is
      # specified, the new method will return that value (as a string).
      # Otherwise, the given block will be used to compute the value of the
      # method.
      #
      # The original method will be aliased, with the new name being prefixed
      # with "original_". This allows the new method to access the original
      # value.
      #
      # Example:
      #
      #   class Person
      #
      #     include ActiveModel::AttributeMethods
      #
      #     cattr_accessor :primary_key
      #     cattr_accessor :inheritance_column
      #
      #     define_attr_method :primary_key, "sysid"
      #     define_attr_method( :inheritance_column ) do
      #       original_inheritance_column + "_id"
      #     end
      #
      #   end
      #
      # Provides you with:
      #
      #   AttributePerson.primary_key
      #   # => "sysid"
      #   AttributePerson.inheritance_column = 'address'
      #   AttributePerson.inheritance_column
      #   # => 'address_id'
      def define_attr_method(name, value=nil, &block)
        sing = singleton_class
        sing.class_eval <<-eorb, __FILE__, __LINE__ + 1
          if method_defined?(:'original_#{name}')
            undef :'original_#{name}'
          end
          alias_method :'original_#{name}', :'#{name}'
        eorb
        if block_given?
          sing.send :define_method, name, &block
        else
          # If we can compile the method name, do it. Otherwise use define_method.
          # This is an important *optimization*, please don't change it. define_method
          # has slower dispatch and consumes more memory.
          if name =~ COMPILABLE_REGEXP
            sing.class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{name}; #{value.nil? ? 'nil' : value.to_s.inspect}; end
            RUBY
          else
            value = value.to_s if value
            sing.send(:define_method, name) { value }
          end
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
      # An instance method <tt>#{prefix}attribute</tt> must exist and accept
      # at least the +attr+ argument.
      #
      # For example:
      #
      #   class Person
      #
      #     include ActiveModel::AttributeMethods
      #     attr_accessor :name
      #     attribute_method_prefix 'clear_'
      #     define_attribute_methods [:name]
      #
      #     private
      #
      #     def clear_attribute(attr)
      #       send("#{attr}=", nil)
      #     end
      #   end
      #
      #   person = Person.new
      #   person.name = "Bob"
      #   person.name          # => "Bob"
      #   person.clear_name
      #   person.name          # => nil
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
      #   class Person
      #
      #     include ActiveModel::AttributeMethods
      #     attr_accessor :name
      #     attribute_method_suffix '_short?'
      #     define_attribute_methods [:name]
      #
      #     private
      #
      #     def attribute_short?(attr)
      #       send(attr).length < 5
      #     end
      #   end
      #
      #   person = Person.new
      #   person.name = "Bob"
      #   person.name          # => "Bob"
      #   person.name_short?   # => true
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
      #   class Person
      #
      #     include ActiveModel::AttributeMethods
      #     attr_accessor :name
      #     attribute_method_affix :prefix => 'reset_', :suffix => '_to_default!'
      #     define_attribute_methods [:name]
      #
      #     private
      #
      #     def reset_attribute_to_default!(attr)
      #       ...
      #     end
      #   end
      #
      #   person = Person.new
      #   person.name                         # => 'Gem'
      #   person.reset_name_to_default!
      #   person.name                         # => 'Gemma'
      def attribute_method_affix(*affixes)
        attribute_method_matchers.concat(affixes.map { |affix| AttributeMethodMatcher.new :prefix => affix[:prefix], :suffix => affix[:suffix] })
        undefine_attribute_methods
      end

      def alias_attribute(new_name, old_name)
        attribute_method_matchers.each do |matcher|
          matcher_new = matcher.method_name(new_name).to_s
          matcher_old = matcher.method_name(old_name).to_s

          if matcher_new =~ COMPILABLE_REGEXP && matcher_old =~ COMPILABLE_REGEXP
            module_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{matcher_new}(*args)
                send(:#{matcher_old}, *args)
              end
            RUBY
          else
            define_method(matcher_new) do |*args|
              send(matcher_old, *args)
            end
          end
        end
      end

      # Declares a the attributes that should be prefixed and suffixed by
      # ActiveModel::AttributeMethods.
      #
      # To use, pass in an array of attribute names (as strings or symbols),
      # be sure to declare +define_attribute_methods+ after you define any
      # prefix, suffix or affix methods, or they will not hook in.
      #
      #   class Person
      #
      #     include ActiveModel::AttributeMethods
      #     attr_accessor :name, :age, :address
      #     attribute_method_prefix 'clear_'
      #
      #     # Call to define_attribute_methods must appear after the
      #     # attribute_method_prefix, attribute_method_suffix or
      #     # attribute_method_affix declares.
      #     define_attribute_methods [:name, :age, :address]
      #
      #     private
      #
      #     def clear_attribute(attr)
      #       ...
      #     end
      #   end
      def define_attribute_methods(attr_names)
        return if attribute_methods_generated?
        attr_names.each do |attr_name|
          attribute_method_matchers.each do |matcher|
            unless instance_method_already_implemented?(matcher.method_name(attr_name))
              generate_method = "define_method_#{matcher.prefix}attribute#{matcher.suffix}"

              if respond_to?(generate_method)
                send(generate_method, attr_name)
              else
                method_name = matcher.method_name(attr_name)

                generated_attribute_methods.module_eval <<-RUBY, __FILE__, __LINE__ + 1
                  if method_defined?('#{method_name}')
                    undef :'#{method_name}'
                  end
                RUBY

                if method_name.to_s =~ COMPILABLE_REGEXP
                  generated_attribute_methods.module_eval <<-RUBY, __FILE__, __LINE__ + 1
                    def #{method_name}(*args)
                      send(:#{matcher.method_missing_target}, '#{attr_name}', *args)
                    end
                  RUBY
                else
                  generated_attribute_methods.module_eval <<-RUBY, __FILE__, __LINE__ + 1
                    define_method('#{method_name}') do |*args|
                      send('#{matcher.method_missing_target}', '#{attr_name}', *args)
                    end
                  RUBY
                end
              end
            end
          end
        end
        @attribute_methods_generated = true
      end

      # Removes all the previously dynamically defined methods from the class
      def undefine_attribute_methods
        generated_attribute_methods.module_eval do
          instance_methods.each { |m| undef_method(m) }
        end
        @attribute_methods_generated = nil
      end

      # Returns true if the attribute methods defined have been generated.
      def generated_attribute_methods #:nodoc:
        @generated_attribute_methods ||= begin
          mod = Module.new
          include mod
          mod
        end
      end

      # Returns true if the attribute methods defined have been generated.
      def attribute_methods_generated?
        @attribute_methods_generated ||= nil
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
            @regex = /\A(#{Regexp.escape(@prefix)})(.+?)(#{Regexp.escape(@suffix)})\z/
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
          read_inheritable_attribute(:attribute_method_matchers) || write_inheritable_attribute(:attribute_method_matchers, [])
        end
    end

    # Allows access to the object attributes, which are held in the
    # <tt>@attributes</tt> hash, as though they were first-class methods. So a
    # Person class with a name attribute can use Person#name and Person#name=
    # and never directly use the attributes hash -- except for multiple assigns
    # with ActiveRecord#attributes=. A Milestone class can also ask
    # Milestone#completed? to test that the completed attribute is not +nil+
    # or 0.
    #
    # It's also possible to instantiate related objects, so a Client class
    # belonging to the clients table with a +master_id+ foreign key can
    # instantiate master through Client#master.
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
        # but found among all methods. Which means that the given method is private.
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
