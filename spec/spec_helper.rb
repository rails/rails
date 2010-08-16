require 'rubygems'
require 'spec'
require 'fileutils'
require 'arel'

require 'support/matchers/be_like'
require 'support/check'

if adapter = ENV['ADAPTER']
  require "support/connections/#{adapter}_connection.rb"
end

Spec::Runner.configure do |config|
  config.include Matchers
  config.include Check

  if defined?(ActiveRecord::Base)
    tmp = File.expand_path('../../tmp', __FILE__)

    FileUtils.mkdir_p(tmp)
    ActiveRecord::Base.logger = Logger.new("#{tmp}/debug.log")
    ActiveRecord::Base.establish_connection("unit")

    require "support/schemas/#{ENV['ADAPTER']}_schema.rb"

    config.before do
      Arel::Table.engine = Arel::Sql::Engine.new(ActiveRecord::Base)
    end
  end
end
