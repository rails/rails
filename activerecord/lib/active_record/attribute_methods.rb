require 'active_support/core_ext/enumerable'
require 'mutex_m'
require 'thread_safe'

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

    AttrNames = Module.new {
      def self.set_name_cache(name, value)
        const_name = "ATTR_#{name}"
        unless const_defined? const_name
          const_set const_name, value.dup.freeze
        end
      end
    }

    BLACKLISTED_CLASS_METHODS = %w(private public protected allocate new name parent superclass)

    class AttributeMethodCache
      def initialize
        @module = Module.new
        @method_cache = ThreadSafe::Cache.new
      end

      def [](name)
        @method_cache.compute_if_absent(name) do
          safe_name = name.unpack('h*').first
          temp_method = "__temp__#{safe_name}"
          ActiveRecord::AttributeMethods::AttrNames.set_name_cache safe_name, name
          @module.module_eval method_body(temp_method, safe_name), __FILE__, __LINE__
          @module.instance_method temp_method
        end
      end

      private
      def method_body; raise NotImplementedError; end
    end

    class GeneratedAttributeMethods < Module; end # :nodoc:

    module ClassMethods
      def inherited(child_class) #:nodoc:
        child_class.initialize_generated_modules
        super
      end

      def initialize_generated_modules # :nodoc:
        @generated_attribute_methods = GeneratedAttributeMethods.new { extend Mutex_m }
        @attribute_methods_generated = false
        include @generated_attribute_methods

        super
      end

      # Generates all the attribute related methods for columns in the database
      # accessors, mutators and query methods.
      def define_attribute_methods # :nodoc:
        return false if @attribute_methods_generated
        # Use a mutex; we don't want two thread simultaneously trying to define
        # attribute methods.
        generated_attribute_methods.synchronize do
          return false if @attribute_methods_generated
          superclass.define_attribute_methods unless self == base_class
          super(column_names)
          @attribute_methods_generated = true
        end
        true
      end

      def undefine_attribute_methods # :nodoc:
        generated_attribute_methods.synchronize do
          super if @attribute_methods_generated
          @attribute_methods_generated = false
        end
      end

      # Raises a <tt>ActiveRecord::DangerousAttributeError</tt> exception when an
      # \Active \Record method is defined in the model, otherwise +false+.
      #
      #   class Person < ActiveRecord::Base
      #     def save
      #       'already defined by Active Record'
      #     end
      #   end
      #
      #   Person.instance_method_already_implemented?(:save)
      #   # => ActiveRecord::DangerousAttributeError: save is defined by ActiveRecord
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
        BLACKLISTED_CLASS_METHODS.include?(method_name.to_s) || class_method_defined_within?(method_name, Base)
      end

      def class_method_defined_within?(name, klass, superklass = klass.superclass) # :nodoc
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

      def find_generated_attribute_method(method_name) # :nodoc:
        klass = self
        until klass == Base
          gen_methods = klass.generated_attribute_methods
          return gen_methods.instance_method(method_name) if method_defined_within?(method_name, gen_methods, Object)
          klass = klass.superclass
        end
        nil
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
        super || (table_exists? && column_names.include?(attribute.to_s.sub(/=$/, '')))
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
            column_names
          else
            []
          end
      end
    end

    # If we haven't generated any methods yet, generate them, then
    # see if we've created the method we're looking for.
    def method_missing(method, *args, &block) # :nodoc:
      self.class.define_attribute_methods
      if respond_to_without_attributes?(method)
        # make sure to invoke the correct attribute method, as we might have gotten here via a `super`
        # call in a overwritten attribute method
        if attribute_method = self.class.find_generated_attribute_method(method)
          # this is probably horribly slow, but should only happen at most once for a given AR class
          attribute_method.bind(self).call(*args, &block)
        else
          return super unless respond_to_missing?(method, true)
          send(method, *args, &block)
        end
      else
        super
      end
    end

    # A Person object with a name attribute can ask <tt>person.respond_to?(:name)</tt>,
    # <tt>person.respond_to?(:name=)</tt>, and <tt>person.respond_to?(:name?)</tt>
    # which will all return +true+. It also define the attribute methods if they have
    # not been generated.
    #
    #   class Person < ActiveRecord::Base
    #   end
    #
    #   person = Person.new
    #   person.respond_to(:name)    # => true
    #   person.respond_to(:name=)   # => true
    #   person.respond_to(:name?)   # => true
    #   person.respond_to('age')    # => true
    #   person.respond_to('age=')   # => true
    #   person.respond_to('age?')   # => true
    #   person.respond_to(:nothing) # => false
    def respond_to?(name, include_private = false)
      name = name.to_s
      self.class.define_attribute_methods
      result = super

      # If the result is false the answer is false.
      return false unless result

      # If the result is true then check for the select case.
      # For queries selecting a subset of columns, return false for unselected columns.
      # We check defined?(@attributes) not to issue warnings if called on objects that
      # have been allocated but not yet initialized.
      if defined?(@attributes) && @attributes.any? && self.class.column_names.include?(name)
        return has_attribute?(name)
      end

      return true
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
      @attributes.has_key?(attr_name.to_s)
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
      attribute_names.each_with_object({}) { |name, attrs|
        attrs[name] = read_attribute(name)
      }
    end

    # Placeholder so it can be overriden when needed by serialization
    def attributes_for_coder # :nodoc:
      attributes
    end

    # Returns an <tt>#inspect</tt>-like string for the value of the
    # attribute +attr_name+. String attributes are truncated upto 50
    # characters, Date and Time attributes are returned in the
    # <tt>:db</tt> format, Array attributes are truncated upto 10 values.
    # Other attributes return the value of <tt>#inspect</tt> without
    # modification.
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
    #   # => "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, ...]"
    def attribute_for_inspect(attr_name)
      value = read_attribute(attr_name)

      if value.is_a?(String) && value.length > 50
        "#{value[0, 50]}...".inspect
      elsif value.is_a?(Date) || value.is_a?(Time)
        %("#{value.to_s(:db)}")
      elsif value.is_a?(Array) && value.size > 10
        inspected = value.first(10).inspect
        %(#{inspected[0...-1]}, ...])
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
    #   person = Task.new(title: '', is_done: false)
    #   person.attribute_present?(:title)   # => false
    #   person.attribute_present?(:is_done) # => true
    #   person.name = 'Francesco'
    #   person.is_done = true
    #   person.attribute_present?(:title)   # => true
    #   person.attribute_present?(:is_done) # => true
    def attribute_present?(attribute)
      value = read_attribute(attribute)
      !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
    end

    # Returns the column object for the named attribute. Returns +nil+ if the
    # named attribute not exists.
    #
    #   class Person < ActiveRecord::Base
    #   end
    #
    #   person = Person.new
    #   person.column_for_attribute(:name) # the result depends on the ConnectionAdapter
    #   # => #<ActiveRecord::ConnectionAdapters::SQLite3Column:0x007ff4ab083980 @name="name", @sql_type="varchar(255)", @null=true, ...>
    #
    #   person.column_for_attribute(:nothing)
    #   # => nil
    def column_for_attribute(name)
      # FIXME: should this return a null object for columns that don't exist?
      self.class.columns_hash[name.to_s]
    end

    # Returns the value of the attribute identified by <tt>attr_name</tt> after it has been typecast (for example,
    # "2004-12-12" in a date column is cast to a date object, like Date.new(2004, 12, 12)). It raises
    # <tt>ActiveModel::MissingAttributeError</tt> if the identified attribute is missing.
    #
    # Alias for the <tt>read_attribute</tt> method.
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
    # (Alias for the protected <tt>write_attribute</tt> method).
    #
    #   class Person < ActiveRecord::Base
    #   end
    #
    #   person = Person.new
    #   person[:age] = '22'
    #   person[:age] # => 22
    #   person[:age] # => Fixnum
    def []=(attr_name, value)
      write_attribute(attr_name, value)
    end

    protected

    def clone_attributes(reader_method = :read_attribute, attributes = {}) # :nodoc:
      attribute_names.each do |name|
        attributes[name] = clone_attribute_value(reader_method, name)
      end
      attributes
    end

    def clone_attribute_value(reader_method, attribute_name) # :nodoc:
      value = send(reader_method, attribute_name)
      value.duplicable? ? value.clone : value
    rescue TypeError, NoMethodError
      value
    end

    def arel_attributes_with_values_for_create(attribute_names) # :nodoc:
      arel_attributes_with_values(attributes_for_create(attribute_names))
    end

    def arel_attributes_with_values_for_update(attribute_names) # :nodoc:
      arel_attributes_with_values(attributes_for_update(attribute_names))
    end

    def attribute_method?(attr_name) # :nodoc:
      # We check defined? because Syck calls respond_to? before actually calling initialize.
      defined?(@attributes) && @attributes.include?(attr_name)
    end

    private

    # Returns a Hash of the Arel::Attributes and attribute values that have been
    # typecasted for use in an Arel insert/update method.
    def arel_attributes_with_values(attribute_names)
      attrs = {}
      arel_table = self.class.arel_table

      attribute_names.each do |name|
        attrs[arel_table[name]] = typecasted_attribute_value(name)
      end
      attrs
    end

    # Filters the primary keys and readonly attributes from the attribute names.
    def attributes_for_update(attribute_names)
      attribute_names.select do |name|
        column_for_attribute(name) && !readonly_attribute?(name)
      end
    end

    # Filters out the primary keys, from the attribute names, when the primary
    # key is to be generated (e.g. the id attribute has no value).
    def attributes_for_create(attribute_names)
      attribute_names.select do |name|
        column_for_attribute(name) && !(pk_attribute?(name) && id.nil?)
      end
    end

    def readonly_attribute?(name)
      self.class.readonly_attributes.include?(name)
    end

    def pk_attribute?(name)
      column_for_attribute(name).primary
    end

    def typecasted_attribute_value(name)
      # FIXME: we need @attributes to be used consistently.
      # If the values stored in @attributes were already typecasted, this code
      # could be simplified
      read_attribute(name)
    end
  end
end
