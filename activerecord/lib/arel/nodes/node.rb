# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    # = Using +Arel::Nodes::Node+
    #
    # Active Record uses Arel to compose SQL statements. Instead of building SQL strings directly, it's building an
    # abstract syntax tree (AST) of the statement using various types of Arel::Nodes::Node. Each node represents a
    # fragment of a SQL statement.
    #
    # The intermediate representation allows Arel to compile the statement into the database's specific SQL dialect
    # only before sending it without having to care about the nuances of each database when building the statement.
    # It also allows easier composition of statements without having to resort to (brittle and unsafe) string manipulation.
    #
    # == Building constraints
    #
    # One of the most common use cases of Arel is generating constraints for +SELECT+ statements. To help with that,
    # most nodes include a couple of useful factory methods to create subtree structures for common constraints. For
    # a full list of those, please refer to Arel::Predications.
    #
    # The following example creates an equality constraint where the value of the name column on the users table
    # matches the value DHH.
    #
    #   users = Arel::Table.new(:users)
    #   constraint = users[:name].eq("DHH")
    #
    #   # => Arel::Nodes::Equality.new(
    #   #      Arel::Attributes::Attribute.new(users, "name"),
    #   #      Arel::Nodes::Casted.new(
    #   #        "DHH",
    #   #        Arel::Attributes::Attribute.new(users, "name")
    #   #      )
    #   #    )
    #
    # The resulting SQL fragment will look like this:
    #
    #   "users"."name" = 'DHH'
    #
    # The constraint fragments can be used with regular ActiveRecord::Relation objects instead of a Hash. The
    # following two examples show two ways of creating the same query.
    #
    #   User.where(name: 'DHH')
    #
    #   # SELECT "users".* FROM "users" WHERE "users"."name" = 'DHH'
    #
    #   users = User.arel_table
    #
    #   User.where(users[:name].eq('DHH'))
    #
    #   # SELECT "users".* FROM "users" WHERE "users"."name" = 'DHH'
    #
    # == Functions
    #
    # Arel comes with built-in support for SQL functions like +COUNT+, +SUM+, +MIN+, +MAX+, and +AVG+. The
    # Arel::Expressions module includes factory methods for the default functions.
    #
    #   employees = Employee.arel_table
    #
    #   Employee.select(employees[:department_id], employees[:salary].average).group(employees[:department_id])
    #
    #   # SELECT "employees"."department_id", AVG("employees"."salary")
    #   #   FROM "employees" GROUP BY "employees"."department_id"
    #
    # It’s also possible to use custom functions by using the Arel::Nodes::NamedFunction node type. It accepts a
    # function name and an array of parameters.
    #
    #   Arel::Nodes::NamedFunction.new('date_trunc', [Arel::Nodes.build_quoted('day'), User.arel_table[:created_at]])
    #
    #   # date_trunc('day', "users"."created_at")
    #
    # == Quoting & bind params
    #
    # Values that you pass to Arel nodes need to be quoted or wrapped in bind params. This ensures they are properly
    # converted into the correct format without introducing a possible SQL injection vulnerability. Most factory
    # methods (like +eq+, +gt+, +lteq+, …) quote passed values automatically. When not using a factory method, it’s
    # possible to convert a value and wrap it in an Arel::Nodes::Quoted node (if necessary) by calling +Arel::Nodes.
    # build_quoted+.
    #
    #   Arel::Nodes.build_quoted("foo") # 'foo'
    #   Arel::Nodes.build_quoted(12.3)  # 12.3
    #
    # Instead of quoting values and embedding them directly in the SQL statement, it’s also possible to create bind
    # params. This keeps the actual values outside of the statement and allows using the prepared statement feature
    # of some databases.
    #
    #   attribute = ActiveRecord::Relation::QueryAttribute.new(:name, "DHH", ActiveRecord::Type::String.new)
    #   Arel::Nodes::BindParam.new(attribute)
    #
    # When ActiveRecord runs the query, bind params are replaced by placeholders (like +$1+) and the values are passed
    # separately.
    #
    # == SQL Literals
    #
    # For cases where there is no way to represent a particular SQL fragment using Arel nodes, you can use an SQL
    # literal. SQL literals are strings that Arel will treat “as is”.
    #
    #   Arel.sql('LOWER("users"."name")').eq('dhh')
    #
    #   # LOWER("users"."name") = 'dhh'
    #
    # Please keep in mind that passing data as raw SQL literals might introduce a possible SQL injection. However,
    # `Arel.sql` supports binding parameters which will ensure proper quoting. This can be useful when you need to
    # control the exact SQL you run, but you still have potentially user-supplied values.
    #
    #   Arel.sql('LOWER("users"."name") = ?', 'dhh')
    #
    #   # LOWER("users"."name") = 'dhh'
    #
    # You can also combine SQL literals.
    #
    #   sql = Arel.sql('SELECT * FROM "users" WHERE ')
    #   sql += Arel.sql('LOWER("users"."name") = :name', name: 'dhh')
    #   sql += Arel.sql('AND "users"."age" > :age', age: 35)
    #
    #   # SELECT * FROM "users" WHERE LOWER("users"."name") = 'dhh' AND "users"."age" > '35'
    class Node
      include Arel::FactoryMethods

      ###
      # Factory method to create a Nodes::Not node that has the recipient of
      # the caller as a child.
      def not
        Nodes::Not.new self
      end

      ###
      # Factory method to create a Nodes::Grouping node that has an Nodes::Or
      # node as a child.
      def or(right)
        Nodes::Grouping.new Nodes::Or.new(self, right)
      end

      ###
      # Factory method to create an Nodes::And node.
      def and(right)
        Nodes::And.new [self, right]
      end

      def invert
        Arel::Nodes::Not.new(self)
      end

      # FIXME: this method should go away.  I don't like people calling
      # to_sql on non-head nodes.  This forces us to walk the AST until we
      # can find a node that has a "relation" member.
      #
      # Maybe we should just use `Table.engine`?  :'(
      def to_sql(engine = Table.engine)
        collector = Arel::Collectors::SQLString.new
        collector = engine.connection.visitor.accept self, collector
        collector.value
      end

      def fetch_attribute
      end

      def equality?; false; end
    end
  end
end
