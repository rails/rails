require "#{RAILS_ROOT}/config/environment"
require 'rails_generator'
require 'rails_generator/scripts/update'
Rails::Generator::Scripts::Update.new.run(ARGV)
