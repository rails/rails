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

Spec::Runner.configure do |config|  
  config.include(BeLikeMatcher, HashTheSameAsMatcher, DisambiguateAttributesMatcher)
  config.mock_with :rr
  config.before do
    Arel::Table.engine = Arel::Engine.new(Fake::Engine.new)
  end
end