$:.unshift(File.dirname(__FILE__))

require 'active_record/support/clean_logger'

require 'active_record/base'
require 'active_record/observer'
require 'active_record/validations'
require 'active_record/callbacks'
require 'active_record/associations'
require 'active_record/aggregations'
require 'active_record/transactions'
require 'active_record/reflection'

ActiveRecord::Base.class_eval do
  include ActiveRecord::Validations
  include ActiveRecord::Callbacks
  include ActiveRecord::Associations
  include ActiveRecord::Aggregations
  include ActiveRecord::Transactions
  include ActiveRecord::Reflection
end

require 'active_record/connection_adapters/mysql_adapter'
require 'active_record/connection_adapters/postgresql_adapter'
require 'active_record/connection_adapters/sqlite_adapter'