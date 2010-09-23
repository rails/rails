require 'arel/visitors/to_sql'
require 'arel/visitors/postgresql'
require 'arel/visitors/mysql'
require 'arel/visitors/join_sql'
require 'arel/visitors/order_clauses'
require 'arel/visitors/dot'

module Arel
  module Visitors
    VISITORS = {
      'postgresql' => Arel::Visitors::PostgreSQL,
      'mysql'      => Arel::Visitors::MySQL,
      'mysql2'     => Arel::Visitors::MySQL,
    }

    ENGINE_VISITORS = Hash.new do |hash, engine|
      pool         = engine.connection_pool
      adapter      = pool.spec.config[:adapter]
      hash[engine] = (VISITORS[adapter] || Visitors::ToSql).new(engine)
    end

    def self.visitor_for engine
      ENGINE_VISITORS[engine]
    end
  end
end
