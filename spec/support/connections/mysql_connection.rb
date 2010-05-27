puts "Using native MySQL"
require "active_record"
require 'logger'

ENV['ADAPTER'] = 'mysql'

ActiveRecord::Base.configurations = {
  'unit' => {
    :adapter  => 'mysql',
    :username => 'root',
    :encoding => 'utf8',
    :database => 'arel_unit',
  }
}
