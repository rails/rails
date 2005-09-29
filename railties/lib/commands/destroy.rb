require "#{RAILS_ROOT}/config/environment"
require 'rails_generator'
require 'rails_generator/scripts/destroy'

ARGV.shift if ['--help', '-h'].include?(ARGV[0])
Rails::Generator::Scripts::Destroy.new.run(ARGV)
