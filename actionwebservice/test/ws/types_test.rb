require File.dirname(__FILE__) + '/abstract_unit'

class TypesTest < Test::Unit::TestCase
  include WS

  def setup
    @caster = BaseTypeCaster.new
  end

  def test_base_types
    assert_equal(:int, BaseTypes.canonical_type_name(:integer))
    assert_equal(:int, BaseTypes.canonical_type_name(:fixnum))
    assert_equal(Integer, BaseTypes.type_name_to_class(:bignum))
    assert_equal(Date, BaseTypes.type_name_to_class(:date))
    assert_equal(Time, BaseTypes.type_name_to_class(:timestamp))
    assert_equal(TrueClass, BaseTypes.type_name_to_class(:bool))
    assert_equal(:int, BaseTypes.class_to_type_name(Bignum))
    assert_equal(:bool, BaseTypes.class_to_type_name(FalseClass))
    assert_equal(Integer, BaseTypes.canonical_type_class(Fixnum))
    assert_raises(TypeError) do
      BaseTypes.canonical_type_name(:fake)
    end
  end

  def test_casting
    assert_equal(5, @caster.cast("5", Fixnum))
    assert_equal('50.0', @caster.cast(50.0, String))
    assert_equal(true, @caster.cast('true', FalseClass))
    assert_equal(false, @caster.cast('false', TrueClass))
    assert_raises(TypeError) do
      @caster.cast('yes', FalseClass)
    end
    assert_equal(3.14159, @caster.cast('3.14159', Float))
    now1 = Time.new
    now2 = @caster.cast("#{now1}", Time)
    assert_equal(now1.tv_sec, now2.tv_sec)
    date1 = Date.parse('2004-01-01')
    date2 = @caster.cast("#{date1}", Date)
    assert_equal(date1, date2)
  end
end
