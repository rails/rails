require File.dirname(__FILE__) + '/../abstract_unit'

class BlankTest < Test::Unit::TestCase
  BLANK = [nil, false, '', '   ', "  \n\t  \r ", [], {}]
  NOT   = [true, 0, 1, 'a', [nil], { nil => 0 }]
  
  class EmptyObject
    def empty?
      true
    end
    alias :strip :empty?
  end
  class NoStripObject < EmptyObject; undef :strip; end
  class NoEmptyStripObject < NoStripObject; undef :empty?; end

  def test_blank
    BLANK.each { |v| assert v.blank?  }
    NOT.each   { |v| assert !v.blank? }
    assert EmptyObject.new.blank?
    assert NoStripObject.new.blank?
    assert !NoEmptyStripObject.new.blank?
  end
end
