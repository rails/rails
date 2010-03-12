dir = File.dirname(__FILE__)
$LOAD_PATH.unshift "#{dir}/../lib"

require 'rubygems'
require 'spec'
require 'pp'
require 'fileutils'
require 'arel'

Dir["#{dir}/support/*.rb"].each do |file|
  require file
end

Spec::Runner.configure do |config|
  config.include BeLikeMatcher, HashTheSameAsMatcher, DisambiguateAttributesMatcher
  config.include AdapterGuards
  config.include Check

  config.before do
    Arel::Table.engine = Arel::Sql::Engine.new(ActiveRecord::Base) if defined?(ActiveRecord::Base)
  end
end

# load corresponding adapter using ADAPTER environment variable when running single *_spec.rb file
if adapter = ENV['ADAPTER']
  require "#{dir}/support/connections/#{adapter}_connection.rb"
  require "#{dir}/support/schemas/#{adapter}_schema.rb"
end
