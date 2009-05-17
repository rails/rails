require "activerecord"
puts "Using native PostgreSQL"

ActiveRecord::Base.configurations = {
  'unit' => {
    :adapter  => 'postgresql',
    :encoding => 'utf8',
    :database => 'arel_unit',
  }
}

ActiveRecord::Base.establish_connection 'unit'
