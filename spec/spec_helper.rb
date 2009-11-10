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
  def adapter_is(name)
    verify_adapter_name(name)
    yield if name.to_s == adapter_name
  end

  def adapter_is_not(name)
    verify_adapter_name(name)
    yield if name.to_s != adapter_name
  end

  def adapter_name
    name = ActiveRecord::Base.configurations["unit"][:adapter]
    verify_adapter_name(name)
    name
  end

  def verify_adapter_name(name)
    raise "Invalid adapter name: #{name}" unless valid_adapters.include?(name.to_s)
  end

  def valid_adapters
    %w[mysql postgresql sqlite3]
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
    Arel::Table.engine = Arel::Sql::Engine.new(ActiveRecord::Base)
  end
end
