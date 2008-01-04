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

Spec::Runner.configure do |config|  
  config.include(BeLikeMatcher)
end