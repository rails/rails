require 'test/unit/testcase'
require 'active_support/testing/setup_and_teardown'
require 'active_support/testing/default'

# TODO: move to core_ext
class Test::Unit::TestCase #:nodoc:
  include ActiveSupport::Testing::SetupAndTeardown
end

module ActiveSupport
  class TestCase < Test::Unit::TestCase
    # test "verify something" do                                   
    #   ...
    # end                                                     
    def self.test(name, &block)
      test_name = "test_#{name.gsub(/[\s]/,'_')}".to_sym
      raise "#{test_name} is already defined in #{self}" if self.instance_methods.include?(test_name.to_s)
      define_method(test_name, &block)
    end
  end
end