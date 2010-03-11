dir = File.dirname(__FILE__)
$LOAD_PATH.unshift "#{dir}/../lib"

require 'rubygems'
require 'spec'
require 'pp'
require 'fileutils'
require 'arel'

[:matchers, :doubles].each do |helper|
  Dir["#{dir}/#{helper}/*"].each { |m| require "#{dir}/#{helper}/#{File.basename(m)}" }
end

module AdapterGuards
  def adapter_is(*names)
    names = names.map(&:to_s)
    names.each{|name| verify_adapter_name(name)}
    yield if names.include? adapter_name
  end

  def adapter_is_not(*names)
    names = names.map(&:to_s)
    names.each{|name| verify_adapter_name(name)}
    yield unless names.include? adapter_name
  end

  def adapter_name
    name = ActiveRecord::Base.configurations["unit"][:adapter]
    name = 'oracle' if name == 'oracle_enhanced'
    verify_adapter_name(name)
    name
  end

  def verify_adapter_name(name)
    raise "Invalid adapter name: #{name}" unless valid_adapters.include?(name.to_s)
  end

  def valid_adapters
    %w[mysql postgresql sqlite3 oracle]
  end
end

module Check
  # This is used to eliminate Ruby warnings on some RSpec assertion lines
  # See: https://rspec.lighthouseapp.com/projects/5645/tickets/504
  def check(*args)
  end
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
  require "#{dir}/connections/#{adapter}_connection.rb"
  require "#{dir}/schemas/#{adapter}_schema.rb"
end
