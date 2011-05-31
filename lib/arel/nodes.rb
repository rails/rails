# node
require 'arel/nodes/node'
require 'arel/nodes/select_statement'
require 'arel/nodes/select_core'
require 'arel/nodes/insert_statement'
require 'arel/nodes/update_statement'

# terminal

require 'arel/nodes/terminal'
require 'arel/nodes/true'
require 'arel/nodes/false'

# unary
require 'arel/nodes/unary'
require 'arel/nodes/ascending'
require 'arel/nodes/descending'
require 'arel/nodes/unqualified_column'
require 'arel/nodes/with'

# binary
require 'arel/nodes/binary'
require 'arel/nodes/equality'
require 'arel/nodes/in' # Why is this subclassed from equality?
require 'arel/nodes/join_source'
require 'arel/nodes/delete_statement'
require 'arel/nodes/table_alias'
require 'arel/nodes/infix_operation'

# nary
require 'arel/nodes/and'

# function
# FIXME: Function + Alias can be rewritten as a Function and Alias node.
# We should make Function a Unary node and deprecate the use of "aliaz"
require 'arel/nodes/function'
require 'arel/nodes/count'
require 'arel/nodes/values'
require 'arel/nodes/named_function'

# joins
require 'arel/nodes/inner_join'
require 'arel/nodes/outer_join'
require 'arel/nodes/string_join'

require 'arel/nodes/sql_literal'
