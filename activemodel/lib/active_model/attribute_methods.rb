# frozen_string_literal: true

require "concurrent/map"

module ActiveModel
  # Raised when an attribute is not defined.
  #
  #   class User < ApplicationRecord
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
        attribute_method_matchers.each do |matcher|
          matcher_new = matcher.method_name(new_name).to_s
          matcher_old = matcher.method_name(old_name).to_s
          define_proxy_call false, self, matcher_new, matcher_old
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
        attr_names.flatten.each { |attr_name| define_attribute_method(attr_name) }
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
      def define_attribute_method(attr_name)
        attribute_method_matchers.each do |matcher|
          method_name = matcher.method_name(attr_name)

          unless instance_method_already_implemented?(method_name)
            generate_method = "define_method_#{matcher.method_missing_target}"

            if respond_to?(generate_method, true)
              send(generate_method, attr_name.to_s)
            else
              define_proxy_call true, generated_attribute_methods, method_name, matcher.method_missing_target, attr_name.to_s
            end
          end
        end
        attribute_method_matchers_cache.clear
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
          instance_methods.each { |m| undef_method(m) }
        end
        attribute_method_matchers_cache.clear
      end

      private
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
            # Must try to match prefixes/suffixes first, or else the matcher with no prefix/suffix
            # will match every time.
            matchers = attribute_method_matchers.partition(&:plain?).reverse.flatten(1)
            matchers.map { |method| method.match(method_name) }.compact
          end
        end

        # Define a method `name` in `mod` that dispatches to `send`
        # using the given `extra` args. This falls back on `define_method`
        # and `send` if the given names cannot be compiled.
        def define_proxy_call(include_private, mod, name, send, *extra)
          defn = if NAME_COMPILABLE_REGEXP.match?(name)
            "def #{name}(*args)"
          else
            "define_method(:'#{name}') do |*args|"
          end

          extra = (extra.map!(&:inspect) << "*args").join(", ".freeze)

          target = if CALL_COMPILABLE_REGEXP.match?(send)
            "#{"self." unless include_private}#{send}(#{extra})"
          else
            "send(:'#{send}', #{extra})"
          end

          mod.module_eval <<-RUBY, __FILE__, __LINE__ + 1
            #{defn}
              #{target}
            end
          RUBY
        end

        class AttributeMethodMatcher #:nodoc:
          attr_reader :prefix, :suffix, :method_missing_target

          AttributeMethodMatch = Struct.new(:target, :attr_name, :method_name)

          def initialize(options = {})
            @prefix, @suffix = options.fetch(:prefix, ""), options.fetch(:suffix, "")
            @regex = /^(?:#{Regexp.escape(@prefix)})(.*)(?:#{Regexp.escape(@suffix)})$/
            @method_missing_target = "#{@prefix}attribute#{@suffix}"
            @method_name = "#{prefix}%s#{suffix}"
          end

          def match(method_name)
            if @regex =~ method_name
              AttributeMethodMatch.new(method_missing_target, $1, method_name)
            end
          end

          def method_name(attr_name)
            @method_name % attr_name
          end

          def plain?
            prefix.empty? && suffix.empty?
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
    def method_missing(method, *args, &block)
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
  end
end
