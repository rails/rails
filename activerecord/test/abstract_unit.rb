$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'active_record'
require 'active_record/fixtures'
require 'connection'

class Test::Unit::TestCase
  def create_fixtures(table_name)
    Fixtures.new(ActiveRecord::Base.connection, table_name, File.dirname(__FILE__) + "/fixtures/" + table_name)
  end
end