module ActiveRecord
  module AttributeMethods #:nodoc:
    DEFAULT_SUFFIXES = %w(= ? _before_type_cast)
    ATTRIBUTE_TYPES_CACHED_BY_DEFAULT = [:datetime, :timestamp, :time, :date]

    def self.included(base)
      base.extend ClassMethods
      base.attribute_method_suffix(*DEFAULT_SUFFIXES)
      base.cattr_accessor :attribute_types_cached_by_default, :instance_writer => false
      base.attribute_types_cached_by_default = ATTRIBUTE_TYPES_CACHED_BY_DEFAULT
      base.cattr_accessor :time_zone_aware_attributes, :instance_writer => false
      base.time_zone_aware_attributes = false
      base.class_inheritable_accessor :skip_time_zone_conversion_for_attributes, :instance_writer => false
      base.skip_time_zone_conversion_for_attributes = []
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
        columns_hash.each do |name, column|
          unless instance_method_already_implemented?(name)
            if self.serialized_attributes[name]
              define_read_method_for_serialized_attribute(name)
            elsif create_time_zone_conversion_attribute?(name, column)
              define_read_method_for_time_zone_conversion(name)
            else
              define_read_method(name.to_sym, name, column)
            end
          end

          unless instance_method_already_implemented?("#{name}=")
            if create_time_zone_conversion_attribute?(name, column)
              define_write_method_for_time_zone_conversion(name)
            else  
              define_write_method(name.to_sym)
            end
          end

          unless instance_method_already_implemented?("#{name}?")
            define_question_method(name)
          end
        end
      end

      # Checks whether the method is defined in the model or any of its subclasses
      # that also derive from Active Record. Raises DangerousAttributeError if the
      # method is defined by Active Record though.
      def instance_method_already_implemented?(method_name)
        method_name = method_name.to_s
        return true if method_name =~ /^id(=$|\?$|$)/
        @_defined_class_methods         ||= ancestors.first(ancestors.index(ActiveRecord::Base)).sum([]) { |m| m.public_instance_methods(false) | m.private_instance_methods(false) | m.protected_instance_methods(false) }.map(&:to_s).to_set
        @@_defined_activerecord_methods ||= (ActiveRecord::Base.public_instance_methods(false) | ActiveRecord::Base.private_instance_methods(false) | ActiveRecord::Base.protected_instance_methods(false)).map(&:to_s).to_set
        raise DangerousAttributeError, "#{method_name} is defined by ActiveRecord" if @@_defined_activerecord_methods.include?(method_name)
        @_defined_class_methods.include?(method_name)
      end
      
      alias :define_read_methods :define_attribute_methods

      # +cache_attributes+ allows you to declare which converted attribute values should
      # be cached. Usually caching only pays off for attributes with expensive conversion
      # methods, like time related columns (e.g. +created_at+, +updated_at+).
      def cache_attributes(*attribute_names)
        attribute_names.each {|attr| cached_attributes << attr.to_s}
      end

      # Returns the attributes which are cached. By default time related columns
      # with datatype <tt>:datetime, :timestamp, :time, :date</tt> are cached.
      def cached_attributes
        @cached_attributes ||=
          columns.select{|c| attribute_types_cached_by_default.include?(c.type)}.map(&:name).to_set
      end

      # Returns +true+ if the provided attribute is being cached.
      def cache_attribute?(attr_name)
        cached_attributes.include?(attr_name)
      end

      private
        # Suffixes a, ?, c become regexp /(a|\?|c)$/
        def rebuild_attribute_method_regexp
          suffixes = attribute_method_suffixes.map { |s| Regexp.escape(s) }
          @@attribute_method_regexp = /(#{suffixes.join('|')})$/.freeze
        end

        # Default to =, ?, _before_type_cast
        def attribute_method_suffixes
          @@attribute_method_suffixes ||= []
        end
        
        def create_time_zone_conversion_attribute?(name, column)
          time_zone_aware_attributes && !skip_time_zone_conversion_for_attributes.include?(name.to_sym) && [:datetime, :timestamp].include?(column.type)
        end
        
        # Define an attribute reader method.  Cope with nil column.
        def define_read_method(symbol, attr_name, column)
          cast_code = column.type_cast_code('v') if column
          access_code = cast_code ? "(v=@attributes['#{attr_name}']) && #{cast_code}" : "@attributes['#{attr_name}']"

          unless attr_name.to_s == self.primary_key.to_s
            access_code = access_code.insert(0, "missing_attribute('#{attr_name}', caller) unless @attributes.has_key?('#{attr_name}'); ")
          end
          
          if cache_attribute?(attr_name)
            access_code = "@attributes_cache['#{attr_name}'] ||= (#{access_code})"
          end
          evaluate_attribute_method attr_name, "def #{symbol}; #{access_code}; end"
        end

        # Define read method for serialized attribute.
        def define_read_method_for_serialized_attribute(attr_name)
          evaluate_attribute_method attr_name, "def #{attr_name}; unserialize_attribute('#{attr_name}'); end"
        end
        
        # Defined for all +datetime+ and +timestamp+ attributes when +time_zone_aware_attributes+ are enabled.
        # This enhanced read method automatically converts the UTC time stored in the database to the time zone stored in Time.zone.
        def define_read_method_for_time_zone_conversion(attr_name)
          method_body = <<-EOV
            def #{attr_name}(reload = false)
              cached = @attributes_cache['#{attr_name}']
              return cached if cached && !reload
              time = read_attribute('#{attr_name}')
              @attributes_cache['#{attr_name}'] = time.acts_like?(:time) ? time.in_time_zone : time
            end
          EOV
          evaluate_attribute_method attr_name, method_body
        end

        # Defines a predicate method <tt>attr_name?</tt>.
        def define_question_method(attr_name)
          evaluate_attribute_method attr_name, "def #{attr_name}?; query_attribute('#{attr_name}'); end", "#{attr_name}?"
        end

        def define_write_method(attr_name)
          evaluate_attribute_method attr_name, "def #{attr_name}=(new_value);write_attribute('#{attr_name}', new_value);end", "#{attr_name}="
        end
        
        # Defined for all +datetime+ and +timestamp+ attributes when +time_zone_aware_attributes+ are enabled.
        # This enhanced write method will automatically convert the time passed to it to the zone stored in Time.zone.
        def define_write_method_for_time_zone_conversion(attr_name)
          method_body = <<-EOV
            def #{attr_name}=(time)
              unless time.acts_like?(:time)
                time = time.is_a?(String) ? Time.zone.parse(time) : time.to_time rescue time
              end
              time = time.in_time_zone rescue nil if time
              write_attribute(:#{attr_name}, time)
            end
          EOV
          evaluate_attribute_method attr_name, method_body, "#{attr_name}="
        end

        # Evaluate the definition for an attribute related method
        def evaluate_attribute_method(attr_name, method_definition, method_name=attr_name)

          unless method_name.to_s == primary_key.to_s
            generated_methods << method_name
          end

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
    end #  ClassMethods


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

      if self.class.private_method_defined?(method_name)
        raise NoMethodError.new("Attempt to call private method", method_name, args)
      end

      # If we haven't generated any methods yet, generate them, then
      # see if we've created the method we're looking for.
      if !self.class.generated_methods?
        self.class.define_attribute_methods
        if self.class.generated_methods.include?(method_name)
          return self.send(method_id, *args, &block)
        end
      end
      
      if self.class.primary_key.to_s == method_name
        id
      elsif md = self.class.match_attribute_method?(method_name)
        attribute_name, method_type = md.pre_match, md.to_s
        if @attributes.include?(attribute_name)
          __send__("attribute#{method_type}", attribute_name, *args, &block)
        else
          super
        end
      elsif @attributes.include?(method_name)
        read_attribute(method_name)
      else
        super
      end
    end

    # Returns the value of the attribute identified by <tt>attr_name</tt> after it has been typecast (for example,
    # "2004-12-12" in a data column is cast to a date object, like Date.new(2004, 12, 12)).
    def read_attribute(attr_name)
      attr_name = attr_name.to_s
      if !(value = @attributes[attr_name]).nil?
        if column = column_for_attribute(attr_name)
          if unserializable_attribute?(attr_name, column)
            unserialize_attribute(attr_name)
          else
            column.type_cast(value)
          end
        else
          value
        end
      else
        nil
      end
    end

    def read_attribute_before_type_cast(attr_name)
      @attributes[attr_name]
    end

    # Returns true if the attribute is of a text column and marked for serialization.
    def unserializable_attribute?(attr_name, column)
      column.text? && self.class.serialized_attributes[attr_name]
    end

    # Returns the unserialized object of the attribute.
    def unserialize_attribute(attr_name)
      unserialized_object = object_from_yaml(@attributes[attr_name])

      if unserialized_object.is_a?(self.class.serialized_attributes[attr_name]) || unserialized_object.nil?
        @attributes.frozen? ? unserialized_object : @attributes[attr_name] = unserialized_object
      else
        raise SerializationTypeMismatch,
          "#{attr_name} was supposed to be a #{self.class.serialized_attributes[attr_name]}, but was a #{unserialized_object.class.to_s}"
      end
    end
  

    # Updates the attribute identified by <tt>attr_name</tt> with the specified +value+. Empty strings for fixnum and float
    # columns are turned into +nil+.
    def write_attribute(attr_name, value)
      attr_name = attr_name.to_s
      @attributes_cache.delete(attr_name)
      if (column = column_for_attribute(attr_name)) && column.number?
        @attributes[attr_name] = convert_number_column_value(value)
      else
        @attributes[attr_name] = value
      end
    end


    def query_attribute(attr_name)
      unless value = read_attribute(attr_name)
        false
      else
        column = self.class.columns_hash[attr_name]
        if column.nil?
          if Numeric === value || value !~ /[^0-9]/
            !value.to_i.zero?
          else
            return false if ActiveRecord::ConnectionAdapters::Column::FALSE_VALUES.include?(value)
            !value.blank?
          end
        elsif column.number?
          !value.zero?
        else
          !value.blank?
        end
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
        
      if @attributes.nil?
        return super
      elsif @attributes.include?(method_name)
        return true
      elsif md = self.class.match_attribute_method?(method_name)
        return true if @attributes.include?(md.pre_match)
      end
      super
    end

    private
    
      def missing_attribute(attr_name, stack)
        raise ActiveRecord::MissingAttributeError, "missing attribute: #{attr_name}", stack
      end
      
      # Handle *? for method_missing.
      def attribute?(attribute_name)
        query_attribute(attribute_name)
      end

      # Handle *= for method_missing.
      def attribute=(attribute_name, value)
        write_attribute(attribute_name, value)
      end

      # Handle *_before_type_cast for method_missing.
      def attribute_before_type_cast(attribute_name)
        read_attribute_before_type_cast(attribute_name)
      end
  end
end
