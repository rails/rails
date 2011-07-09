require 'abstract_unit'

class RubygemsVersionTests < Test::Unit::TestCase
  def test_with_different_versions_for_greater_than_symbol
    assert(Gem::Version.new('1.9') > '1.8.7')
    assert(!(Gem::Version.new('1.8.7') > '1.9'))
    assert(Gem::Version.new('10.9') > '9.10')
    assert(!(Gem::Version.new('9.10') > '10.9'))
    assert(Gem::Version.new('1.10.9') > '1.9.10')
    assert(!(Gem::Version.new('1.9.10') > '1.10.9'))
  end

  def test_with_different_versions_for_less_than_symbol
    assert(!(Gem::Version.new('1.9') < '1.8.7'))
    assert(Gem::Version.new('1.8.7') < '1.9')
    assert(!(Gem::Version.new('10.9') < '9.10'))
    assert(Gem::Version.new('9.10') < '10.9')
    assert(!(Gem::Version.new('1.10.9') < '1.9.10'))
    assert(Gem::Version.new('1.9.10') < '1.10.9')
  end

  def test_with_different_versions_for_equals_to_symbol
    assert(!(Gem::Version.new('1.9') == '1.8.7'))
    assert(Gem::Version.new('1.8.7') == '1.8.7')
    assert(!(Gem::Version.new('10.9') == '9.10'))
  end


  def test_with_different_versions_for_greater_than_equals_to_symbol
    assert(Gem::Version.new('1.9') >= '1.9')
    assert(!(Gem::Version.new('1.8.7') >= '1.9'))
    assert(Gem::Version.new('10.9') >= '9.10')
  end


  def test_with_different_versions_for_less_than_equals_to_symbol
    assert(Gem::Version.new('1.9') <= '1.9')
    assert(Gem::Version.new('1.8.7') <= '1.9')
    assert(!(Gem::Version.new('10.9') <= '9.10'))
  end
end

