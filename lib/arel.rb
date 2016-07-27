require 'arel/crud'
require 'arel/factory_methods'

require 'arel/expressions'
require 'arel/predications'
require 'arel/window_predications'
require 'arel/math'
require 'arel/alias_predication'
require 'arel/order_predications'
require 'arel/table'
require 'arel/attributes'
require 'arel/compatibility/wheres'

require 'arel/visitors'

require 'arel/tree_manager'
require 'arel/insert_manager'
require 'arel/select_manager'
require 'arel/update_manager'
require 'arel/delete_manager'
require 'arel/nodes'

module Arel
  VERSION = '7.1.1'

  def self.sql raw_sql
    Arel::Nodes::SqlLiteral.new raw_sql
  end

  def self.star
    sql '*'
  end
  ## Convenience Alias
  Node = Arel::Nodes::Node
end
