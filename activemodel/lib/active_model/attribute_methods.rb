# frozen_string_literal: true

require "concurrent/map"

module ActiveModel
  # Raised when an attribute is not defined.
  #
  #   class User < ActiveRecord::Base
  #     has_many :pets
  #   end
  #
  #   user = User.first
  #   user.pets.select(:id).first.user_id
  #   # => ActiveModel::MissingAttributeError: missing attribute 'user_id' for Pet
  class MissingAttributeError < NoMethodError
  end

  # = Active \Model \Attribute \Methods
  #
  # Provides a way to add prefixes and suffixes to your methods as
  # well as handling the creation of ActiveRecord::Base - like
  # class methods such as +table_name+.
  #
  # The requirements to implement +ActiveModel::AttributeMethods+ are to:
  #
  # * <tt>include ActiveModel::AttributeMethods</tt> in your class.
  # * Call each of its methods you want to add, such as +attribute_method_suffix+
  #   or +attribute_method_prefix+.
  # * Call +define_attribute_methods+ after the other methods are called.
  # * Define the various generic +_attribute+ methods that you have declared.
  # * Define an +attributes+ method which returns a hash with each
  #   attribute name in your model as hash key and the attribute value as hash value.
  #   Hash keys must be strings.
  #
  # A minimal implementation could be:
  #
  #   class Person
  #     include ActiveModel::AttributeMethods
  #
  #     attribute_method_affix  prefix: 'reset_', suffix: '_to_default!'
  #     attribute_method_suffix '_contrived?'
  #     attribute_method_prefix 'clear_'
  #     define_attribute_methods :name
  #
  #     attr_accessor :name
  #
  #     def attributes
  #       { 'name' => @name }
  #     end
  #
  #     private
  #       def attribute_contrived?(attr)
  #         true
  #       end
  #
  #       def clear_attribute(attr)
  #         send("#{attr}=", nil)
  #       end
  #
  #       def reset_attribute_to_default!(attr)
  #         send("#{attr}=", 'Default Name')
  #       end
  #   end
  module AttributeMethods
    extend ActiveSupport::Concern

    NAME_COMPILABLE_REGEXP = /\A[a-zA-Z_]\w*[!?=]?\z/
    CALL_COMPILABLE_REGEXP = /\A[a-zA-Z_]\w*[!?]?\z/

    included do
      class_attribute :attribute_aliases, instance_writer: false, default: {}
      class_attribute :attribute_method_patterns, instance_writer: false, default: [ ClassMethods::AttributeMethodPattern.new ]
    end

    module ClassMethods
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
      #   class Person
      #     include ActiveModel::AttributeMethods
      #
      #     attr_accessor :name
      #     attribute_method_prefix 'clear_'
      #     define_attribute_methods :name
      #
      #     private
      #       def clear_attribute(attr)
      #         send("#{attr}=", nil)
      #       end
      #   end
      #
      #   person = Person.new
      #   person.name = 'Bob'
      #   person.name          # => "Bob"
      #   person.clear_name
      #   person.name          # => nil
      def attribute_method_prefix(*prefixes, parameters: nil)
        self.attribute_method_patterns += prefixes.map! { |prefix| AttributeMethodPattern.new(prefix: prefix, parameters: parameters) }
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
      # An <tt>attribute#{suffix}</tt> instance method must exist and accept at
      # least the +attr+ argument.
      #
      #   class Person
      #     include ActiveModel::AttributeMethods
      #
      #     attr_accessor :name
      #     attribute_method_suffix '_short?'
      #     define_attribute_methods :name
      #
      #     private
      #       def attribute_short?(attr)
      #         send(attr).length < 5
      #       end
      #   end
      #
      #   person = Person.new
      #   person.name = 'Bob'
      #   person.name          # => "Bob"
      #   person.name_short?   # => true
      def attribute_method_suffix(*suffixes, parameters: nil)
        self.attribute_method_patterns += suffixes.map! { |suffix| AttributeMethodPattern.new(suffix: suffix, parameters: parameters) }
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
      #   class Person
      #     include ActiveModel::AttributeMethods
      #
      #     attr_accessor :name
      #     attribute_method_affix prefix: 'reset_', suffix: '_to_default!'
      #     define_attribute_methods :name
      #
      #     private
      #       def reset_attribute_to_default!(attr)
      #         send("#{attr}=", 'Default Name')
      #       end
      #   end
      #
      #   person = Person.new
      #   person.name                         # => 'Gem'
      #   person.reset_name_to_default!
      #   person.name                         # => 'Default Name'
      def attribute_method_affix(*affixes)
        self.attribute_method_patterns += affixes.map! { |affix| AttributeMethodPattern.new(**affix) }
        undefine_attribute_methods
      end

      # Allows you to make aliases for attributes.
      #
      #   class Person
      #     include ActiveModel::AttributeMethods
      #
      #     attr_accessor :name
      #     attribute_method_suffix '_short?'
      #     define_attribute_methods :name
      #
      #     alias_attribute :nickname, :name
      #
      #     private
      #       def attribute_short?(attr)
      #         send(attr).length < 5
      #       end
      #   end
      #
      #   person = Person.new
      #   person.name = 'Bob'
      #   person.name            # => "Bob"
      #   person.nickname        # => "Bob"
      #   person.name_short?     # => true
      #   person.nickname_short? # => true
      def alias_attribute(new_name, old_name)
        old_name = old_name.to_s
        new_name = new_name.to_s
        self.attribute_aliases = attribute_aliases.merge(new_name => old_name)
        aliases_by_attribute_name[old_name] << new_name
        eagerly_generate_alias_attribute_methods(new_name, old_name)
      end

      def eagerly_generate_alias_attribute_methods(new_name, old_name) # :nodoc:
        ActiveSupport::CodeGenerator.batch(generated_attribute_methods, __FILE__, __LINE__) do |code_generator|
          generate_alias_attribute_methods(code_generator, new_name, old_name)
        end
      end

      def generate_alias_attribute_methods(code_generator, new_name, old_name) # :nodoc:
        ActiveSupport::CodeGenerator.batch(code_generator, __FILE__, __LINE__) do |owner|
          attribute_method_patterns.each do |pattern|
            alias_attribute_method_definition(code_generator, pattern, new_name, old_name)
          end
          attribute_method_patterns_cache.clear
        end
      end

      def alias_attribute_method_definition(code_generator, pattern, new_name, old_name) # :nodoc:
        method_name = pattern.method_name(new_name).to_s
        target_name = pattern.method_name(old_name).to_s
        parameters = pattern.parameters

        mangled_name = build_mangled_name(target_name)

        call_args = []
        call_args << parameters if parameters

        define_call(code_generator, method_name, target_name, mangled_name, parameters, call_args, namespace: :alias_attribute, as: method_name)
      end

      # Is +new_name+ an alias?
      def attribute_alias?(new_name)
        attribute_aliases.key? new_name.to_s
      end

      # Returns the original name for the alias +name+
      def attribute_alias(name)
        attribute_aliases[name.to_s]
      end

      # Declares the attributes that should be prefixed and suffixed by
      # +ActiveModel::AttributeMethods+.
      #
      # To use, pass attribute names (as strings or symbols). Be sure to declare
      # +define_attribute_methods+ after you define any prefix, suffix, or affix
      # methods, or they will not hook in.
      #
      #   class Person
      #     include ActiveModel::AttributeMethods
      #
      #     attr_accessor :name, :age, :address
      #     attribute_method_prefix 'clear_'
      #
      #     # Call to define_attribute_methods must appear after the
      #     # attribute_method_prefix, attribute_method_suffix or
      #     # attribute_method_affix declarations.
      #     define_attribute_methods :name, :age, :address
      #
      #     private
      #       def clear_attribute(attr)
      #         send("#{attr}=", nil)
      #       end
      #   end
      def define_attribute_methods(*attr_names)
        ActiveSupport::CodeGenerator.batch(generated_attribute_methods, __FILE__, __LINE__) do |owner|
          attr_names.flatten.each do |attr_name|
            define_attribute_method(attr_name, _owner: owner)
            aliases_by_attribute_name[attr_name.to_s].each do |aliased_name|
              generate_alias_attribute_methods owner, aliased_name, attr_name
            end
          end
        end
      end

      # Declares an attribute that should be prefixed and suffixed by
      # +ActiveModel::AttributeMethods+.
      #
      # To use, pass an attribute name (as string or symbol). Be sure to declare
      # +define_attribute_method+ after you define any prefix, suffix or affix
      # method, or they will not hook in.
      #
      #   class Person
      #     include ActiveModel::AttributeMethods
      #
      #     attr_accessor :name
      #     attribute_method_suffix '_short?'
      #
      #     # Call to define_attribute_method must appear after the
      #     # attribute_method_prefix, attribute_method_suffix or
      #     # attribute_method_affix declarations.
      #     define_attribute_method :name
      #
      #     private
      #       def attribute_short?(attr)
      #         send(attr).length < 5
      #       end
      #   end
      #
      #   person = Person.new
      #   person.name = 'Bob'
      #   person.name        # => "Bob"
      #   person.name_short? # => true
      def define_attribute_method(attr_name, _owner: generated_attribute_methods, as: attr_name)
        ActiveSupport::CodeGenerator.batch(_owner, __FILE__, __LINE__) do |owner|
          attribute_method_patterns.each do |pattern|
            define_attribute_method_pattern(pattern, attr_name, owner: owner, as: as)
          end
          attribute_method_patterns_cache.clear
        end
      end

      def define_attribute_method_pattern(pattern, attr_name, owner:, as:, override: false) # :nodoc:
        canonical_method_name = pattern.method_name(attr_name)
        public_method_name = pattern.method_name(as)

        # If defining a regular attribute method, we don't override methods that are explicitly
        # defined in parent classes.
        if instance_method_already_implemented?(public_method_name)
          # However, for `alias_attribute`, we always define the method.
          # We check for override second because `instance_method_already_implemented?`
          # also check for dangerous methods.
          return unless override
        end

        generate_method = "define_method_#{pattern.proxy_target}"

        if respond_to?(generate_method, true)
          send(generate_method, attr_name.to_s, owner: owner, as: as)
        else
          define_proxy_call(
            owner,
            canonical_method_name,
            pattern.proxy_target,
            pattern.parameters,
            attr_name.to_s,
            namespace: :active_model_proxy,
            as: public_method_name
          )
        end
      end

      # Removes all the previously dynamically defined methods from the class, including alias attribute methods.
      #
      #   class Person
      #     include ActiveModel::AttributeMethods
      #
      #     attr_accessor :name
      #     attribute_method_suffix '_short?'
      #     define_attribute_method :name
      #     alias_attribute :first_name, :name
      #
      #     private
      #       def attribute_short?(attr)
      #         send(attr).length < 5
      #       end
      #   end
      #
      #   person = Person.new
      #   person.name = 'Bob'
      #   person.first_name  # => "Bob"
      #   person.name_short? # => true
      #
      #   Person.undefine_attribute_methods
      #
      #   person.name_short? # => NoMethodError
      #   person.first_name  # => NoMethodError
      def undefine_attribute_methods
        generated_attribute_methods.module_eval do
          undef_method(*instance_methods)
        end
        attribute_method_patterns_cache.clear
      end

      def aliases_by_attribute_name # :nodoc:
        @aliases_by_attribute_name ||= Hash.new { |h, k| h[k] = [] }
      end

      private
        def inherited(base) # :nodoc:
          super
          base.class_eval do
            @attribute_method_patterns_cache = nil
            @aliases_by_attribute_name = nil
            @generated_attribute_methods = nil
          end
        end

        def resolve_attribute_name(name)
          attribute_aliases.fetch(super, &:itself)
        end

        def generated_attribute_methods
          @generated_attribute_methods ||= Module.new.tap { |mod| include mod }
        end

        def instance_method_already_implemented?(method_name)
          generated_attribute_methods.method_defined?(method_name)
        end

        # The methods +method_missing+ and +respond_to?+ of this module are
        # invoked often in a typical rails, both of which invoke the method
        # +matched_attribute_method+. The latter method iterates through an
        # array doing regular expression matches, which results in a lot of
        # object creations. Most of the time it returns a +nil+ match. As the
        # match result is always the same given a +method_name+, this cache is
        # used to alleviate the GC, which ultimately also speeds up the app
        # significantly (in our case our test suite finishes 10% faster with
        # this cache).
        def attribute_method_patterns_cache
          @attribute_method_patterns_cache ||= Concurrent::Map.new(initial_capacity: 4)
        end

        def attribute_method_patterns_matching(method_name)
          attribute_method_patterns_cache.compute_if_absent(method_name) do
            attribute_method_patterns.filter_map { |pattern| pattern.match(method_name) }
          end
        end

        # Define a method `name` in `mod` that dispatches to `send`
        # using the given `extra` args. This falls back on `send`
        # if the called name cannot be compiled.
        def define_proxy_call(code_generator, name, proxy_target, parameters, *call_args, namespace:, as: name)
          mangled_name = build_mangled_name(name)

          call_args.map!(&:inspect)
          call_args << parameters if parameters

          # We have to use a different namespace for every target method, because
          # if someone defines an attribute that look like an attribute method we could clash, e.g.
          #   attribute :title_was
          #   attribute :title
          namespace = :"#{namespace}_#{proxy_target}"

          define_call(code_generator, name, proxy_target, mangled_name, parameters, call_args, namespace: namespace, as: as)
        end

        def build_mangled_name(name)
          mangled_name = name

          unless NAME_COMPILABLE_REGEXP.match?(name)
            mangled_name = :"__temp__#{name.unpack1("h*")}"
          end

          mangled_name
        end

        def define_call(code_generator, name, target_name, mangled_name, parameters, call_args, namespace:, as:)
          code_generator.define_cached_method(mangled_name, as: as, namespace: namespace) do |batch|
            body = if CALL_COMPILABLE_REGEXP.match?(target_name)
              "self.#{target_name}(#{call_args.join(", ")})"
            else
              call_args.unshift(":'#{target_name}'")
              "send(#{call_args.join(", ")})"
            end

            batch <<
              "def #{mangled_name}(#{parameters || ''})" <<
              body <<
              "end"
          end
        end

        class AttributeMethodPattern # :nodoc:
          attr_reader :prefix, :suffix, :proxy_target, :parameters

          AttributeMethod = Struct.new(:proxy_target, :attr_name)

          def initialize(prefix: "", suffix: "", parameters: nil)
            @prefix = prefix
            @suffix = suffix
            @parameters = parameters.nil? ? "..." : parameters
            @regex = /\A(?:#{Regexp.escape(@prefix)})(.*)(?:#{Regexp.escape(@suffix)})\z/
            @proxy_target = "#{@prefix}attribute#{@suffix}"
            @method_name = "#{prefix}%s#{suffix}"
          end

          def match(method_name)
            if @regex =~ method_name
              AttributeMethod.new(proxy_target, $1)
            end
          end

          def method_name(attr_name)
            @method_name % attr_name
          end
        end
    end

    # Allows access to the object attributes, which are held in the hash
    # returned by <tt>attributes</tt>, as though they were first-class
    # methods. So a +Person+ class with a +name+ attribute can for example use
    # <tt>Person#name</tt> and <tt>Person#name=</tt> and never directly use
    # the attributes hash -- except for multiple assignments with
    # <tt>ActiveRecord::Base#attributes=</tt>.
    #
    # It's also possible to instantiate related objects, so a <tt>Client</tt>
    # class belonging to the +clients+ table with a +master_id+ foreign key
    # can instantiate master through <tt>Client#master</tt>.
    def method_missing(method, ...)
      if respond_to_without_attributes?(method, true)
        super
      else
        match = matched_attribute_method(method.name)
        match ? attribute_missing(match, ...) : super
      end
    end

    # +attribute_missing+ is like +method_missing+, but for attributes. When
    # +method_missing+ is called we check to see if there is a matching
    # attribute method. If so, we tell +attribute_missing+ to dispatch the
    # attribute. This method can be overloaded to customize the behavior.
    def attribute_missing(match, ...)
      __send__(match.proxy_target, match.attr_name, ...)
    end

    # A +Person+ instance with a +name+ attribute can ask
    # <tt>person.respond_to?(:name)</tt>, <tt>person.respond_to?(:name=)</tt>,
    # and <tt>person.respond_to?(:name?)</tt> which will all return +true+.
    alias :respond_to_without_attributes? :respond_to?
    def respond_to?(method, include_private_methods = false)
      if super
        true
      elsif !include_private_methods && super(method, true)
        # If we're here then we haven't found among non-private methods
        # but found among all methods. Which means that the given method is private.
        false
      else
        !matched_attribute_method(method.to_s).nil?
      end
    end

    private
      def attribute_method?(attr_name)
        respond_to_without_attributes?(:attributes) && attributes.include?(attr_name)
      end

      # Returns a struct representing the matching attribute method.
      # The struct's attributes are prefix, base and suffix.
      def matched_attribute_method(method_name)
        matches = self.class.send(:attribute_method_patterns_matching, method_name)
        matches.detect { |match| attribute_method?(match.attr_name) }
      end

      def missing_attribute(attr_name, stack)
        raise ActiveModel::MissingAttributeError, "missing attribute '#{attr_name}' for #{self.class}", stack
      end

      def _read_attribute(attr)
        __send__(attr)
      end

      module AttrNames # :nodoc:
        DEF_SAFE_NAME = /\A[a-zA-Z_]\w*\z/

        # We want to generate the methods via module_eval rather than
        # define_method, because define_method is slower on dispatch.
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
        def self.define_attribute_accessor_method(owner, attr_name, writer: false)
          method_name = "#{attr_name}#{'=' if writer}"
          if attr_name.ascii_only? && DEF_SAFE_NAME.match?(attr_name)
            yield method_name, "'#{attr_name}'"
          else
            safe_name = attr_name.unpack1("h*")
            const_name = "ATTR_#{safe_name}"
            const_set(const_name, attr_name) unless const_defined?(const_name)
            temp_method_name = "__temp__#{safe_name}#{'=' if writer}"
            attr_name_expr = "::ActiveModel::AttributeMethods::AttrNames::#{const_name}"
            yield temp_method_name, attr_name_expr
          end
        end
      end
  end
end
