# frozen_string_literal: true

require "arel/errors"

require "arel/crud"
require "arel/factory_methods"

require "arel/expressions"
require "arel/predications"
require "arel/filter_predications"
require "arel/window_predications"
require "arel/math"
require "arel/alias_predication"
require "arel/order_predications"
require "arel/table"
require "arel/attributes/attribute"

require "arel/visitors"
require "arel/collectors/sql_string"

require "arel/tree_manager"
require "arel/insert_manager"
require "arel/select_manager"
require "arel/update_manager"
require "arel/delete_manager"
require "arel/nodes"

module Arel
  VERSION = "10.0.0"

  # Wrap a known-safe SQL string for passing to query methods, e.g.
  #
  #   Post.order(Arel.sql("REPLACE(title, 'misc', 'zzzz') asc")).pluck(:id)
  #
  # Great caution should be taken to avoid SQL injection vulnerabilities.
  # This method should not be used with unsafe values such as request
  # parameters or model attributes.
  #
  # Take a look at the {security guide}[https://guides.rubyonrails.org/security.html#sql-injection]
  # for more information.
  #
  # To construct a more complex query fragment, including the possible
  # use of user-provided values, the +sql_string+ may contain <tt>?</tt> and
  # +:key+ placeholders, corresponding to the additional arguments. Note
  # that this behavior only applies when bind value parameters are
  # supplied in the call; without them, the placeholder tokens have no
  # special meaning, and will be passed through to the query as-is.
  #
  # The +:retryable+ option can be used to mark the SQL as safe to retry.
  # Use this option only if the SQL is idempotent, as it could be executed
  # more than once.
  def self.sql(sql_string, *positional_binds, retryable: false, **named_binds)
    if Arel::Nodes::SqlLiteral === sql_string
      sql_string
    elsif positional_binds.empty? && named_binds.empty?
      Arel::Nodes::SqlLiteral.new(sql_string, retryable: retryable)
    else
      Arel::Nodes::BoundSqlLiteral.new sql_string, positional_binds, named_binds
    end
  end

  def self.star # :nodoc:
    sql("*", retryable: true)
  end

  def self.arel_node?(value) # :nodoc:
    value.is_a?(Arel::Nodes::Node) || value.is_a?(Arel::Attribute) || value.is_a?(Arel::Nodes::SqlLiteral)
  end

  def self.fetch_attribute(value, &block) # :nodoc:
    unless String === value
      value.fetch_attribute(&block)
    end
  end
end
