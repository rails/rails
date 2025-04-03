# frozen_string_literal: true

require "active_support/core_ext/enumerable"

module ActiveRecord
  # = Active Record Attribute Methods
  module AttributeMethods
    extend ActiveSupport::Concern
    include ActiveModel::AttributeMethods

    included do
      initialize_generated_modules
      include Read
      include Write
      include BeforeTypeCast
      include Query
      include PrimaryKey
      include TimeZoneConversion
      include Dirty
      include Serialization
    end

    RESTRICTED_CLASS_METHODS = %w(private public protected allocate new name superclass)

    class GeneratedAttributeMethods < Module # :nodoc:
      LOCK = Monitor.new
    end

    class << self
      def dangerous_attribute_methods # :nodoc:
        @dangerous_attribute_methods ||= (
          Base.instance_methods +
          Base.private_instance_methods -
          Base.superclass.instance_methods -
          Base.superclass.private_instance_methods +
          %i[__id__ dup freeze frozen? hash class clone]
        ).map { |m| -m.to_s }.to_set.freeze
      end
    end

    module ClassMethods
      def initialize_generated_modules # :nodoc:
        @generated_attribute_methods = const_set(:GeneratedAttributeMethods, GeneratedAttributeMethods.new)
        private_constant :GeneratedAttributeMethods
        @attribute_methods_generated = false
        @alias_attributes_mass_generated = false
        include @generated_attribute_methods

        super
      end

      # Allows you to make aliases for attributes.
      #
      #   class Person < ActiveRecord::Base
      #     alias_attribute :nickname, :name
      #   end
      #
      #   person = Person.create(name: 'Bob')
      #   person.name     # => "Bob"
      #   person.nickname # => "Bob"
      #
      # The alias can also be used for querying:
      #
      #   Person.where(nickname: "Bob")
      #   # SELECT "people".* FROM "people" WHERE "people"."name" = "Bob"
      def alias_attribute(new_name, old_name)
        super

        if @alias_attributes_mass_generated
          ActiveSupport::CodeGenerator.batch(generated_attribute_methods, __FILE__, __LINE__) do |code_generator|
            generate_alias_attribute_methods(code_generator, new_name, old_name)
          end
        end
      end

      def eagerly_generate_alias_attribute_methods(_new_name, _old_name) # :nodoc:
        # alias attributes in Active Record are lazily generated
      end

      def generate_alias_attribute_methods(code_generator, new_name, old_name) # :nodoc:
        attribute_method_patterns.each do |pattern|
          alias_attribute_method_definition(code_generator, pattern, new_name, old_name)
        end
        attribute_method_patterns_cache.clear
      end

      def alias_attribute_method_definition(code_generator, pattern, new_name, old_name) # :nodoc:
        old_name = old_name.to_s

        if !abstract_class? && !has_attribute?(old_name)
          raise ArgumentError, "#{self.name} model aliases `#{old_name}`, but `#{old_name}` is not an attribute. " \
            "Use `alias_method :#{new_name}, :#{old_name}` or define the method manually."
        else
          define_attribute_method_pattern(pattern, old_name, owner: code_generator, as: new_name, override: true)
        end
      end

      def attribute_methods_generated? # :nodoc:
        @attribute_methods_generated
      end

      # Generates all the attribute related methods for columns in the database
      # accessors, mutators and query methods.
      def define_attribute_methods # :nodoc:
        return false if @attribute_methods_generated
        # Use a mutex; we don't want two threads simultaneously trying to define
        # attribute methods.
        GeneratedAttributeMethods::LOCK.synchronize do
          return false if @attribute_methods_generated

          superclass.define_attribute_methods unless base_class?

          unless abstract_class?
            load_schema
            super(attribute_names)
            alias_attribute :id_value, :id if _has_attribute?("id")
          end

          generate_alias_attributes

          @attribute_methods_generated = true
        end

        true
      end

      def generate_alias_attributes # :nodoc:
        superclass.generate_alias_attributes unless superclass == Base

        return if @alias_attributes_mass_generated

        ActiveSupport::CodeGenerator.batch(generated_attribute_methods, __FILE__, __LINE__) do |code_generator|
          aliases_by_attribute_name.each do |old_name, new_names|
            new_names.each do |new_name|
              generate_alias_attribute_methods(code_generator, new_name, old_name)
            end
          end
        end

        @alias_attributes_mass_generated = true
      end

      def undefine_attribute_methods # :nodoc:
        GeneratedAttributeMethods::LOCK.synchronize do
          super if @attribute_methods_generated
          @attribute_methods_generated = false
          @alias_attributes_mass_generated = false
        end
      end

      # Raises an ActiveRecord::DangerousAttributeError exception when an
      # \Active \Record method is defined in the model, otherwise +false+.
      #
      #   class Person < ActiveRecord::Base
      #     def save
      #       'already defined by Active Record'
      #     end
      #   end
      #
      #   Person.instance_method_already_implemented?(:save)
      #   # => ActiveRecord::DangerousAttributeError: save is defined by Active Record. Check to make sure that you don't have an attribute or method with the same name.
      #
      #   Person.instance_method_already_implemented?(:name)
      #   # => false
      def instance_method_already_implemented?(method_name)
        if dangerous_attribute_method?(method_name)
          raise DangerousAttributeError, "#{method_name} is defined by Active Record. Check to make sure that you don't have an attribute or method with the same name."
        end

        if superclass == Base
          super
        else
          # If ThisClass < ... < SomeSuperClass < ... < Base and SomeSuperClass
          # defines its own attribute method, then we don't want to override that.
          defined = method_defined_within?(method_name, superclass, Base) &&
            ! superclass.instance_method(method_name).owner.is_a?(GeneratedAttributeMethods)
          defined || super
        end
      end

      # A method name is 'dangerous' if it is already (re)defined by Active Record, but
      # not by any ancestors. (So 'puts' is not dangerous but 'save' is.)
      def dangerous_attribute_method?(name) # :nodoc:
        ::ActiveRecord::AttributeMethods.dangerous_attribute_methods.include?(name.to_s)
      end

      def method_defined_within?(name, klass, superklass = klass.superclass) # :nodoc:
        if klass.method_defined?(name) || klass.private_method_defined?(name)
          if superklass.method_defined?(name) || superklass.private_method_defined?(name)
            klass.instance_method(name).owner != superklass.instance_method(name).owner
          else
            true
          end
        else
          false
        end
      end

      # A class method is 'dangerous' if it is already (re)defined by Active Record, but
      # not by any ancestors. (So 'puts' is not dangerous but 'new' is.)
      def dangerous_class_method?(method_name)
        return true if RESTRICTED_CLASS_METHODS.include?(method_name.to_s)

        if Base.respond_to?(method_name, true)
          if Object.respond_to?(method_name, true)
            Base.method(method_name).owner != Object.method(method_name).owner
          else
            true
          end
        else
          false
        end
      end

      # Returns +true+ if +attribute+ is an attribute method and table exists,
      # +false+ otherwise.
      #
      #   class Person < ActiveRecord::Base
      #   end
      #
      #   Person.attribute_method?('name')   # => true
      #   Person.attribute_method?(:age=)    # => true
      #   Person.attribute_method?(:nothing) # => false
      def attribute_method?(attribute)
        super || (table_exists? && column_names.include?(attribute.to_s.delete_suffix("=")))
      end

      # Returns an array of column names as strings if it's not an abstract class and
      # table exists. Otherwise it returns an empty array.
      #
      #   class Person < ActiveRecord::Base
      #   end
      #
      #   Person.attribute_names
      #   # => ["id", "created_at", "updated_at", "name", "age"]
      def attribute_names
        @attribute_names ||= if !abstract_class? && table_exists?
          attribute_types.keys
        else
          []
        end.freeze
      end

      # Returns true if the given attribute exists, otherwise false.
      #
      #   class Person < ActiveRecord::Base
      #     alias_attribute :new_name, :name
      #   end
      #
      #   Person.has_attribute?('name')     # => true
      #   Person.has_attribute?('new_name') # => true
      #   Person.has_attribute?(:age)       # => true
      #   Person.has_attribute?(:nothing)   # => false
      def has_attribute?(attr_name)
        attr_name = attr_name.to_s
        attr_name = attribute_aliases[attr_name] || attr_name
        attribute_types.key?(attr_name)
      end

      def _has_attribute?(attr_name) # :nodoc:
        attribute_types.key?(attr_name)
      end

      private
        def inherited(child_class)
          super
          child_class.initialize_generated_modules
          child_class.class_eval do
            @alias_attributes_mass_generated = false
            @attribute_names = nil
          end
        end
    end

    # A Person object with a name attribute can ask <tt>person.respond_to?(:name)</tt>,
    # <tt>person.respond_to?(:name=)</tt>, and <tt>person.respond_to?(:name?)</tt>
    # which will all return +true+. It also defines the attribute methods if they have
    # not been generated.
    #
    #   class Person < ActiveRecord::Base
    #   end
    #
    #   person = Person.new
    #   person.respond_to?(:name)    # => true
    #   person.respond_to?(:name=)   # => true
    #   person.respond_to?(:name?)   # => true
    #   person.respond_to?('age')    # => true
    #   person.respond_to?('age=')   # => true
    #   person.respond_to?('age?')   # => true
    #   person.respond_to?(:nothing) # => false
    def respond_to?(name, include_private = false)
      return false unless super

      # If the result is true then check for the select case.
      # For queries selecting a subset of columns, return false for unselected columns.
      if @attributes
        if name = self.class.symbol_column_to_string(name.to_sym)
          return _has_attribute?(name)
        end
      end

      true
    end

    # Returns +true+ if the given attribute is in the attributes hash, otherwise +false+.
    #
    #   class Person < ActiveRecord::Base
    #     alias_attribute :new_name, :name
    #   end
    #
    #   person = Person.new
    #   person.has_attribute?(:name)     # => true
    #   person.has_attribute?(:new_name) # => true
    #   person.has_attribute?('age')     # => true
    #   person.has_attribute?(:nothing)  # => false
    def has_attribute?(attr_name)
      attr_name = attr_name.to_s
      attr_name = self.class.attribute_aliases[attr_name] || attr_name
      @attributes.key?(attr_name)
    end

    def _has_attribute?(attr_name) # :nodoc:
      @attributes.key?(attr_name)
    end

    # Returns an array of names for the attributes available on this object.
    #
    #   class Person < ActiveRecord::Base
    #   end
    #
    #   person = Person.new
    #   person.attribute_names
    #   # => ["id", "created_at", "updated_at", "name", "age"]
    def attribute_names
      @attributes.keys
    end

    # Returns a hash of all the attributes with their names as keys and the values of the attributes as values.
    #
    #   class Person < ActiveRecord::Base
    #   end
    #
    #   person = Person.create(name: 'Francesco', age: 22)
    #   person.attributes
    #   # => {"id"=>3, "created_at"=>Sun, 21 Oct 2012 04:53:04, "updated_at"=>Sun, 21 Oct 2012 04:53:04, "name"=>"Francesco", "age"=>22}
    def attributes
      @attributes.to_hash
    end

    # Returns an <tt>#inspect</tt>-like string for the value of the
    # attribute +attr_name+. String attributes are truncated up to 50
    # characters. Other attributes return the value of <tt>#inspect</tt>
    # without modification.
    #
    #   person = Person.create!(name: 'David Heinemeier Hansson ' * 3)
    #
    #   person.attribute_for_inspect(:name)
    #   # => "\"David Heinemeier Hansson David Heinemeier Hansson ...\""
    #
    #   person.attribute_for_inspect(:created_at)
    #   # => "\"2012-10-22 00:15:07.000000000 +0000\""
    #
    #   person.attribute_for_inspect(:tag_ids)
    #   # => "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]"
    def attribute_for_inspect(attr_name)
      attr_name = attr_name.to_s
      attr_name = self.class.attribute_aliases[attr_name] || attr_name
      value = _read_attribute(attr_name)
      format_for_inspect(attr_name, value)
    end

    # Returns +true+ if the specified +attribute+ has been set by the user or by a
    # database load and is neither +nil+ nor <tt>empty?</tt> (the latter only applies
    # to objects that respond to <tt>empty?</tt>, most notably Strings). Otherwise, +false+.
    # Note that it always returns +true+ with boolean attributes.
    #
    #   class Task < ActiveRecord::Base
    #   end
    #
    #   task = Task.new(title: '', is_done: false)
    #   task.attribute_present?(:title)   # => false
    #   task.attribute_present?(:is_done) # => true
    #   task.title = 'Buy milk'
    #   task.is_done = true
    #   task.attribute_present?(:title)   # => true
    #   task.attribute_present?(:is_done) # => true
    def attribute_present?(attr_name)
      attr_name = attr_name.to_s
      attr_name = self.class.attribute_aliases[attr_name] || attr_name
      value = _read_attribute(attr_name)
      !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
    end

    # Returns the value of the attribute identified by +attr_name+ after it has
    # been type cast. (For information about specific type casting behavior, see
    # the types under ActiveModel::Type.)
    #
    #   class Person < ActiveRecord::Base
    #     belongs_to :organization
    #   end
    #
    #   person = Person.new(name: "Francesco", date_of_birth: "2004-12-12")
    #   person[:name]            # => "Francesco"
    #   person[:date_of_birth]   # => Date.new(2004, 12, 12)
    #   person[:organization_id] # => nil
    #
    # Raises ActiveModel::MissingAttributeError if the attribute is missing.
    # Note, however, that the +id+ attribute will never be considered missing.
    #
    #   person = Person.select(:name).first
    #   person[:name]            # => "Francesco"
    #   person[:date_of_birth]   # => ActiveModel::MissingAttributeError: missing attribute 'date_of_birth' for Person
    #   person[:organization_id] # => ActiveModel::MissingAttributeError: missing attribute 'organization_id' for Person
    #   person[:id]              # => nil
    def [](attr_name)
      read_attribute(attr_name) { |n| missing_attribute(n, caller) }
    end

    # Updates the attribute identified by +attr_name+ using the specified
    # +value+. The attribute value will be type cast upon being read.
    #
    #   class Person < ActiveRecord::Base
    #   end
    #
    #   person = Person.new
    #   person[:date_of_birth] = "2004-12-12"
    #   person[:date_of_birth] # => Date.new(2004, 12, 12)
    def []=(attr_name, value)
      write_attribute(attr_name, value)
    end

    # Returns the name of all database fields which have been read from this
    # model. This can be useful in development mode to determine which fields
    # need to be selected. For performance critical pages, selecting only the
    # required fields can be an easy performance win (assuming you aren't using
    # all of the fields on the model).
    #
    # For example:
    #
    #   class PostsController < ActionController::Base
    #     after_action :print_accessed_fields, only: :index
    #
    #     def index
    #       @posts = Post.all
    #     end
    #
    #     private
    #       def print_accessed_fields
    #         p @posts.first.accessed_fields
    #       end
    #   end
    #
    # Which allows you to quickly change your code to:
    #
    #   class PostsController < ActionController::Base
    #     def index
    #       @posts = Post.select(:id, :title, :author_id, :updated_at)
    #     end
    #   end
    def accessed_fields
      @attributes.accessed
    end

    private
      def respond_to_missing?(name, include_private = false)
        if self.class.define_attribute_methods
          # Some methods weren't defined yet.
          return true if self.class.method_defined?(name)
          return true if include_private && self.class.private_method_defined?(name)
        end

        super
      end

      def method_missing(name, ...)
        # We can't know whether some method was defined or not because
        # multiple thread might be concurrently be in this code path.
        # So the first one would define the methods and the others would
        # appear to already have them.
        self.class.define_attribute_methods

        # So in all cases we must behave as if the method was just defined.
        method = begin
          self.class.public_instance_method(name)
        rescue NameError
          nil
        end

        # The method might be explicitly defined in the model, but call a generated
        # method with super. So we must resume the call chain at the right step.
        method = method.super_method while method && !method.owner.is_a?(GeneratedAttributeMethods)
        if method
          method.bind_call(self, ...)
        else
          super
        end
      end

      def attribute_method?(attr_name)
        @attributes&.key?(attr_name)
      end

      def attributes_with_values(attribute_names)
        attribute_names.index_with { |name| @attributes[name] }
      end

      # Filters the primary keys, readonly attributes and virtual columns from the attribute names.
      def attributes_for_update(attribute_names)
        attribute_names &= self.class.column_names
        attribute_names.delete_if do |name|
          self.class.readonly_attribute?(name) ||
            self.class.counter_cache_column?(name) ||
            column_for_attribute(name).virtual?
        end
      end

      # Filters out the virtual columns and also primary keys, from the attribute names, when the primary
      # key is to be generated (e.g. the id attribute has no value).
      def attributes_for_create(attribute_names)
        attribute_names &= self.class.column_names
        attribute_names.delete_if do |name|
          (pk_attribute?(name) && id.nil?) ||
            column_for_attribute(name).virtual?
        end
      end

      def format_for_inspect(name, value)
        if value.nil?
          value.inspect
        else
          inspected_value = if value.is_a?(String) && value.length > 50
            "#{value[0, 50]}...".inspect
          elsif value.is_a?(Date) || value.is_a?(Time)
            %("#{value.to_fs(:inspect)}")
          else
            value.inspect
          end

          inspection_filter.filter_param(name, inspected_value)
        end
      end

      def pk_attribute?(name)
        name == @primary_key
      end
  end
end
