$:.unshift(File.dirname(__FILE__) + '/../lib')
# $:.unshift(File.dirname(__FILE__) + '/fixtures')

require 'test/unit'
require 'active_record'
require 'active_record/fixtures'
require 'connection'

class Test::Unit::TestCase #:nodoc:
  def create_fixtures(*table_names)
    if block_given?
      Fixtures.create_fixtures(File.dirname(__FILE__) + "/fixtures/", table_names) { yield }
    else
      Fixtures.create_fixtures(File.dirname(__FILE__) + "/fixtures/", table_names)
    end
  end
end

Test::Unit::TestCase.fixture_path = File.dirname(__FILE__) + "/fixtures/"