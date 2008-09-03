module ActiveModel
  module Validations
    module ClassMethods
      # Validates whether the value of the specified attributes are unique across the system. Useful for making sure that only one user
      # can be named "davidhh".
      #
      #   class Person < ActiveRecord::Base
      #     validates_uniqueness_of :user_name, :scope => :account_id
      #   end
      #
      # It can also validate whether the value of the specified attributes are unique based on multiple scope parameters.  For example,
      # making sure that a teacher can only be on the schedule once per semester for a particular class.
      #
      #   class TeacherSchedule < ActiveRecord::Base
      #     validates_uniqueness_of :teacher_id, :scope => [:semester_id, :class_id]
      #   end
      #
      # When the record is created, a check is performed to make sure that no record exists in the database with the given value for the specified
      # attribute (that maps to a column). When the record is updated, the same check is made but disregarding the record itself.
      #
      # Because this check is performed outside the database there is still a chance that duplicate values
      # will be inserted in two parallel transactions.  To guarantee against this you should create a 
      # unique index on the field. See +add_index+ for more information.
      #
      # Configuration options:
      # * <tt>:message</tt> - Specifies a custom error message (default is: "has already been taken")
      # * <tt>:scope</tt> - One or more columns by which to limit the scope of the uniqueness constraint.
      # * <tt>:case_sensitive</tt> - Looks for an exact match.  Ignored by non-text columns (+true+ by default).
      # * <tt>:allow_nil</tt> - If set to +true+, skips this validation if the attribute is +nil+ (default is: +false+)
      # * <tt>:allow_blank</tt> - If set to +true+, skips this validation if the attribute is blank (default is: +false+)
      # * <tt>:if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. <tt>:if => :allow_validation</tt>, or <tt>:if => Proc.new { |user| user.signup_step > 2 }</tt>).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>:unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. <tt>:unless => :skip_validation</tt>, or <tt>:unless => Proc.new { |user| user.signup_step <= 2 }</tt>).  The
      #   method, proc or string should return or evaluate to a true or false value.
      def validates_uniqueness_of(*attr_names)
        configuration = { :message => ActiveRecord::Errors.default_error_messages[:taken] }
        configuration.update(attr_names.extract_options!)

        validates_each(attr_names,configuration) do |record, attr_name, value|
          # The check for an existing value should be run from a class that
          # isn't abstract. This means working down from the current class
          # (self), to the first non-abstract class. Since classes don't know
          # their subclasses, we have to build the hierarchy between self and
          # the record's class.
          class_hierarchy = [record.class]
          while class_hierarchy.first != self
            class_hierarchy.insert(0, class_hierarchy.first.superclass)
          end

          # Now we can work our way down the tree to the first non-abstract
          # class (which has a database table to query from).
          finder_class = class_hierarchy.detect { |klass| !klass.abstract_class? }

          if value.nil? || (configuration[:case_sensitive] || !finder_class.columns_hash[attr_name.to_s].text?)
            condition_sql = "#{record.class.quoted_table_name}.#{attr_name} #{attribute_condition(value)}"
            condition_params = [value]
          else
            # sqlite has case sensitive SELECT query, while MySQL/Postgresql don't.
            # Hence, this is needed only for sqlite.
            condition_sql = "LOWER(#{record.class.quoted_table_name}.#{attr_name}) #{attribute_condition(value)}"
            condition_params = [value.downcase]
          end

          if scope = configuration[:scope]
            Array(scope).map do |scope_item|
              scope_value = record.send(scope_item)
              condition_sql << " AND #{record.class.quoted_table_name}.#{scope_item} #{attribute_condition(scope_value)}"
              condition_params << scope_value
            end
          end

          unless record.new_record?
            condition_sql << " AND #{record.class.quoted_table_name}.#{record.class.primary_key} <> ?"
            condition_params << record.send(:id)
          end

          results = finder_class.with_exclusive_scope do
            connection.select_all(
              construct_finder_sql(
                :select     => attr_name,
                :from       => finder_class.quoted_table_name,
                :conditions => [condition_sql, *condition_params]
              )
            )
          end

          unless results.length.zero?
            found = true

            # As MySQL/Postgres don't have case sensitive SELECT queries, we try to find duplicate
            # column in ruby when case sensitive option
            if configuration[:case_sensitive] && finder_class.columns_hash[attr_name.to_s].text?
              found = results.any? { |a| a[attr_name.to_s] == value }
            end

            record.errors.add(attr_name, configuration[:message]) if found
          end
        end
      end
    end
  end
end
