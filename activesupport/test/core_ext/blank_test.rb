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
end
