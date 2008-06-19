require 'abstract_unit'

class EmptyTrue
  def empty?() true; end
end

class EmptyFalse
  def empty?() false; end
end

class BlankTest < Test::Unit::TestCase
  BLANK = [ EmptyTrue.new, nil, false, '', '   ', "  \n\t  \r ", [], {} ]
  NOT   = [ EmptyFalse.new, Object.new, true, 0, 1, 'a', [nil], { nil => 0 } ]

  def test_blank
    BLANK.each { |v| assert v.blank?, "#{v.inspect} should be blank" }
    NOT.each   { |v| assert !v.blank?, "#{v.inspect} should not be blank" }
  end

  def test_present
    BLANK.each { |v| assert !v.present?, "#{v.inspect} should not be present" }
    NOT.each   { |v| assert v.present?, "#{v.inspect} should be present" }
  end
end
