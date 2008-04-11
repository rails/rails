require 'rubygems'
require 'spec'
require 'pp'
dir = File.dirname(__FILE__)
$LOAD_PATH.unshift "#{dir}/../lib"
Dir["#{dir}/matchers/*"].each { |m| require "#{dir}/matchers/#{File.basename(m)}" }
require 'active_relation'

ActiveRecord::Base.configurations = {
  'test' => {
    :adapter  => 'mysql',
    :username => 'root',
    :password => 'password',
    :encoding => 'utf8',
    :database => 'sql_algebra_test',
  },
}
ActiveRecord::Base.establish_connection 'test'

class Hash
  def shift
    returning to_a.sort { |(key1, value1), (key2, value2)| key1.hash <=> key2.hash }.shift do |key, _|
      delete(key)
    end
  end
end

Spec::Runner.configure do |config|  
  config.include(BeLikeMatcher, HashTheSameAsMatcher)
  config.mock_with :rr
  config.before do
    ActiveRelation::Table.engine = ActiveRelation::Engine.new(ActiveRecord::Base)
  end
end