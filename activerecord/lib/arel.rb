# frozen_string_literal: true

module Arel # :nodoc: all
  autoload :Crud,               "arel/crud"
  autoload :FactoryMethods,     "arel/factory_methods"
  autoload :Expressions,        "arel/expressions"
  autoload :Predications,       "arel/predications"
  autoload :WindowPredications, "arel/window_predications"
  autoload :Math,               "arel/math"
  autoload :AliasPredication,   "arel/alias_predication"
  autoload :OrderPredications,  "arel/order_predications"
  autoload :Table,              "arel/table"
  autoload :Attributes,         "arel/attributes"
  autoload :TreeManager,        "arel/tree_manager"
  autoload :InsertManager,      "arel/insert_manager"
  autoload :SelectManager,      "arel/select_manager"
  autoload :UpdateManager,      "arel/update_manager"
  autoload :DeleteManager,      "arel/delete_manager"

  module Compatibility
    autoload :Wheres, "arel/compatibility/wheres"
  end

  module Visitors
    autoload :Visitor,    "arel/visitors/visitor"
    autoload :DepthFirst, "arel/visitors/depth_first"
    autoload :ToSql,      "arel/visitors/to_sql"
    autoload :SQLite,     "arel/visitors/sqlite"
    autoload :PostgreSQL, "arel/visitors/postgresql"
    autoload :MySQL,      "arel/visitors/mysql"
    autoload :MSSQL,      "arel/visitors/mssql"
    autoload :Oracle,     "arel/visitors/oracle"
    autoload :Oracle12,   "arel/visitors/oracle12"
    autoload :WhereSql,   "arel/visitors/where_sql"
    autoload :Dot,        "arel/visitors/dot"
    autoload :IBM_DB,     "arel/visitors/ibm_db"
    autoload :Informix,   "arel/visitors/informix"
  end

  module Collectors
    autoload :Bind,            "arel/collectors/bind"
    autoload :Composite,       "arel/collectors/composite"
    autoload :PlainString,     "arel/collectors/plain_string"
    autoload :SQLString,       "arel/collectors/sql_string"
    autoload :SubstituteBinds, "arel/collectors/substitute_binds"
  end

  module Nodes
    ## Node
    autoload :Node,            "arel/nodes/node"
    autoload :NodeExpression,  "arel/nodes/node_expression"
    autoload :SelectStatement, "arel/nodes/select_statement"
    autoload :SelectCore,      "arel/nodes/select_core"
    autoload :InsertStatement, "arel/nodes/insert_statement"
    autoload :UpdateStatement, "arel/nodes/update_statement"
    autoload :BindParam,       "arel/nodes/bind_param"

    ## Terminal
    autoload :Distinct, "arel/nodes/terminal"
    autoload :True,     "arel/nodes/true"
    autoload :False,    "arel/nodes/false"

    ## Unary
    autoload :Unary,             "arel/nodes/unary"
    autoload :Grouping,          "arel/nodes/grouping"
    autoload :Ascending,         "arel/nodes/ascending"
    autoload :Descending,        "arel/nodes/descending"
    autoload :UnqualifiedColumn, "arel/nodes/unqualified_column"
    autoload :With,              "arel/nodes/with"

    ## Binary
    autoload :Binary,          "arel/nodes/binary"
    autoload :Equality,        "arel/nodes/equality"
    autoload :In,              "arel/nodes/in" # Why is this subclassed from equality?
    autoload :JoinSource,      "arel/nodes/join_source"
    autoload :DeleteStatement, "arel/nodes/delete_statement"
    autoload :TableAlias,      "arel/nodes/table_alias"
    autoload :InfixOperation,  "arel/nodes/infix_operation"
    autoload :UnaryOperation,  "arel/nodes/unary_operation"
    autoload :Over,            "arel/nodes/over"
    autoload :Matches,         "arel/nodes/matches"
    autoload :Regexp,          "arel/nodes/regexp"

    ## Nary
    autoload :And, "arel/nodes/and"

    ## Function
    # FIXME: Function + Alias can be rewritten as a Function and Alias node.
    # We should make Function a Unary node and deprecate the use of "aliaz"
    autoload :Function,      "arel/nodes/function"
    autoload :Count,         "arel/nodes/count"
    autoload :Extract,       "arel/nodes/extract"
    autoload :Values,        "arel/nodes/values"
    autoload :ValuesList,    "arel/nodes/values_list"
    autoload :NamedFunction, "arel/nodes/named_function"

    ## Windows
    autoload :Window, "arel/nodes/window"

    ## Conditional expressions
    autoload :Case, "arel/nodes/case"

    ## Joins
    autoload :FullOuterJoin,  "arel/nodes/full_outer_join"
    autoload :InnerJoin,      "arel/nodes/inner_join"
    autoload :OuterJoin,      "arel/nodes/outer_join"
    autoload :RightOuterJoin, "arel/nodes/right_outer_join"
    autoload :StringJoin,     "arel/nodes/string_join"

    autoload :SqlLiteral, "arel/nodes/sql_literal"
    autoload :Casted,     "arel/nodes/casted"
  end

  VERSION = "10.0.0"

  def self.sql(raw_sql)
    Arel::Nodes::SqlLiteral.new raw_sql
  end

  def self.star
    sql "*"
  end

  ## Convenience Alias
  Node = Arel::Nodes::Node

  ## Errors
  ArelError = Class.new(StandardError)
  EmptyJoinError = Class.new(ArelError)
end
