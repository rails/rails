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
  #   # => ActiveModel::MissingAttributeError: missing attribute: user_id
  class MissingAttributeError < NoMethodError
  end

  # == Active \Model \Attribute \Methods
  #
  # Provides a way to add prefixes and suffixes to your methods as
  # well as handling the creation of <tt>ActiveRecord::Base</tt>-like
  # class methods such as +table_name+.
  #
  # The requirements to implement <tt>ActiveModel::AttributeMethods</tt> are to:
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
  #       send("#{attr}=", 'Default Name')
  #     end
  #   end
  module AttributeMethods
    extend ActiveSupport::Concern

    NAME_COMPILABLE_REGEXP = /\A[a-zA-Z_]\w*[!?=]?\z/
    CALL_COMPILABLE_REGEXP = /\A[a-zA-Z_]\w*[!?]?\z/

    included do
      class_attribute :attribute_aliases, instance_writer: false, default: {}
      class_attribute :attribute_method_matchers, instance_writer: false, default: [ ClassMethods::AttributeMethodMatcher.new ]
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
      #
      #     def clear_attribute(attr)
      #       send("#{attr}=", nil)
      #     end
      #   end
      #
      #   person = Person.new
      #   person.name = 'Bob'
      #   person.name          # => "Bob"
      #   person.clear_name
      #   person.name          # => nil
      def attribute_method_prefix(*prefixes)
        self.attribute_method_matchers += prefixes.map! { |prefix| AttributeMethodMatcher.new prefix: prefix }
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
      #
      #     def attribute_short?(attr)
      #       send(attr).length < 5
      #     end
      #   end
      #
      #   person = Person.new
      #   person.name = 'Bob'
      #   person.name          # => "Bob"
      #   person.name_short?   # => true
      def attribute_method_suffix(*suffixes)
        self.attribute_method_matchers += suffixes.map! { |suffix| AttributeMethodMatcher.new suffix: suffix }
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
      #
      #     def reset_attribute_to_default!(attr)
      #       send("#{attr}=", 'Default Name')
      #     end
      #   end
      #
      #   person = Person.new
      #   person.name                         # => 'Gem'
      #   person.reset_name_to_default!
      #   person.name                         # => 'Default Name'
      def attribute_method_affix(*affixes)
        self.attribute_method_matchers += affixes.map! { |affix| AttributeMethodMatcher.new prefix: affix[:prefix], suffix: affix[:suffix] }
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
      #
      #     def attribute_short?(attr)
      #       send(attr).length < 5
      #     end
      #   end
      #
      #   person = Person.new
      #   person.name = 'Bob'
      #   person.name            # => "Bob"
      #   person.nickname        # => "Bob"
      #   person.name_short?     # => true
      #   person.nickname_short? # => true
      def alias_attribute(new_name, old_name)
        self.attribute_aliases = attribute_aliases.merge(new_name.to_s => old_name.to_s)
        CodeGenerator.batch(self, __FILE__, __LINE__) do |owner|
          attribute_method_matchers.each do |matcher|
            matcher_new = matcher.method_name(new_name).to_s
            matcher_old = matcher.method_name(old_name).to_s
            define_proxy_call owner, matcher_new, matcher_old
          end
        end
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
      # <tt>ActiveModel::AttributeMethods</tt>.
      #
      # To use, pass attribute names (as strings or symbols). Be sure to declare
      # +define_attribute_methods+ after you define any prefix, suffix or affix
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
      #
      #     def clear_attribute(attr)
      #       send("#{attr}=", nil)
      #     end
      #   end
      def define_attribute_methods(*attr_names)
        CodeGenerator.batch(generated_attribute_methods, __FILE__, __LINE__) do |owner|
          attr_names.flatten.each { |attr_name| define_attribute_method(attr_name, _owner: owner) }
        end
      end

      # Declares an attribute that should be prefixed and suffixed by
      # <tt>ActiveModel::AttributeMethods</tt>.
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
      #
      #     def attribute_short?(attr)
      #       send(attr).length < 5
      #     end
      #   end
      #
      #   person = Person.new
      #   person.name = 'Bob'
      #   person.name        # => "Bob"
      #   person.name_short? # => true
      def define_attribute_method(attr_name, _owner: generated_attribute_methods)
        CodeGenerator.batch(_owner, __FILE__, __LINE__) do |owner|
          attribute_method_matchers.each do |matcher|
            method_name = matcher.method_name(attr_name)

            unless instance_method_already_implemented?(method_name)
              generate_method = "define_method_#{matcher.target}"

              if respond_to?(generate_method, true)
                send(generate_method, attr_name.to_s, owner: owner)
              else
                define_proxy_call owner, method_name, matcher.target, attr_name.to_s
              end
            end
          end
          attribute_method_matchers_cache.clear
        end
      end

      # Removes all the previously dynamically defined methods from the class.
      #
      #   class Person
      #     include ActiveModel::AttributeMethods
      #
      #     attr_accessor :name
      #     attribute_method_suffix '_short?'
      #     define_attribute_method :name
      #
      #     private
      #
      #     def attribute_short?(attr)
      #       send(attr).length < 5
      #     end
      #   end
      #
      #   person = Person.new
      #   person.name = 'Bob'
      #   person.name_short? # => true
      #
      #   Person.undefine_attribute_methods
      #
      #   person.name_short? # => NoMethodError
      def undefine_attribute_methods
        generated_attribute_methods.module_eval do
          undef_method(*instance_methods)
        end
        attribute_method_matchers_cache.clear
      end

      private
        class CodeGenerator
          class << self
            def batch(owner, path, line)
              if owner.is_a?(CodeGenerator)
                yield owner
              else
                instance = new(owner, path, line)
                result = yield instance
                instance.execute
                result
              end
            end
          end

          def initialize(owner, path, line)
            @owner = owner
            @path = path
            @line = line
            @sources = ["# frozen_string_literal: true\n"]
            @renames = {}
          end

          def <<(source_line)
            @sources << source_line
          end

          def rename_method(old_name, new_name)
            @renames[old_name] = new_name
          end

          def execute
            @owner.module_eval(@sources.join(";"), @path, @line - 1)
            @renames.each do |old_name, new_name|
              @owner.alias_method new_name, old_name
              @owner.undef_method old_name
            end
          end
        end
        private_constant :CodeGenerator

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
        def attribute_method_matchers_cache
          @attribute_method_matchers_cache ||= Concurrent::Map.new(initial_capacity: 4)
        end

        def attribute_method_matchers_matching(method_name)
          attribute_method_matchers_cache.compute_if_absent(method_name) do
            attribute_method_matchers.map { |matcher| matcher.match(method_name) }.compact
          end
        end

        # Define a method `name` in `mod` that dispatches to `send`
        # using the given `extra` args. This falls back on `define_method`
        # and `send` if the given names cannot be compiled.
        def define_proxy_call(code_generator, name, target, *extra)
          defn = if NAME_COMPILABLE_REGEXP.match?(name)
            "def #{name}(*args)"
          else
            "define_method(:'#{name}') do |*args|"
          end

          extra = (extra.map!(&:inspect) << "*args").join(", ")

          body = if CALL_COMPILABLE_REGEXP.match?(target)
            "self.#{target}(#{extra})"
          else
            "send(:'#{target}', #{extra})"
          end

          code_generator <<
            defn <<
            body <<
            "end" <<
            "ruby2_keywords(:'#{name}')"
        end

        class AttributeMethodMatcher #:nodoc:
          attr_reader :prefix, :suffix, :target

          AttributeMethodMatch = Struct.new(:target, :attr_name)

          def initialize(options = {})
            @prefix, @suffix = options.fetch(:prefix, ""), options.fetch(:suffix, "")
            @regex = /^(?:#{Regexp.escape(@prefix)})(.*)(?:#{Regexp.escape(@suffix)})$/
            @target = "#{@prefix}attribute#{@suffix}"
            @method_name = "#{prefix}%s#{suffix}"
          end

          def match(method_name)
            if @regex =~ method_name
              AttributeMethodMatch.new(target, $1)
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
    ruby2_keywords def method_missing(method, *args, &block)
      if respond_to_without_attributes?(method, true)
        super
      else
        match = matched_attribute_method(method.to_s)
        match ? attribute_missing(match, *args, &block) : super
      end
    end

    # +attribute_missing+ is like +method_missing+, but for attributes. When
    # +method_missing+ is called we check to see if there is a matching
    # attribute method. If so, we tell +attribute_missing+ to dispatch the
    # attribute. This method can be overloaded to customize the behavior.
    def attribute_missing(match, *args, &block)
      __send__(match.target, match.attr_name, *args, &block)
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
        matches = self.class.send(:attribute_method_matchers_matching, method_name)
        matches.detect { |match| attribute_method?(match.attr_name) }
      end

      def missing_attribute(attr_name, stack)
        raise ActiveModel::MissingAttributeError, "missing attribute: #{attr_name}", stack
      end

      def _read_attribute(attr)
        __send__(attr)
      end

      module AttrNames # :nodoc:
        DEF_SAFE_NAME = /\A[a-zA-Z_]\w*\z/

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
            owner.rename_method(temp_method_name, method_name)
          end
        end
      end
  end
end
