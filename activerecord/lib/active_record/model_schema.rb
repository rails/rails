require 'active_support/concern'

module ActiveRecord
  module ModelSchema
    extend ActiveSupport::Concern

    included do
      ##
      # :singleton-method:
      # Accessor for the prefix type that will be prepended to every primary key column name.
      # The options are :table_name and :table_name_with_underscore. If the first is specified,
      # the Product class will look for "productid" instead of "id" as the primary column. If the
      # latter is specified, the Product class will look for "product_id" instead of "id". Remember
      # that this is a global setting for all Active Records.
      cattr_accessor :primary_key_prefix_type, :instance_writer => false
      self.primary_key_prefix_type = nil

      ##
      # :singleton-method:
      # Accessor for the name of the prefix string to prepend to every table name. So if set
      # to "basecamp_", all table names will be named like "basecamp_projects", "basecamp_people",
      # etc. This is a convenient way of creating a namespace for tables in a shared database.
      # By default, the prefix is the empty string.
      #
      # If you are organising your models within modules you can add a prefix to the models within
      # a namespace by defining a singleton method in the parent module called table_name_prefix which
      # returns your chosen prefix.
      class_attribute :table_name_prefix, :instance_writer => false
      self.table_name_prefix = ""

      ##
      # :singleton-method:
      # Works like +table_name_prefix+, but appends instead of prepends (set to "_basecamp" gives "projects_basecamp",
      # "people_basecamp"). By default, the suffix is the empty string.
      class_attribute :table_name_suffix, :instance_writer => false
      self.table_name_suffix = ""

      ##
      # :singleton-method:
      # Indicates whether table names should be the pluralized versions of the corresponding class names.
      # If true, the default table name for a Product class will be +products+. If false, it would just be +product+.
      # See table_name for the full rules on table/class naming. This is true, by default.
      class_attribute :pluralize_table_names, :instance_writer => false
      self.pluralize_table_names = true

      def table_name
        symbolized_attributes = attributes.symbolize_keys
        return self.class.table_name(*self.class.table_partition_keys.map{|attribute_name| symbolized_attributes[attribute_name]})
      end
    end

    module ClassMethods
      # Guesses the table name (in forced lower-case) based on the name of the class in the
      # inheritance hierarchy descending directly from ActiveRecord::Base. So if the hierarchy
      # looks like: Reply < Message < ActiveRecord::Base, then Message is used
      # to guess the table name even when called on Reply. The rules used to do the guess
      # are handled by the Inflector class in Active Support, which knows almost all common
      # English inflections. You can add new inflections in config/initializers/inflections.rb.
      #
      # Nested classes are given table names prefixed by the singular form of
      # the parent's table name. Enclosing modules are not considered.
      #
      # ==== Examples
      #
      #   class Invoice < ActiveRecord::Base
      #   end
      #
      #   file                  class               table_name
      #   invoice.rb            Invoice             invoices
      #
      #   class Invoice < ActiveRecord::Base
      #     class Lineitem < ActiveRecord::Base
      #     end
      #   end
      #
      #   file                  class               table_name
      #   invoice.rb            Invoice::Lineitem   invoice_lineitems
      #
      #   module Invoice
      #     class Lineitem < ActiveRecord::Base
      #     end
      #   end
      #
      #   file                  class               table_name
      #   invoice/lineitem.rb   Invoice::Lineitem   lineitems
      #
      # Additionally, the class-level +table_name_prefix+ is prepended and the
      # +table_name_suffix+ is appended. So if you have "myapp_" as a prefix,
      # the table name guess for an Invoice class becomes "myapp_invoices".
      # Invoice::Lineitem becomes "myapp_invoice_lineitems".
      #
      # You can also set your own table name explicitly:
      #
      #   class Mouse < ActiveRecord::Base
      #     self.table_name = "mice"
      #   end
      #
      # Alternatively, you can override the table_name method to define your
      # own computation. (Possibly using <tt>super</tt> to manipulate the default
      # table name.) Example:
      #
      #   class Post < ActiveRecord::Base
      #     def self.table_name
      #       "special_" + super
      #     end
      #   end
      #   Post.table_name # => "special_posts"
      def table_name(*table_partition_key_values)
        reset_table_name unless defined?(@table_name)
        @table_name
      end

      def original_table_name #:nodoc:
        deprecated_original_property_getter :table_name
      end

      # Sets the table name explicitly. Example:
      #
      #   class Project < ActiveRecord::Base
      #     self.table_name = "project"
      #   end
      #
      # You can also just define your own <tt>self.table_name</tt> method; see
      # the documentation for ActiveRecord::Base#table_name.
      def table_name=(value)
        @original_table_name = @table_name if defined?(@table_name)
        @table_name          = value && value.to_s
        @quoted_table_name   = nil
        reset_arel_table
        @relation            = Relation.new(self, arel_table)
      end

      def set_table_name(value = nil, &block) #:nodoc:
        deprecated_property_setter :table_name, value, block
        @quoted_table_name = nil
        reset_arel_table
        @relation          = Relation.new(self, arel_table)
      end

      #
      # Returns an array of attribute names (strings) used to fetch the key value(s)
      # the determine this specific partition table.
      #
      # @return [String] the column name used to partition this table
      # @return [Array<String>] the column names used to partition this table
      def table_partition_keys
        return []
      end

      #
      # The specific values for a partition of this active record's type which are defined by
      # {#self.table_partition_keys}
      #
      # @param [Hash] values key/value pairs to extract values from
      # @return [Object] value of partition key
      # @return [Array<Object>] values of partition keys
      def table_partition_key_values(values)
        symbolized_values = values.symbolize_keys
        return self.table_partition_keys.map{|key| symbolized_values[key.to_sym]}
      end

      #
      # This scoping is used to target the
      # active record find() to a specific child table and alias it to the name of the
      # parent table (so activerecord can generally work with it)
      #
      # Use as:
      #
      #   Foo.from_partition(KEY).find(:first)
      #
      # where KEY is the key value(s) used as the check constraint on Foo's table.
      #
      # @param [*Array<Object>] partition_field the field values to partition on
      # @return [Hash] the scoping
      def from_partition(*partition_field)
        table_alias_name = table_alias_name(*partition_field)
        from("#{table_name(*partition_field)} AS #{table_alias_name}").
          tap{|relation| relation.table.table_alias = table_alias_name}
      end

      #
      # This scope is used to target the
      # active record find() to a specific child table. Is probably best used in advanced
      # activerecord queries when a number of tables are involved in the query.
      #
      # Use as:
      #
      #   Foo.from_partitioned_without_alias(KEY).find(:all, :select => "*")
      #
      # where KEY is the key value(s) used as the check constraint on Foo's table.
      #
      # it's not obvious why :select => "*" is supplied.  note activerecord wants
      # to use the name of parent table for access to any attributes, so without
      # the :select argument the sql result would be something like:
      #
      #   SELECT foos.* FROM foos_partitions.pXXX
      #
      # which fails because table foos is not referenced.  using the form #from_partition
      # is almost always the correct thing when using activerecord.
      #
      # Because the scope is specific to a class (a class method) but unlike
      # class methods is not inherited, one  must use this form (#from_partitioned_without_alias) instead
      # of #from_partitioned_without_alias_scope to get the most derived classes specific active record scope.
      #
      # @param [*Array<Object>] partition_field the field values to partition on
      # @return [Hash] the scoping
      def from_partitioned_without_alias(*partition_field)
        table_alias_name = table_name(*partition_field)
        from(table_alias_name).
          tap{|relation| relation.table.table_alias = table_alias_name}
      end

      def table_alias_name(*partition_field)
        return table_name(*partition_field)
      end

      #
      # partitioning needs to be able to specify if 
      # we should prefetch the primary key (to determine
      # the specific table we will insert in to we
      # need to know the partition key values.
      #
      # this needs to be on the model NOT the connection
      #
      # for the simple case we just pass the question on to
      # the connection
      def prefetch_primary_key?
        connection.prefetch_primary_key?(table_name)
      end

      # Returns a quoted version of the table name, used to construct SQL statements.
      def quoted_table_name
        @quoted_table_name ||= connection.quote_table_name(table_name)
      end

      # Computes the table name, (re)sets it internally, and returns it.
      def reset_table_name #:nodoc:
        if abstract_class?
          self.table_name = if superclass == Base || superclass.abstract_class?
                              nil
                            else
                              superclass.table_name
                            end
        elsif superclass.abstract_class?
          self.table_name = superclass.table_name || compute_table_name
        else
          self.table_name = compute_table_name
        end
      end

      def full_table_name_prefix #:nodoc:
        (parents.detect{ |p| p.respond_to?(:table_name_prefix) } || self).table_name_prefix
      end

      # The name of the column containing the object's class when Single Table Inheritance is used
      def inheritance_column
        if self == Base
          'type'
        else
          (@inheritance_column ||= nil) || superclass.inheritance_column
        end
      end

      def original_inheritance_column #:nodoc:
        deprecated_original_property_getter :inheritance_column
      end

      # Sets the value of inheritance_column
      def inheritance_column=(value)
        @original_inheritance_column = inheritance_column
        @inheritance_column          = value.to_s
      end

      def set_inheritance_column(value = nil, &block) #:nodoc:
        deprecated_property_setter :inheritance_column, value, block
      end

      def sequence_name
        if base_class == self
          @sequence_name ||= reset_sequence_name
        else
          (@sequence_name ||= nil) || base_class.sequence_name
        end
      end

      def original_sequence_name #:nodoc:
        deprecated_original_property_getter :sequence_name
      end

      def reset_sequence_name #:nodoc:
        self.sequence_name = connection.default_sequence_name(table_name, primary_key)
      end

      # Sets the name of the sequence to use when generating ids to the given
      # value, or (if the value is nil or false) to the value returned by the
      # given block. This is required for Oracle and is useful for any
      # database which relies on sequences for primary key generation.
      #
      # If a sequence name is not explicitly set when using Oracle or Firebird,
      # it will default to the commonly used pattern of: #{table_name}_seq
      #
      # If a sequence name is not explicitly set when using PostgreSQL, it
      # will discover the sequence corresponding to your primary key for you.
      #
      #   class Project < ActiveRecord::Base
      #     self.sequence_name = "projectseq"   # default would have been "project_seq"
      #   end
      def sequence_name=(value)
        @original_sequence_name = @sequence_name if defined?(@sequence_name)
        @sequence_name          = value.to_s
      end

      def set_sequence_name(value = nil, &block) #:nodoc:
        deprecated_property_setter :sequence_name, value, block
      end

      # Indicates whether the table associated with this class exists
      def table_exists?
        connection.schema_cache.table_exists?(table_name)
      end

      # Returns an array of column objects for the table associated with this class.
      def columns
        @columns ||= connection.schema_cache.columns[table_name].map do |col|
          col = col.dup
          col.primary = (col.name == primary_key)
          col
        end
      end

      # Returns a hash of column objects for the table associated with this class.
      def columns_hash
        @columns_hash ||= Hash[columns.map { |c| [c.name, c] }]
      end

      # Returns a hash where the keys are column names and the values are
      # default values when instantiating the AR object for this table.
      def column_defaults
        @column_defaults ||= Hash[columns.map { |c| [c.name, c.default] }]
      end

      # Returns an array of column names as strings.
      def column_names
        @column_names ||= columns.map { |column| column.name }
      end

      # Returns an array of column objects where the primary id, all columns ending in "_id" or "_count",
      # and columns used for single table inheritance have been removed.
      def content_columns
        @content_columns ||= columns.reject { |c| c.primary || c.name =~ /(_id|_count)$/ || c.name == inheritance_column }
      end

      # Returns a hash of all the methods added to query each of the columns in the table with the name of the method as the key
      # and true as the value. This makes it possible to do O(1) lookups in respond_to? to check if a given method for attribute
      # is available.
      def column_methods_hash #:nodoc:
        @dynamic_methods_hash ||= column_names.inject(Hash.new(false)) do |methods, attr|
          attr_name = attr.to_s
          methods[attr.to_sym]       = attr_name
          methods["#{attr}=".to_sym] = attr_name
          methods["#{attr}?".to_sym] = attr_name
          methods["#{attr}_before_type_cast".to_sym] = attr_name
          methods
        end
      end

      # Resets all the cached information about columns, which will cause them
      # to be reloaded on the next request.
      #
      # The most common usage pattern for this method is probably in a migration,
      # when just after creating a table you want to populate it with some default
      # values, eg:
      #
      #  class CreateJobLevels < ActiveRecord::Migration
      #    def up
      #      create_table :job_levels do |t|
      #        t.integer :id
      #        t.string :name
      #
      #        t.timestamps
      #      end
      #
      #      JobLevel.reset_column_information
      #      %w{assistant executive manager director}.each do |type|
      #        JobLevel.create(:name => type)
      #      end
      #    end
      #
      #    def down
      #      drop_table :job_levels
      #    end
      #  end
      def reset_column_information
        connection.clear_cache!
        undefine_attribute_methods
        connection.schema_cache.clear_table_cache!(table_name) if table_exists?

        @column_names = @content_columns = @column_defaults = @columns = @columns_hash = nil
        @dynamic_methods_hash = @inheritance_column = nil
        @arel_engine = @relation = nil
      end

      def clear_cache! # :nodoc:
        connection.schema_cache.clear!
      end

      private

      # Guesses the table name, but does not decorate it with prefix and suffix information.
      def undecorated_table_name(class_name = base_class.name)
        table_name = class_name.to_s.demodulize.underscore
        table_name = table_name.pluralize if pluralize_table_names
        table_name
      end

      # Computes and returns a table name according to default conventions.
      def compute_table_name
        base = base_class
        if self == base
          # Nested classes are prefixed with singular parent table name.
          if parent < ActiveRecord::Base && !parent.abstract_class?
            contained = parent.table_name
            contained = contained.singularize if parent.pluralize_table_names
            contained += '_'
          end
          "#{full_table_name_prefix}#{contained}#{undecorated_table_name(name)}#{table_name_suffix}"
        else
          # STI subclasses always use their superclass' table.
          base.table_name
        end
      end

      def deprecated_property_setter(property, value, block)
        if block
          ActiveSupport::Deprecation.warn(
            "Calling set_#{property} is deprecated. If you need to lazily evaluate " \
            "the #{property}, define your own `self.#{property}` class method. You can use `super` " \
            "to get the default #{property} where you would have called `original_#{property}`."
          )

          define_attr_method property, value, false, &block
        else
          ActiveSupport::Deprecation.warn(
            "Calling set_#{property} is deprecated. Please use `self.#{property} = 'the_name'` instead."
          )

          define_attr_method property, value, false
        end
      end

      def deprecated_original_property_getter(property)
        ActiveSupport::Deprecation.warn("original_#{property} is deprecated. Define self.#{property} and call super instead.")

        if !instance_variable_defined?("@original_#{property}") && respond_to?("reset_#{property}")
          send("reset_#{property}")
        else
          instance_variable_get("@original_#{property}")
        end
      end
    end
  end
end
