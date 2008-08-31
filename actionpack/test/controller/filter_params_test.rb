require 'abstract_unit'

class FilterParamController < ActionController::Base
end

class FilterParamTest < Test::Unit::TestCase
  def setup
    @controller = FilterParamController.new
  end

  def test_filter_parameters
    assert FilterParamController.respond_to?(:filter_parameter_logging)
    assert !@controller.respond_to?(:filter_parameters)

    FilterParamController.filter_parameter_logging
    assert @controller.respond_to?(:filter_parameters)

    test_hashes = [[{},{},[]],
    [{'foo'=>nil},{'foo'=>nil},[]],
    [{'foo'=>'bar'},{'foo'=>'bar'},[]],
    [{'foo'=>'bar'},{'foo'=>'bar'},%w'food'],
    [{'foo'=>'bar'},{'foo'=>'[FILTERED]'},%w'foo'],
    [{'foo'=>'bar', 'bar'=>'foo'},{'foo'=>'[FILTERED]', 'bar'=>'foo'},%w'foo baz'],
    [{'foo'=>'bar', 'baz'=>'foo'},{'foo'=>'[FILTERED]', 'baz'=>'[FILTERED]'},%w'foo baz'],
    [{'bar'=>{'foo'=>'bar','bar'=>'foo'}},{'bar'=>{'foo'=>'[FILTERED]','bar'=>'foo'}},%w'fo'],
    [{'foo'=>{'foo'=>'bar','bar'=>'foo'}},{'foo'=>'[FILTERED]'},%w'f banana']]

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
end
