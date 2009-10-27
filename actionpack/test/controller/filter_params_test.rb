require 'abstract_unit'

class FilterParamController < ActionController::Base
  def payment
    head :ok
  end
end

class FilterParamTest < ActionController::TestCase
  tests FilterParamController

  class MockLogger
    attr_reader :logged
    attr_accessor :level
    
    def initialize
      @level = Logger::DEBUG
    end
    
    def method_missing(method, *args)
      @logged ||= []
      @logged << args.first unless block_given?
      @logged << yield if block_given?
    end
  end

  setup :set_logger

  def test_filter_parameters_must_have_one_word
    assert_raises RuntimeError do
      FilterParamController.filter_parameter_logging
    end
  end

  def test_filter_parameters
    assert FilterParamController.respond_to?(:filter_parameter_logging)

    test_hashes = [
    [{'foo'=>'bar'},{'foo'=>'bar'},%w'food'],
    [{'foo'=>'bar'},{'foo'=>'[FILTERED]'},%w'foo'],
    [{'foo'=>'bar', 'bar'=>'foo'},{'foo'=>'[FILTERED]', 'bar'=>'foo'},%w'foo baz'],
    [{'foo'=>'bar', 'baz'=>'foo'},{'foo'=>'[FILTERED]', 'baz'=>'[FILTERED]'},%w'foo baz'],
    [{'bar'=>{'foo'=>'bar','bar'=>'foo'}},{'bar'=>{'foo'=>'[FILTERED]','bar'=>'foo'}},%w'fo'],
    [{'foo'=>{'foo'=>'bar','bar'=>'foo'}},{'foo'=>'[FILTERED]'},%w'f banana'],
    [{'baz'=>[{'foo'=>'baz'}]}, {'baz'=>[{'foo'=>'[FILTERED]'}]}, %w(foo)]]

    test_hashes.each do |before_filter, after_filter, filter_words|
      FilterParamController.filter_parameter_logging(*filter_words)
      assert_equal after_filter, @controller.__send__(:filter_parameters, before_filter)

      filter_words.push('blah')
      FilterParamController.filter_parameter_logging(*filter_words) do |key, value|
        value.reverse! if key =~ /bargain/
      end

      before_filter['barg'] = {'bargain'=>'gain', 'blah'=>'bar', 'bar'=>{'bargain'=>{'blah'=>'foo'}}}
      after_filter['barg'] = {'bargain'=>'niag', 'blah'=>'[FILTERED]', 'bar'=>{'bargain'=>{'blah'=>'[FILTERED]'}}}

      assert_equal after_filter, @controller.__send__(:filter_parameters, before_filter)
    end
  end

  def test_filter_parameters_is_protected
    FilterParamController.filter_parameter_logging(:foo)
    assert !FilterParamController.action_methods.include?('filter_parameters')
    assert_raise(NoMethodError) { @controller.filter_parameters([{'password' => '[FILTERED]'}]) }
  end

  def test_filter_parameters_inside_logs
    FilterParamController.filter_parameter_logging(:lifo, :amount)

    get :payment, :lifo => 'Pratik', :amount => '420', :step => '1'

    filtered_params_logs = logs.detect {|l| l =~ /\AParameters/ }

    assert filtered_params_logs.index('"amount"=>"[FILTERED]"')
    assert filtered_params_logs.index('"lifo"=>"[FILTERED]"')
    assert filtered_params_logs.index('"step"=>"1"')
  end

  private

  def set_logger
    @controller.logger = MockLogger.new
  end
  
  def logs
    @logs ||= @controller.logger.logged.compact.map {|l| l.to_s.strip}
  end
end
