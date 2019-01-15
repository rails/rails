# frozen_string_literal: true

require "arel/errors"

require "arel/crud"
require "arel/factory_methods"

require "arel/expressions"
require "arel/predications"
require "arel/window_predications"
require "arel/math"
require "arel/alias_predication"
require "arel/order_predications"
require "arel/table"
require "arel/attributes"
require "arel/compatibility/wheres"

require "arel/visitors"
require "arel/collectors/sql_string"

require "arel/tree_manager"
require "arel/insert_manager"
require "arel/select_manager"
require "arel/update_manager"
require "arel/delete_manager"
require "arel/nodes"

module Arel # :nodoc: all
  VERSION = "10.0.0"

  def self.sql(raw_sql)
    Arel::Nodes::SqlLiteral.new raw_sql
  end

  def self.star
    sql "*"
  end

  def self.arel_node?(value)
    value.is_a?(Arel::Node) || value.is_a?(Arel::Attribute) || value.is_a?(Arel::Nodes::SqlLiteral)
  end

  ## Convenience Alias
  Node = Arel::Nodes::Node
end
