# frozen_string_literal: true

module ActiveRecord
  module Validations
    class UniquenessValidator < ActiveModel::EachValidator # :nodoc:
      def initialize(options)
        if options[:conditions] && !options[:conditions].respond_to?(:call)
          raise ArgumentError, "#{options[:conditions]} was passed as :conditions but is not callable. " \
                               "Pass a callable instead: `conditions: -> { where(approved: true) }`"
        end
        unless Array(options[:scope]).all? { |scope| scope.respond_to?(:to_sym) }
          raise ArgumentError, "#{options[:scope]} is not supported format for :scope option. " \
            "Pass a symbol or an array of symbols instead: `scope: :user_id`"
        end
        super
        @klass = options[:class]
        @klass = @klass.superclass if @klass.singleton_class?
      end

      def validate_each(record, attribute, value)
        finder_class = find_finder_class_for(record)
        value = map_enum_attribute(finder_class, attribute, value)

        return if record.persisted? && !validation_needed?(finder_class, record, attribute)

        relation = build_relation(finder_class, attribute, value)
        if record.persisted?
          if finder_class.primary_key
            relation = relation.where.not(finder_class.primary_key => [record.id_in_database])
          else
            raise UnknownPrimaryKey.new(finder_class, "Cannot validate uniqueness for persisted record without primary key.")
          end
        end
        relation = scope_relation(record, relation)

        if options[:conditions]
          conditions = options[:conditions]

          relation = if conditions.arity.zero?
            relation.instance_exec(&conditions)
          else
            relation.instance_exec(record, &conditions)
          end
        end

        if relation.exists?
          error_options = options.except(:case_sensitive, :scope, :conditions)
          error_options[:value] = value

          record.errors.add(attribute, :taken, **error_options)
        end
      end

    private
      # The check for an existing value should be run from a class that
      # isn't abstract. This means working down from the current class
      # (self), to the first non-abstract class.
      def find_finder_class_for(record)
        current_class = record.class
        found_class = nil
        loop do
          found_class = current_class unless current_class.abstract_class?
          break if current_class == @klass
          current_class = current_class.superclass
        end

        found_class
      end

      def validation_needed?(klass, record, attribute)
        return true if options[:conditions] || options.key?(:case_sensitive)

        scope = Array(options[:scope])
        attributes = scope + [attribute]
        attributes = resolve_attributes(record, attributes)

        return true if attributes.any? { |attr| record.attribute_changed?(attr) ||
                                                record.read_attribute(attr).nil? }

        !covered_by_unique_index?(klass, record, attribute, scope)
      end

      def covered_by_unique_index?(klass, record, attribute, scope)
        @covered ||= self.attributes.map(&:to_s).select do |attr|
          attributes = scope + [attr]
          attributes = resolve_attributes(record, attributes)

          klass.schema_cache.indexes(klass.table_name).any? do |index|
            index.unique &&
              index.where.nil? &&
              (Array(index.columns) - attributes).empty?
          end
        end

        @covered.include?(attribute.to_s)
      end

      def resolve_attributes(record, attributes)
        attributes.flat_map do |attribute|
          reflection = record.class._reflect_on_association(attribute)

          if reflection.nil?
            attribute.to_s
          elsif reflection.polymorphic?
            [reflection.foreign_key, reflection.foreign_type]
          else
            reflection.foreign_key
          end
        end
      end

      def build_relation(klass, attribute, value)
        relation = klass.unscoped
        # TODO: Add case-sensitive / case-insensitive operators to Arel
        # to no longer need to checkout a connection here.
        comparison = klass.with_connection do |connection|
          relation.bind_attribute(attribute, value) do |attr, bind|
            return relation.none! if bind.unboundable?

            if !options.key?(:case_sensitive) || bind.nil?
              connection.default_uniqueness_comparison(attr, bind)
            elsif options[:case_sensitive]
              connection.case_sensitive_comparison(attr, bind)
            else
              # will use SQL LOWER function before comparison, unless it detects a case insensitive collation
              connection.case_insensitive_comparison(attr, bind)
            end
          end
        end

        relation.where!(comparison)
      end

      def scope_relation(record, relation)
        Array(options[:scope]).each do |scope_item|
          scope_value = if record.class._reflect_on_association(scope_item)
            record.association(scope_item).reader
          else
            record.read_attribute(scope_item)
          end
          relation = relation.where(scope_item => scope_value)
        end

        relation
      end

      def map_enum_attribute(klass, attribute, value)
        mapping = klass.defined_enums[attribute.to_s]
        value = mapping[value] if value && mapping
        value
      end
    end

    module ClassMethods
      # Validates whether the value of the specified attributes are unique
      # across the system. Useful for making sure that only one user
      # can be named "davidhh".
      #
      #   class Person < ActiveRecord::Base
      #     validates_uniqueness_of :user_name
      #   end
      #
      # It can also validate whether the value of the specified attributes are
      # unique based on a <tt>:scope</tt> parameter:
      #
      #   class Person < ActiveRecord::Base
      #     validates_uniqueness_of :user_name, scope: :account_id
      #   end
      #
      # Or even multiple scope parameters. For example, making sure that a
      # teacher can only be on the schedule once per semester for a particular
      # class.
      #
      #   class TeacherSchedule < ActiveRecord::Base
      #     validates_uniqueness_of :teacher_id, scope: [:semester_id, :class_id]
      #   end
      #
      # It is also possible to limit the uniqueness constraint to a set of
      # records matching certain conditions. In this example archived articles
      # are not being taken into consideration when validating uniqueness
      # of the title attribute:
      #
      #   class Article < ActiveRecord::Base
      #     validates_uniqueness_of :title, conditions: -> { where.not(status: 'archived') }
      #   end
      #
      # To build conditions based on the record's state, define the conditions
      # callable with a parameter, which will be the record itself. This
      # example validates the title is unique for the year of publication:
      #
      #   class Article < ActiveRecord::Base
      #     validates_uniqueness_of :title, conditions: ->(article) {
      #       published_at = article.published_at
      #       where(published_at: published_at.beginning_of_year..published_at.end_of_year)
      #     }
      #   end
      #
      # When the record is created, a check is performed to make sure that no
      # record exists in the database with the given value for the specified
      # attribute (that maps to a column). When the record is updated,
      # the same check is made but disregarding the record itself.
      #
      # Configuration options:
      #
      # * <tt>:message</tt> - Specifies a custom error message (default is:
      #   "has already been taken").
      # * <tt>:scope</tt> - One or more columns by which to limit the scope of
      #   the uniqueness constraint.
      # * <tt>:conditions</tt> - Specify the conditions to be included as a
      #   <tt>WHERE</tt> SQL fragment to limit the uniqueness constraint lookup
      #   (e.g. <tt>conditions: -> { where(status: 'active') }</tt>).
      # * <tt>:case_sensitive</tt> - Looks for an exact match. Ignored by
      #   non-text columns. The default behavior respects the default database collation.
      # * <tt>:allow_nil</tt> - If set to +true+, skips this validation if the
      #   attribute is +nil+ (default is +false+).
      # * <tt>:allow_blank</tt> - If set to +true+, skips this validation if the
      #   attribute is blank (default is +false+).
      # * <tt>:if</tt> - Specifies a method, proc, or string to call to determine
      #   if the validation should occur (e.g. <tt>if: :allow_validation</tt>,
      #   or <tt>if: Proc.new { |user| user.signup_step > 2 }</tt>). The method,
      #   proc or string should return or evaluate to a +true+ or +false+ value.
      # * <tt>:unless</tt> - Specifies a method, proc, or string to call to
      #   determine if the validation should not occur (e.g. <tt>unless: :skip_validation</tt>,
      #   or <tt>unless: Proc.new { |user| user.signup_step <= 2 }</tt>). The
      #   method, proc, or string should return or evaluate to a +true+ or +false+
      #   value.
      #
      # === Concurrency and integrity
      #
      # Using this validation method in conjunction with
      # {ActiveRecord::Base#save}[rdoc-ref:Persistence#save]
      # does not guarantee the absence of duplicate record insertions, because
      # uniqueness checks on the application level are inherently prone to race
      # conditions. For example, suppose that two users try to post a Comment at
      # the same time, and a Comment's title must be unique. At the database-level,
      # the actions performed by these users could be interleaved in the following manner:
      #
      #               User 1                 |               User 2
      #  ------------------------------------+--------------------------------------
      #  # User 1 checks whether there's     |
      #  # already a comment with the title  |
      #  # 'My Post'. This is not the case.  |
      #  SELECT * FROM comments              |
      #  WHERE title = 'My Post'             |
      #                                      |
      #                                      | # User 2 does the same thing and also
      #                                      | # infers that their title is unique.
      #                                      | SELECT * FROM comments
      #                                      | WHERE title = 'My Post'
      #                                      |
      #  # User 1 inserts their comment.     |
      #  INSERT INTO comments                |
      #  (title, content) VALUES             |
      #  ('My Post', 'hi!')                  |
      #                                      |
      #                                      | # User 2 does the same thing.
      #                                      | INSERT INTO comments
      #                                      | (title, content) VALUES
      #                                      | ('My Post', 'hello!')
      #                                      |
      #                                      | # ^^^^^^
      #                                      | # Boom! We now have a duplicate
      #                                      | # title!
      #
      # The best way to work around this problem is to add a unique index to the database table using
      # {connection.add_index}[rdoc-ref:ConnectionAdapters::SchemaStatements#add_index].
      # In the rare case that a race condition occurs, the database will guarantee
      # the field's uniqueness.
      #
      # When the database catches such a duplicate insertion,
      # {ActiveRecord::Base#save}[rdoc-ref:Persistence#save] will raise an ActiveRecord::StatementInvalid
      # exception. You can either choose to let this error propagate (which
      # will result in the default \Rails exception page being shown), or you
      # can catch it and restart the transaction (e.g. by telling the user
      # that the title already exists, and asking them to re-enter the title).
      # This technique is also known as
      # {optimistic concurrency control}[https://en.wikipedia.org/wiki/Optimistic_concurrency_control].
      #
      # The bundled ActiveRecord::ConnectionAdapters distinguish unique index
      # constraint errors from other types of database errors by throwing an
      # ActiveRecord::RecordNotUnique exception. For other adapters you will
      # have to parse the (database-specific) exception message to detect such
      # a case.
      #
      # The following bundled adapters throw the ActiveRecord::RecordNotUnique exception:
      #
      # * ActiveRecord::ConnectionAdapters::Mysql2Adapter.
      # * ActiveRecord::ConnectionAdapters::TrilogyAdapter.
      # * ActiveRecord::ConnectionAdapters::SQLite3Adapter.
      # * ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.
      def validates_uniqueness_of(*attr_names)
        validates_with UniquenessValidator, _merge_attributes(attr_names)
      end
    end
  end
end
