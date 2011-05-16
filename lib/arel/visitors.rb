require 'arel/visitors/visitor'
require 'arel/visitors/depth_first'
require 'arel/visitors/to_sql'
require 'arel/visitors/sqlite'
require 'arel/visitors/postgresql'
require 'arel/visitors/mysql'
require 'arel/visitors/mssql'
require 'arel/visitors/oracle'
require 'arel/visitors/join_sql'
require 'arel/visitors/where_sql'
require 'arel/visitors/order_clauses'
require 'arel/visitors/dot'
require 'arel/visitors/ibm_db'
require 'arel/visitors/informix'

module Arel
  module Visitors
    VISITORS = {
      'postgresql'      => Arel::Visitors::PostgreSQL,
      'mysql'           => Arel::Visitors::MySQL,
      'mysql2'          => Arel::Visitors::MySQL,
      'mssql'           => Arel::Visitors::MSSQL,
      'sqlserver'       => Arel::Visitors::MSSQL,
      'oracle_enhanced' => Arel::Visitors::Oracle,
      'sqlite'          => Arel::Visitors::SQLite,
      'sqlite3'         => Arel::Visitors::SQLite,
      'ibm_db'          => Arel::Visitors::IBM_DB,
      'informix'        => Arel::Visitors::Informix,
    }

    ENGINE_VISITORS = Hash.new do |hash, engine|
      pool         = engine.connection_pool
      adapter      = pool.spec.config[:adapter]
      hash[engine] = (VISITORS[adapter] || Visitors::ToSql).new(engine)
    end

    def self.visitor_for engine
      ENGINE_VISITORS[engine]
    end
    class << self; alias :for :visitor_for; end
  end
end
