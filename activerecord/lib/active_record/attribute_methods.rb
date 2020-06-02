# frozen_string_literal: true

require "mutex_m"
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

      delegate :column_for_attribute, to: :class
    end

    RESTRICTED_CLASS_METHODS = %w(private public protected allocate new name parent superclass)

    class GeneratedAttributeMethods < Module #:nodoc:
      include Mutex_m
    end

    class << self
      def dangerous_attribute_methods # :nodoc:
        @dangerous_attribute_methods ||= (
          Base.instance_methods +
          Base.private_instance_methods -
          Base.superclass.instance_methods -
          Base.superclass.private_instance_methods
        ).map { |m| -m.to_s }.to_set.freeze
      end
    end

    module ClassMethods
      def inherited(child_class) #:nodoc:
        child_class.initialize_generated_modules
        super
      end

      def initialize_generated_modules # :nodoc:
        @generated_attribute_methods = const_set(:GeneratedAttributeMethods, GeneratedAttributeMethods.new)
        private_constant :GeneratedAttributeMethods
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

      # If the result is true then check for the select case.
      # For queries selecting a subset of columns, return false for unselected columns.
      # We check defined?(@attributes) not to issue warnings if called on objects that
      # have been allocated but not yet initialized.
      if defined?(@attributes)
        if name = self.class.symbol_column_to_string(name.to_sym)
          return has_attribute?(name)
        end
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
      value = _read_attribute(attr_name)
      format_for_inspect(value)
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
        attribute_names.index_with do |name|
          _read_attribute(name)
        end
      end

      # Filters the primary keys and readonly attributes from the attribute names.
      def attributes_for_update(attribute_names)
        attribute_names &= self.class.column_names
        attribute_names.delete_if do |name|
          self.class.readonly_attribute?(name)
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

      def format_for_inspect(value)
        if value.is_a?(String) && value.length > 50
          "#{value[0, 50]}...".inspect
        elsif value.is_a?(Date) || value.is_a?(Time)
          %("#{value.to_s(:inspect)}")
        else
          value.inspect
        end
      end

      def pk_attribute?(name)
        name == @primary_key
      end
  end
end
