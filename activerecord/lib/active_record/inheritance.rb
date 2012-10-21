
module ActiveRecord
  ActiveSupport.on_load(:active_record_config) do
    # Determine whether to store the full constant name including namespace when using STI
    mattr_accessor :store_full_sti_class, instance_accessor: false
    self.store_full_sti_class = true
  end

  module Inheritance
    extend ActiveSupport::Concern

    included do
      config_attribute :store_full_sti_class
    end

    module ClassMethods
      # True if this isn't a concrete subclass needing a STI type condition.
      def descends_from_active_record?
        sup = active_record_super

        if sup.abstract_class?
          sup.descends_from_active_record?
        elsif self == Base
          false
        else
          [Base, Model].include?(sup) || !columns_hash.include?(inheritance_column)
        end
      end

      def finder_needs_type_condition? #:nodoc:
        # This is like this because benchmarking justifies the strange :false stuff
        :true == (@finder_needs_type_condition ||= descends_from_active_record? ? :false : :true)
      end

      def symbolized_base_class
        @symbolized_base_class ||= base_class.to_s.to_sym
      end

      def symbolized_sti_name
        @symbolized_sti_name ||= sti_name.present? ? sti_name.to_sym : symbolized_base_class
      end

      # Returns the class descending directly from ActiveRecord::Base (or
      # that includes ActiveRecord::Model), or an  abstract class, if any, in
      # the inheritance hierarchy.
      #
      # If A extends AR::Base, A.base_class will return A. If B descends from A
      # through some arbitrarily deep hierarchy, B.base_class will return A.
      #
      # If B < A and C < B and if A is an abstract_class then both B.base_class
      # and C.base_class would return B as the answer since A is an abstract_class.
      def base_class
        unless self < ActiveRecord::Tag
          raise ActiveRecordError, "#{name} doesn't belong in a hierarchy descending from ActiveRecord"
        end

        sup = active_record_super
        if sup == Base || sup == Model || sup.abstract_class?
          self
        else
          sup.base_class
        end
      end

      # Set this to true if this is an abstract class (see <tt>abstract_class?</tt>).
      # If you are using inheritance with ActiveRecord and don't want child classes
      # to utilize the implied STI table name of the parent class, this will need to be true.
      # For example, given the following:
      #
      #   class SuperClass < ActiveRecord::Base
      #     self.abstract_class = true
      #   end
      #   class Child < SuperClass
      #     self.table_name = 'the_table_i_really_want'
      #   end
      #
      #
      # <tt>self.abstract_class = true</tt> is required to make <tt>Child<.find,.create, or any Arel method></tt> use <tt>the_table_i_really_want</tt> instead of a table called <tt>super_classes</tt>
      #
      attr_accessor :abstract_class

      # Returns whether this class is an abstract class or not.
      def abstract_class?
        defined?(@abstract_class) && @abstract_class == true
      end

      def sti_name
        store_full_sti_class ? name : name.demodulize
      end

      # Finder methods must instantiate through this method to work with the
      # single-table inheritance model that makes it possible to create
      # objects of different types from the same table.
      def instantiate(record, column_types = {})
        sti_class    = find_sti_class(record[inheritance_column])
        column_types = sti_class.decorate_columns(column_types)
        sti_class.allocate.init_with('attributes' => record, 'column_types' => column_types)
      end

      # For internal use.
      #
      # If this class includes ActiveRecord::Model then it won't have a
      # superclass. So this provides a way to get to the 'root' (ActiveRecord::Model).
      def active_record_super #:nodoc:
        superclass < Model ? superclass : Model
      end

      protected

      # Returns the class type of the record using the current module as a prefix. So descendants of
      # MyApp::Business::Account would appear as MyApp::Business::AccountSubclass.
      def compute_type(type_name)
        if type_name.match(/^::/)
          # If the type is prefixed with a scope operator then we assume that
          # the type_name is an absolute reference.
          ActiveSupport::Dependencies.constantize(type_name)
        else
          # Build a list of candidates to search for
          candidates = []
          name.scan(/::|$/) { candidates.unshift "#{$`}::#{type_name}" }
          candidates << type_name

          candidates.each do |candidate|
            begin
              constant = ActiveSupport::Dependencies.constantize(candidate)
              return constant if candidate == constant.to_s
            rescue NameError => e
              # We don't want to swallow NoMethodError < NameError errors
              raise e unless e.instance_of?(NameError)
            end
          end

          raise NameError, "uninitialized constant #{candidates.first}"
        end
      end

      private

      def find_sti_class(type_name)
        if type_name.blank? || !columns_hash.include?(inheritance_column)
          self
        else
          begin
            if store_full_sti_class
              ActiveSupport::Dependencies.constantize(type_name)
            else
              compute_type(type_name)
            end
          rescue NameError
            raise SubclassNotFound,
              "The single-table inheritance mechanism failed to locate the subclass: '#{type_name}'. " +
              "This error is raised because the column '#{inheritance_column}' is reserved for storing the class in case of inheritance. " +
              "Please rename this column if you didn't intend it to be used for storing the inheritance class " +
              "or overwrite #{name}.inheritance_column to use another column for that information."
          end
        end
      end

      def type_condition(table = arel_table)
        sti_column = table[inheritance_column.to_sym]
        sti_names  = ([self] + descendants).map { |model| model.sti_name }

        sti_column.in(sti_names)
      end
    end

    private

    # Sets the attribute used for single table inheritance to this class name if this is not the
    # ActiveRecord::Base descendant.
    # Considering the hierarchy Reply < Message < ActiveRecord::Base, this makes it possible to
    # do Reply.new without having to set <tt>Reply[Reply.inheritance_column] = "Reply"</tt> yourself.
    # No such attribute would be set for objects of the Message class in that example.
    def ensure_proper_type
      klass = self.class
      if klass.finder_needs_type_condition?
        write_attribute(klass.inheritance_column, klass.sti_name)
      end
    end
  end
end
