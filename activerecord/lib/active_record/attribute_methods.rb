# frozen_string_literal: true

require "mutex_m"

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

      delegate :column_for_attribute, to: :class
    end

    AttrNames = Module.new {
      def self.set_name_cache(name, value)
        const_name = "ATTR_#{name}"
        unless const_defined? const_name
          const_set const_name, -value
        end
      end
    }

    RESTRICTED_CLASS_METHODS = %w(private public protected allocate new name parent superclass)

    class GeneratedAttributeMethods < Module #:nodoc:
      include Mutex_m
    end

    module ClassMethods
      def inherited(child_class) #:nodoc:
        child_class.initialize_generated_modules
        super
      end

      def initialize_generated_modules # :nodoc:
        @generated_attribute_methods = GeneratedAttributeMethods.new
        @attribute_methods_generated = false
        include @generated_attribute_methods

        super
      end

      # Generates all the attribute related methods for columns in the database
      # accessors, mutators and query methods.
      def define_attribute_methods # :nodoc:
        return false if @attribute_methods_generated
        # Use a mutex; we don't want two threads simultaneously trying to define
        # attribute methods.
        generated_attribute_methods.synchronize do
          return false if @attribute_methods_generated
          superclass.define_attribute_methods unless base_class?
          super(attribute_names)
          @attribute_methods_generated = true
        end
      end

      def undefine_attribute_methods # :nodoc:
        generated_attribute_methods.synchronize do
          super if defined?(@attribute_methods_generated) && @attribute_methods_generated
          @attribute_methods_generated = false
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
          # defines its own attribute method, then we don't want to overwrite that.
          defined = method_defined_within?(method_name, superclass, Base) &&
            ! superclass.instance_method(method_name).owner.is_a?(GeneratedAttributeMethods)
          defined || super
        end
      end

      # A method name is 'dangerous' if it is already (re)defined by Active Record, but
      # not by any ancestors. (So 'puts' is not dangerous but 'save' is.)
      def dangerous_attribute_method?(name) # :nodoc:
        method_defined_within?(name, Base)
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
        RESTRICTED_CLASS_METHODS.include?(method_name.to_s) || class_method_defined_within?(method_name, Base)
      end

      def class_method_defined_within?(name, klass, superklass = klass.superclass) # :nodoc:
        if klass.respond_to?(name, true)
          if superklass.respond_to?(name, true)
            klass.method(name).owner != superklass.method(name).owner
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
        super || (table_exists? && column_names.include?(attribute.to_s.sub(/=$/, "")))
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
        end
      end

      # Regexp for column names (with or without a table name prefix). Matches
      # the following:
      #   "#{table_name}.#{column_name}"
      #   "#{column_name}"
      COLUMN_NAME = /\A(?:\w+\.)?\w+\z/i

      # Regexp for column names with order (with or without a table name
      # prefix, with or without various order modifiers). Matches the following:
      #   "#{table_name}.#{column_name}"
      #   "#{table_name}.#{column_name} #{direction}"
      #   "#{table_name}.#{column_name} #{direction} NULLS FIRST"
      #   "#{table_name}.#{column_name} NULLS LAST"
      #   "#{column_name}"
      #   "#{column_name} #{direction}"
      #   "#{column_name} #{direction} NULLS FIRST"
      #   "#{column_name} NULLS LAST"
      COLUMN_NAME_WITH_ORDER = /
        \A
        (?:\w+\.)?
        \w+
        (?:\s+asc|\s+desc)?
        (?:\s+nulls\s+(?:first|last))?
        \z
      /ix

      def disallow_raw_sql!(args, permit: COLUMN_NAME) # :nodoc:
        unexpected = args.reject do |arg|
          Arel.arel_node?(arg) ||
            arg.to_s.split(/\s*,\s*/).all? { |part| permit.match?(part) }
        end

        return if unexpected.none?

        if allow_unsafe_raw_sql == :deprecated
          ActiveSupport::Deprecation.warn(
            "Dangerous query method (method whose arguments are used as raw " \
            "SQL) called with non-attribute argument(s): " \
            "#{unexpected.map(&:inspect).join(", ")}. Non-attribute " \
            "arguments will be disallowed in Rails 6.0. This method should " \
            "not be called with user-provided values, such as request " \
            "parameters or model attributes. Known-safe values can be passed " \
            "by wrapping them in Arel.sql()."
          )
        else
          raise(ActiveRecord::UnknownAttributeReference,
            "Query method called with non-attribute argument(s): " +
            unexpected.map(&:inspect).join(", ")
          )
        end
      end

      # Returns true if the given attribute exists, otherwise false.
      #
      #   class Person < ActiveRecord::Base
      #   end
      #
      #   Person.has_attribute?('name')   # => true
      #   Person.has_attribute?(:age)     # => true
      #   Person.has_attribute?(:nothing) # => false
      def has_attribute?(attr_name)
        attribute_types.key?(attr_name.to_s)
      end

      # Returns the column object for the named attribute.
      # Returns a +ActiveRecord::ConnectionAdapters::NullColumn+ if the
      # named attribute does not exist.
      #
      #   class Person < ActiveRecord::Base
      #   end
      #
      #   person = Person.new
      #   person.column_for_attribute(:name) # the result depends on the ConnectionAdapter
      #   # => #<ActiveRecord::ConnectionAdapters::Column:0x007ff4ab083980 @name="name", @sql_type="varchar(255)", @null=true, ...>
      #
      #   person.column_for_attribute(:nothing)
      #   # => #<ActiveRecord::ConnectionAdapters::NullColumn:0xXXX @name=nil, @sql_type=nil, @cast_type=#<Type::Value>, ...>
      def column_for_attribute(name)
        name = name.to_s
        columns_hash.fetch(name) do
          ConnectionAdapters::NullColumn.new(name)
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

      case name
      when :to_partial_path
        name = "to_partial_path"
      when :to_model
        name = "to_model"
      else
        name = name.to_s
      end

      # If the result is true then check for the select case.
      # For queries selecting a subset of columns, return false for unselected columns.
      # We check defined?(@attributes) not to issue warnings if called on objects that
      # have been allocated but not yet initialized.
      if defined?(@attributes) && self.class.column_names.include?(name)
        return has_attribute?(name)
      end

      true
    end

    # Returns +true+ if the given attribute is in the attributes hash, otherwise +false+.
    #
    #   class Person < ActiveRecord::Base
    #   end
    #
    #   person = Person.new
    #   person.has_attribute?(:name)    # => true
    #   person.has_attribute?('age')    # => true
    #   person.has_attribute?(:nothing) # => false
    def has_attribute?(attr_name)
      @attributes.key?(attr_name.to_s)
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
    # characters, Date and Time attributes are returned in the
    # <tt>:db</tt> format. Other attributes return the value of
    # <tt>#inspect</tt> without modification.
    #
    #   person = Person.create!(name: 'David Heinemeier Hansson ' * 3)
    #
    #   person.attribute_for_inspect(:name)
    #   # => "\"David Heinemeier Hansson David Heinemeier Hansson ...\""
    #
    #   person.attribute_for_inspect(:created_at)
    #   # => "\"2012-10-22 00:15:07\""
    #
    #   person.attribute_for_inspect(:tag_ids)
    #   # => "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]"
    def attribute_for_inspect(attr_name)
      value = read_attribute(attr_name)

      if value.is_a?(String) && value.length > 50
        "#{value[0, 50]}...".inspect
      elsif value.is_a?(Date) || value.is_a?(Time)
        %("#{value.to_s(:db)}")
      else
        value.inspect
      end
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
    def attribute_present?(attribute)
      value = _read_attribute(attribute)
      !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
    end

    # Returns the value of the attribute identified by <tt>attr_name</tt> after it has been typecast (for example,
    # "2004-12-12" in a date column is cast to a date object, like Date.new(2004, 12, 12)). It raises
    # <tt>ActiveModel::MissingAttributeError</tt> if the identified attribute is missing.
    #
    # Note: +:id+ is always present.
    #
    #   class Person < ActiveRecord::Base
    #     belongs_to :organization
    #   end
    #
    #   person = Person.new(name: 'Francesco', age: '22')
    #   person[:name] # => "Francesco"
    #   person[:age]  # => 22
    #
    #   person = Person.select('id').first
    #   person[:name]            # => ActiveModel::MissingAttributeError: missing attribute: name
    #   person[:organization_id] # => ActiveModel::MissingAttributeError: missing attribute: organization_id
    def [](attr_name)
      read_attribute(attr_name) { |n| missing_attribute(n, caller) }
    end

    # Updates the attribute identified by <tt>attr_name</tt> with the specified +value+.
    # (Alias for the protected #write_attribute method).
    #
    #   class Person < ActiveRecord::Base
    #   end
    #
    #   person = Person.new
    #   person[:age] = '22'
    #   person[:age] # => 22
    #   person[:age].class # => Integer
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
    #
    #     def print_accessed_fields
    #       p @posts.first.accessed_fields
    #     end
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
      def attribute_method?(attr_name)
        # We check defined? because Syck calls respond_to? before actually calling initialize.
        defined?(@attributes) && @attributes.key?(attr_name)
      end

      def attributes_with_values(attribute_names)
        attribute_names.each_with_object({}) do |name, attrs|
          attrs[name] = _read_attribute(name)
        end
      end

      # Filters the primary keys and readonly attributes from the attribute names.
      def attributes_for_update(attribute_names)
        attribute_names &= self.class.column_names
        attribute_names.delete_if do |name|
          readonly_attribute?(name)
        end
      end

      # Filters out the primary keys, from the attribute names, when the primary
      # key is to be generated (e.g. the id attribute has no value).
      def attributes_for_create(attribute_names)
        attribute_names &= self.class.column_names
        attribute_names.delete_if do |name|
          pk_attribute?(name) && id.nil?
        end
      end

      def readonly_attribute?(name)
        self.class.readonly_attributes.include?(name)
      end

      def pk_attribute?(name)
        name == self.class.primary_key
      end
  end
end
