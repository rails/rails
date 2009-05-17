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
    yield if name.to_s == adapter_name
  end

  def adapter_is_not(name)
    yield if name.to_s != adapter_name
  end

  def adapter_name
    Arel::Table.engine.connection.class.name.underscore.split("/").last.gsub(/_adapter/, '')
  end
end

Spec::Runner.configure do |config|
  config.include BeLikeMatcher, HashTheSameAsMatcher, DisambiguateAttributesMatcher
  config.include AdapterGuards
  config.mock_with :rr
  config.before do
    Arel::Table.engine = Arel::Sql::Engine.new(ActiveRecord::Base)
  end
end
