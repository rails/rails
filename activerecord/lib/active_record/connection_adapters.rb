# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :AbstractAdapter
    end

    autoload :Column
    autoload :PoolConfig
    autoload :PoolManager
    autoload :LegacyPoolManager

    autoload_at "active_record/connection_adapters/abstract/schema_definitions" do
      autoload :IndexDefinition
      autoload :ColumnDefinition
      autoload :ChangeColumnDefinition
      autoload :ForeignKeyDefinition
      autoload :CheckConstraintDefinition
      autoload :TableDefinition
      autoload :Table
      autoload :AlterTable
      autoload :ReferenceDefinition
    end

    autoload_under "abstract" do
      autoload :SchemaStatements
      autoload :DatabaseStatements
      autoload :DatabaseLimits
      autoload :Quoting
      autoload :ConnectionHandler
      autoload :QueryCache
      autoload :Savepoints
    end

    autoload_at "active_record/connection_adapters/abstract/connection_pool" do
      autoload :ConnectionPool
      autoload :NullPool
    end

    autoload_at "active_record/connection_adapters/abstract/transaction" do
      autoload :TransactionManager
      autoload :NullTransaction
      autoload :RealTransaction
      autoload :SavepointTransaction
      autoload :TransactionState
    end
  end
end
