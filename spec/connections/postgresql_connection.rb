puts "Using native PostgreSQL"
require "active_record"
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

ActiveRecord::Base.configurations = {
  'unit' => {
    :adapter  => 'postgresql',
    :encoding => 'utf8',
    :database => 'arel_unit',
  }
}

ActiveRecord::Base.establish_connection 'unit'
