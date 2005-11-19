$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../../activesupport/lib')

require 'test/unit'
require 'active_record'
require 'active_record/fixtures'
require 'active_support/binding_of_caller'
require 'active_support/breakpoint'
require 'connection'

QUOTED_TYPE = ActiveRecord::Base.connection.quote_column_name('type') unless Object.const_defined?(:QUOTED_TYPE)

class Test::Unit::TestCase #:nodoc:
  self.fixture_path = File.dirname(__FILE__) + "/fixtures/"
  self.use_instantiated_fixtures = false
  self.use_transactional_fixtures = (ENV['AR_NO_TX_FIXTURES'] != "yes")

  def create_fixtures(*table_names, &block)
    Fixtures.create_fixtures(File.dirname(__FILE__) + "/fixtures/", table_names, &block)
  end
end

def current_adapter?(type)
  ActiveRecord::ConnectionAdapters.const_defined?(type) &&
    ActiveRecord::Base.connection.instance_of?(ActiveRecord::ConnectionAdapters.const_get(type))
end

#ActiveRecord::Base.logger = Logger.new(STDOUT)
#ActiveRecord::Base.colorize_logging = false
