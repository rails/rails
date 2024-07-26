require File.dirname(__FILE__) + "/../config/environments/test"

require 'test/unit'
require 'active_record/fixtures'

def create_fixtures(table_name)
  Fixtures.new(ActiveRecord::Base.connection, table_name, File.dirname(__FILE__) + "/fixtures/#{table_name}")
end