require 'abstract_unit'

class LoggingController < ActionController::Base
  def show
    render :nothing => true
  end
end

class LoggingTest < ActionController::TestCase
  tests LoggingController

  class MockLogger
    attr_reader :logged
    attr_accessor :level
    
    def initialize
      @level = Logger::DEBUG
    end
    
    def method_missing(method, *args, &blk)
      @logged ||= []
      @logged << args.first
      @logged << blk.call if block_given?
    end
  end

  def setup
    super
    set_logger
  end

  def test_logging_without_parameters
    get :show
    assert_equal 2, logs.size
    assert_nil logs.detect {|l| l =~ /Parameters/ }
  end

  def test_logging_with_parameters
    get :show, :id => '10'
    assert_equal 3, logs.size

    params = logs.detect {|l| l =~ /Parameters/ }
    assert_equal 'Parameters: {"id"=>"10"}', params
  end
  
  private

  def set_logger
    @controller.logger = MockLogger.new
  end
  
  def logs
    @logs ||= @controller.logger.logged.compact.map {|l| l.to_s.strip}
  end
end
