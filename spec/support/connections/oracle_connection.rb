puts "Using native Oracle"
require "active_record"
require 'logger'

ENV['ADAPTER'] = 'oracle'

# Prepend oracle_enhanced local development directory in front of load path
$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../../../oracle-enhanced/lib"

ActiveRecord::Base.configurations = {
  'unit' => {
    :adapter  => 'oracle_enhanced',
    :username => 'arel_unit',
    :password => 'arel_unit',
    :database => 'orcl',
  }
}
