require 'active_support/core_ext/enumerable'

module ActiveRecord
  module AttributeMethods #:nodoc:
    extend ActiveSupport::Concern

    ATTRIBUTE_TYPES_CACHED_BY_DEFAULT = [:datetime, :timestamp, :time, :date]

    included do
      cattr_accessor :attribute_types_cached_by_default, :instance_writer => false
      self.attribute_types_cached_by_default = ATTRIBUTE_TYPES_CACHED_BY_DEFAULT
    end

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
        attribute_method_suffixes.concat suffixes
        rebuild_attribute_method_regexp
      end

      # Returns MatchData if method_name is an attribute method.
      def match_attribute_method?(method_name)
        rebuild_attribute_method_regexp unless defined?(@@attribute_method_regexp) && @@attribute_method_regexp
        @@attribute_method_regexp.match(method_name)
      end

      # Contains the names of the generated attribute methods.
      def generated_methods #:nodoc:
        @generated_methods ||= Set.new
      end

      def generated_methods?
        !generated_methods.empty?
      end

      # Generates all the attribute related methods for columns in the database
      # accessors, mutators and query methods.
      def define_attribute_methods
        return if generated_methods?
        columns_hash.keys.each do |name|
          attribute_method_suffixes.each do |suffix|
            method_name = "#{name}#{suffix}"
            unless instance_method_already_implemented?(method_name)
              generate_method = "define_attribute_method#{suffix}"
              if respond_to?(generate_method)
                send(generate_method, name)
              else
                evaluate_attribute_method(name, "def #{method_name}(*args); attribute#{suffix}('#{name}', *args); end", method_name)
              end
            end
          end
        end
      end

      def undefine_attribute_methods
        generated_methods.each { |name| undef_method(name) }
        @generated_methods = nil
      end

      # Checks whether the method is defined in the model or any of its subclasses
      # that also derive from Active Record.
      def instance_method_already_implemented?(method_name)
        method_name = method_name.to_s
        @_defined_class_methods ||= ancestors.first(ancestors.index(ActiveRecord::Base)).sum([]) { |m| m.public_instance_methods(false) | m.private_instance_methods(false) | m.protected_instance_methods(false) }.map(&:to_s).to_set
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

        # Evaluate the definition for an attribute related method
        def evaluate_attribute_method(attr_name, method_definition, method_name)
          generated_methods << method_name

          begin
            class_eval(method_definition, __FILE__, __LINE__)
          rescue SyntaxError => err
            generated_methods.delete(attr_name)
            if logger
              logger.warn "Exception occurred during reader method compilation."
              logger.warn "Maybe #{attr_name} is not a valid Ruby identifier?"
              logger.warn err.message
            end
          end
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
      if !self.class.generated_methods?
        self.class.define_attribute_methods
        guard_private_attribute_method!(method_name, args)
        if self.class.generated_methods.include?(method_name)
          return self.send(method_id, *args, &block)
        end
      end

      guard_private_attribute_method!(method_name, args)
      if self.class.primary_key.to_s == method_name
        id
      elsif md = self.class.match_attribute_method?(method_name)
        attribute_name, method_type = md.pre_match, md.to_s
        if @attributes.include?(attribute_name)
          __send__("attribute#{method_type}", attribute_name, *args, &block)
        else
          super
        end
      else
        super
      end
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
      elsif !self.class.generated_methods?
        self.class.define_attribute_methods
        if self.class.generated_methods.include?(method_name)
          return true
        end
      end

      if md = self.class.match_attribute_method?(method_name)
        return true if @attributes.include?(md.pre_match)
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
