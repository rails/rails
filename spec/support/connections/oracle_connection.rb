puts "Using native Oracle"
require "active_record"
require 'logger'

# Prepend oracle_enhanced local development directory in front of load path
$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../../../oracle-enhanced/lib"

ActiveRecord::Base.logger = Logger.new("debug.log")

ActiveRecord::Base.configurations = {
  'unit' => {
    :adapter  => 'oracle_enhanced',
    :username => 'arel_unit',
    :password => 'arel_unit',
    :database => 'orcl',
  }
}

ActiveRecord::Base.establish_connection 'unit'
