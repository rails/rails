$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'active_record'
require 'active_record/fixtures'
require 'active_record/support/binding_of_caller'
require 'active_record/support/breakpoint'
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