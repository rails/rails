# encoding: utf-8

gem 'activerecord-jdbcmysql-adapter'
require 'arjdbc/mysql'

module ActiveRecord::ConnectionAdapters

  class MysqlAdapter < JdbcAdapter

    def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [])
      sql, binds = sql_for_insert(sql, pk, id_value, sequence_name, binds)
      id      = exec_insert(sql, name, binds)
      id_value || id
    end

    protected

    def exec_insert(sql, name, binds)
      binds = binds.dup

      # Pretend to support bind parameters
      execute sql.gsub('?') { quote(*binds.shift.reverse) }, name
    end


  end
end