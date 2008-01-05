require 'rubygems'
require 'spec'
require File.join(File.dirname(__FILE__), '..', 'lib', 'sql_algebra')
require File.join(File.dirname(__FILE__), 'spec_helpers', 'be_like')

ActiveRecord::Base.configurations = {
  'sql_algebra_test' => {
    :adapter  => 'mysql',
    :username => 'root',
    :password => 'password',
    :encoding => 'utf8',
    :database => 'sql_algebra_test',
  },
}
ActiveRecord::Base.establish_connection 'sql_algebra_test'

class Hash
  def shift
    returning to_a.sort { |(key1, value1), (key2, value2)| key1.hash <=> key2.hash }.shift do |key, value|
      delete(key)
    end
  end
end

Spec::Runner.configure do |config|  
  config.include(BeLikeMatcher)
end