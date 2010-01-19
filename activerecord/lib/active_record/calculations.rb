module ActiveRecord
  module Calculations #:nodoc:
    extend ActiveSupport::Concern

    module ClassMethods
      delegate :count, :average, :minimum, :maximum, :sum, :to => :scoped

      # This calculates aggregate values in the given column.  Methods for count, sum, average, minimum, and maximum have been added as shortcuts.
      # Options such as <tt>:conditions</tt>, <tt>:order</tt>, <tt>:group</tt>, <tt>:having</tt>, and <tt>:joins</tt> can be passed to customize the query.
      #
      # There are two basic forms of output:
      #   * Single aggregate value: The single value is type cast to Fixnum for COUNT, Float for AVG, and the given column's type for everything else.
      #   * Grouped values: This returns an ordered hash of the values and groups them by the <tt>:group</tt> option.  It takes either a column name, or the name
      #     of a belongs_to association.
      #
      #       values = Person.maximum(:age, :group => 'last_name')
      #       puts values["Drake"]
      #       => 43
      #
      #       drake  = Family.find_by_last_name('Drake')
      #       values = Person.maximum(:age, :group => :family) # Person belongs_to :family
      #       puts values[drake]
      #       => 43
      #
      #       values.each do |family, max_age|
      #       ...
      #       end
      #
      # Options:
      # * <tt>:conditions</tt> - An SQL fragment like "administrator = 1" or [ "user_name = ?", username ]. See conditions in the intro to ActiveRecord::Base.
      # * <tt>:include</tt>: Eager loading, see Associations for details.  Since calculations don't load anything, the purpose of this is to access fields on joined tables in your conditions, order, or group clauses.
      # * <tt>:joins</tt> - An SQL fragment for additional joins like "LEFT JOIN comments ON comments.post_id = id". (Rarely needed).
      #   The records will be returned read-only since they will have attributes that do not correspond to the table's columns.
      # * <tt>:order</tt> - An SQL fragment like "created_at DESC, name" (really only used with GROUP BY calculations).
      # * <tt>:group</tt> - An attribute name by which the result should be grouped. Uses the GROUP BY SQL-clause.
      # * <tt>:select</tt> - By default, this is * as in SELECT * FROM, but can be changed if you for example want to do a join, but not
      #   include the joined columns.
      # * <tt>:distinct</tt> - Set this to true to make this a distinct calculation, such as SELECT COUNT(DISTINCT posts.id) ...
      #
      # Examples:
      #   Person.calculate(:count, :all) # The same as Person.count
      #   Person.average(:age) # SELECT AVG(age) FROM people...
      #   Person.minimum(:age, :conditions => ['last_name != ?', 'Drake']) # Selects the minimum age for everyone with a last name other than 'Drake'
      #   Person.minimum(:age, :having => 'min(age) > 17', :group => :last_name) # Selects the minimum age for any family without any minors
      #   Person.sum("2 * age")
      def calculate(operation, column_name, options = {})
        construct_calculation_arel(options).calculate(operation, column_name, options.slice(:distinct))
      rescue ThrowResult
        0
      end

      private

      def construct_calculation_arel(options = {})
        relation = scoped.apply_finder_options(options.except(:distinct))
        (relation.eager_loading? || relation.includes_values.present?) ? relation.send(:construct_relation_for_association_calculations) : relation
      end

    end
  end
end
