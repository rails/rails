module ActiveRecord
  module WherePolymorphicExpectationsHelper

    # Wraps polymorphic conditions in parentheses
    def wrap_polymorphic(statement)
      statement.gsub(/WHERE\s(.+)\Z/) { "WHERE (#{$1})" }
    end
  end
end