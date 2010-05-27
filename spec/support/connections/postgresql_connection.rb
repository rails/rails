puts "Using native PostgreSQL"
require "active_record"
require 'logger'

ENV['ADAPTER'] = 'postgresql'

ActiveRecord::Base.configurations = {
  'unit' => {
    :adapter  => 'postgresql',
    :encoding => 'utf8',
    :database => 'arel_unit',
  }
}
