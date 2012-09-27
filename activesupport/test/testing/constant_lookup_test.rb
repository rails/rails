require 'abstract_unit'

class Foo; end
class Bar < Foo;
  def index; end
  def self.index; end
end
class Baz < Bar; end
module FooBar; end

class ConstantLookupTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::ConstantLookup

  def find_foo(name)
    self.class.determine_constant_from_test_name(name) do |constant|
      Class === constant && constant < Foo
    end
  end

  def find_module(name)
    self.class.determine_constant_from_test_name(name) do |constant|
      Module === constant
    end
  end

  def test_find_bar_from_foo
    assert_equal Bar, find_foo("Bar")
    assert_equal Bar, find_foo("Bar::index")
    assert_equal Bar, find_foo("Bar::index::authenticated")
    assert_equal Bar, find_foo("BarTest")
    assert_equal Bar, find_foo("BarTest::index")
    assert_equal Bar, find_foo("BarTest::index::authenticated")
  end

  def test_find_module
    assert_equal FooBar, find_module("FooBar")
    assert_equal FooBar, find_module("FooBar::index")
    assert_equal FooBar, find_module("FooBar::index::authenticated")
    assert_equal FooBar, find_module("FooBarTest")
    assert_equal FooBar, find_module("FooBarTest::index")
    assert_equal FooBar, find_module("FooBarTest::index::authenticated")
  end

  def test_returns_nil_when_cant_find_foo
    assert_nil find_foo("DoesntExist")
    assert_nil find_foo("DoesntExistTest")
    assert_nil find_foo("DoesntExist::Nadda")
    assert_nil find_foo("DoesntExist::Nadda::Nope")
    assert_nil find_foo("DoesntExist::Nadda::Nope::NotHere")
  end

  def test_returns_nil_when_cant_find_module
    assert_nil find_module("DoesntExist")
    assert_nil find_module("DoesntExistTest")
    assert_nil find_module("DoesntExist::Nadda")
    assert_nil find_module("DoesntExist::Nadda::Nope")
    assert_nil find_module("DoesntExist::Nadda::Nope::NotHere")
  end
end
