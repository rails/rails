# :markup: markdown
# frozen_string_literal: true

module ActiveRecord
  module Type
    # Include this module in an attribute type to customize the SQL expression
    # used to compare values of that type in Active Record predicates.
    #
    # For example, a text type can compare through the normalized expression
    # used by a database expression index:
    #
    #     def comparison_expression(expression)
    #       Arel::Nodes::NamedFunction.new("lower", [expression])
    #     end
    #
    # Active Record compares values of the type by applying the expression
    # symmetrically to the stored attribute and query value. Ruby values are
    # serialized first; Arel expressions are not. `IS NULL` tests apply to the
    # transformed attribute, and subquery projections are treated as stored
    # values and transformed as well. Association join constraints compare two
    # stored attributes. Each side is transformed through its own column's type.
    # The expression defines equality, ordering, and null semantics for the type.
    # Type authors are responsible for ensuring those semantics are appropriate
    # and supported by the database.
    #
    # Ordering compares through the same expression: `order` on an attribute
    # sorts by the transformed value, as do `in_order_of` and batch cursors.
    # Writes use `serialize` without applying the comparison expression;
    # `group` and aggregate calculations use the stored attribute.
    module QueryPredicates
      def query_predicates? # :nodoc:
        true
      end

      # Converts a stored attribute or serialized query value into the
      # expression on which comparisons are performed.
      def comparison_expression(expression)
        expression
      end

      # Include in a representation-preserving type decorator that exposes its
      # wrapped type as `subtype`.
      module Decorator
        include QueryPredicates

        def query_predicates?
          QueryPredicates.type?(subtype)
        end

        def comparison_expression(expression)
          subtype.comparison_expression(expression)
        end
      end

      module NormalizedValueTypeDecorator # :nodoc:
        include Decorator

        def subtype
          cast_type
        end
      end

      def self.type?(type) # :nodoc:
        self === type && type.query_predicates?
      end
    end
  end
end
