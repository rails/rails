require 'arel/crud'

require 'arel/expressions'
require 'arel/predications'
require 'arel/table'
require 'arel/attributes'
require 'arel/compatibility/wheres'

#### these are deprecated
# The Arel::Relation constant is referenced in Rails
require 'arel/relation'
require 'arel/expression'
####

require 'arel/visitors'

require 'arel/tree_manager'
require 'arel/insert_manager'
require 'arel/select_manager'
require 'arel/update_manager'
require 'arel/delete_manager'
require 'arel/nodes'


#### these are deprecated
require 'arel/deprecated'
require 'arel/sql/engine'
require 'arel/sql_literal'
####

module Arel
  VERSION = '2.0.6'

  def self.sql raw_sql
    Arel::Nodes::SqlLiteral.new raw_sql
  end
  ## Convenience Alias
  Node = Arel::Nodes::Node
end
