# frozen_string_literal: true

# node
require "arel/nodes/node"
require "arel/nodes/node_expression"
require "arel/nodes/select_statement"
require "arel/nodes/select_core"
require "arel/nodes/insert_statement"
require "arel/nodes/update_statement"
require "arel/nodes/bind_param"
require "arel/nodes/fragments"

# terminal

require "arel/nodes/terminal"
require "arel/nodes/true"
require "arel/nodes/false"

# unary
require "arel/nodes/unary"
require "arel/nodes/grouping"
require "arel/nodes/homogeneous_in"
require "arel/nodes/ordering"
require "arel/nodes/ascending"
require "arel/nodes/descending"
require "arel/nodes/unqualified_column"
require "arel/nodes/with"

# binary
require "arel/nodes/binary"
require "arel/nodes/equality"
require "arel/nodes/filter"
require "arel/nodes/in"
require "arel/nodes/join_source"
require "arel/nodes/delete_statement"
require "arel/nodes/table_alias"
require "arel/nodes/infix_operation"
require "arel/nodes/unary_operation"
require "arel/nodes/over"
require "arel/nodes/matches"
require "arel/nodes/regexp"
require "arel/nodes/cte"

# nary
require "arel/nodes/and"

# function
# FIXME: Function + Alias can be rewritten as a Function and Alias node.
# We should make Function a Unary node and deprecate the use of "aliaz"
require "arel/nodes/function"
require "arel/nodes/count"
require "arel/nodes/extract"
require "arel/nodes/values_list"
require "arel/nodes/named_function"

# windows
require "arel/nodes/window"

# conditional expressions
require "arel/nodes/case"

# joins
require "arel/nodes/full_outer_join"
require "arel/nodes/inner_join"
require "arel/nodes/outer_join"
require "arel/nodes/right_outer_join"
require "arel/nodes/string_join"
require "arel/nodes/leading_join"

require "arel/nodes/comment"

require "arel/nodes/sql_literal"
require "arel/nodes/bound_sql_literal"

require "arel/nodes/casted"
