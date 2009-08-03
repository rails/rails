require 'active_support/core_ext/enumerable'

module ActiveRecord
  module AttributeMethods #:nodoc:
    extend ActiveSupport::Concern

    # Declare and check for suffixed attribute methods.
    module ClassMethods
      # Declares a method available for all attributes with the given suffix.
      # Uses +method_missing+ and <tt>respond_to?</tt> to rewrite the method
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
      #     attribute_method_suffix '_changed?'
      #
      #     private
      #       def attribute_changed?(attr)
      #         ...
      #       end
      #   end
      #
      #   person = Person.find(1)
      #   person.name_changed?    # => false
      #   person.name = 'Hubert'
      #   person.name_changed?    # => true
      def attribute_method_suffix(*suffixes)
        attribute_method_suffixes.concat(suffixes)
        rebuild_attribute_method_regexp
        undefine_attribute_methods
      end

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

      # Returns MatchData if method_name is an attribute method.
      def match_attribute_method?(method_name)
        rebuild_attribute_method_regexp unless defined?(@@attribute_method_regexp) && @@attribute_method_regexp
        @@attribute_method_regexp.match(method_name)
      end

      def generated_methods #:nodoc:
        @generated_methods ||= begin
          mod = Module.new
          include mod
          mod
        end
      end

      # Generates all the attribute related methods for columns in the database
      # accessors, mutators and query methods.
      def define_attribute_methods
        return unless generated_methods.instance_methods.empty?
        columns_hash.keys.each do |name|
          attribute_method_suffixes.each do |suffix|
            method_name = "#{name}#{suffix}"
            unless instance_method_already_implemented?(method_name)
              generate_method = "define_attribute_method#{suffix}"
              if respond_to?(generate_method)
                send(generate_method, name)
              else
                generated_methods.module_eval("def #{method_name}(*args); send(:attribute#{suffix}, '#{name}', *args); end", __FILE__, __LINE__)
              end
            end
          end
        end
      end

      def undefine_attribute_methods
        generated_methods.module_eval do
          instance_methods.each { |m| undef_method(m) }
        end
      end

      # Checks whether the method is defined in the model or any of its subclasses
      # that also derive from Active Record. Raises DangerousAttributeError if the
      # method is defined by Active Record though.
      def instance_method_already_implemented?(method_name)
        method_name = method_name.to_s
        @_defined_class_methods         ||= ancestors.first(ancestors.index(ActiveRecord::Base)).sum([]) { |m| m.public_instance_methods(false) | m.private_instance_methods(false) | m.protected_instance_methods(false) }.map {|m| m.to_s }.to_set
        @@_defined_activerecord_methods ||= (ActiveRecord::Base.public_instance_methods(false) | ActiveRecord::Base.private_instance_methods(false) | ActiveRecord::Base.protected_instance_methods(false)).map{|m| m.to_s }.to_set
        raise DangerousAttributeError, "#{method_name} is defined by ActiveRecord" if @@_defined_activerecord_methods.include?(method_name)
        @_defined_class_methods.include?(method_name)
      end

      private
        # Suffixes a, ?, c become regexp /(a|\?|c)$/
        def rebuild_attribute_method_regexp
          suffixes = attribute_method_suffixes.map { |s| Regexp.escape(s) }
          @@attribute_method_regexp = /(#{suffixes.join('|')})$/.freeze
        end

        def attribute_method_suffixes
          @@attribute_method_suffixes ||= []
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

      # If we haven't generated any methods yet, generate them, then
      # see if we've created the method we're looking for.
      if self.class.generated_methods.instance_methods.empty?
        self.class.define_attribute_methods
        guard_private_attribute_method!(method_name, args)
        if self.class.generated_methods.instance_methods.include?(method_name)
          return self.send(method_id, *args, &block)
        end
      end

      if md = self.class.match_attribute_method?(method_name)
        attribute_name, method_type = md.pre_match, md.to_s
        if attribute_name == 'id' || @attributes.include?(attribute_name)
          guard_private_attribute_method!(method_name, args)
          return __send__("attribute#{method_type}", attribute_name, *args, &block)
        end
      end
      super
    end

    # A Person object with a name attribute can ask <tt>person.respond_to?(:name)</tt>,
    # <tt>person.respond_to?(:name=)</tt>, and <tt>person.respond_to?(:name?)</tt>
    # which will all return +true+.
    alias :respond_to_without_attributes? :respond_to?
    def respond_to?(method, include_private_methods = false)
      method_name = method.to_s
      if super
        return true
      elsif !include_private_methods && super(method, true)
        # If we're here than we haven't found among non-private methods
        # but found among all methods. Which means that given method is private.
        return false
      elsif self.class.generated_methods.instance_methods.empty?
        self.class.define_attribute_methods
        if self.class.generated_methods.instance_methods.include?(method_name)
          return true
        end
      end

      if md = self.class.match_attribute_method?(method_name)
        return true if md.pre_match == 'id' || @attributes.include?(md.pre_match)
      end
      super
    end

    private
      # prevent method_missing from calling private methods with #send
      def guard_private_attribute_method!(method_name, args)
        if self.class.private_method_defined?(method_name)
          raise NoMethodError.new("Attempt to call private method", method_name, args)
        end
      end

      def missing_attribute(attr_name, stack)
        raise ActiveRecord::MissingAttributeError, "missing attribute: #{attr_name}", stack
      end
  end
end
