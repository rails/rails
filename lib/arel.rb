require 'arel/crud'

require 'arel/version'
require 'arel/table'
require 'arel/attributes'

#### these are deprecated
# The Arel::Relation constant is referenced in Rails
require 'arel/relation'
####

require 'arel/tree_manager'
require 'arel/insert_manager'
require 'arel/select_manager'
require 'arel/update_manager'
require 'arel/nodes'

#### these are deprecated
require 'arel/sql/engine'
require 'arel/sql_literal'
####

require 'arel/visitors/to_sql'
require 'arel/visitors/dot'
