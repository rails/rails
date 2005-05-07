require File.dirname(__FILE__) + '/abstract_unit'

module CastingTest
  class API < ActionWebService::API::Base
    api_method :int,       :expects => [:int]
    api_method :str,       :expects => [:string]
    api_method :base64,    :expects => [:base64]
    api_method :bool,      :expects => [:bool]
    api_method :float,     :expects => [:float]
    api_method :time,      :expects => [:time]
    api_method :datetime,  :expects => [:datetime]
    api_method :date,      :expects => [:date]

    api_method :int_array,   :expects => [[:int]]
    api_method :str_array,   :expects => [[:string]]
    api_method :bool_array,  :expects => [[:bool]]
  end
end

class TC_Casting < Test::Unit::TestCase
  include CastingTest

  def test_base_type_casting_valid
    assert_equal 10000,   cast_expects(:int, '10000')[0]
    assert_equal '10000', cast_expects(:str, 10000)[0]
    base64 = cast_expects(:base64, 10000)[0]
    assert_equal '10000', base64
    assert_instance_of ActionWebService::Base64, base64
    [1, '1', 'true', 'y', 'yes'].each do |val|
      assert_equal true, cast_expects(:bool, val)[0]
    end
    [0, '0', 'false', 'n', 'no'].each do |val|
      assert_equal false, cast_expects(:bool, val)[0]
    end
    assert_equal 3.14159, cast_expects(:float, '3.14159')[0]
    now = Time.at(Time.now.tv_sec)
    casted = cast_expects(:time, now.to_s)[0]
    assert_equal now, casted
    now = DateTime.now
    assert_equal now.to_s, cast_expects(:datetime, now.to_s)[0].to_s
    today = Date.today
    assert_equal today, cast_expects(:date, today.to_s)[0]
  end

  def test_base_type_casting_invalid
    assert_raises ArgumentError do
      cast_expects(:int, 'this is not a number')
    end
    assert_raises ActionWebService::Casting::CastingError do
      # neither true or false ;)
      cast_expects(:bool, 'i always lie')
    end
    assert_raises ArgumentError do
      cast_expects(:float, 'not a float')
    end
    assert_raises ArgumentError do
      cast_expects(:time, '111111111111111111111111111111111')
    end
    assert_raises ArgumentError do
      cast_expects(:datetime, '-1')
    end
    assert_raises ArgumentError do
      cast_expects(:date, '')
    end
  end

  def test_array_type_casting
    assert_equal [1, 2, 3213992, 4], cast_expects(:int_array, ['1', '2', '3213992', '4'])[0]
    assert_equal ['one', 'two', '5.0', '200', nil, 'true'], cast_expects(:str_array, [:one, 'two', 5.0, 200, nil, true])[0]
    assert_equal [true, nil, true, true, false], cast_expects(:bool_array, ['1', nil, 'y', true, 'false'])[0]
  end

  def test_array_type_casting_failure
    assert_raises ActionWebService::Casting::CastingError do
      cast_expects(:bool_array, ['false', 'blahblah'])
    end
    assert_raises ArgumentError do
      cast_expects(:int_array, ['1', '2.021', '4'])
    end
  end

  private
    def cast_expects(method_name, *args)
      API.api_method_instance(method_name.to_sym).cast_expects([*args])
    end
end
