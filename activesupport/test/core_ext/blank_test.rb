require File.dirname(__FILE__) + '/../abstract_unit'

class EmptyTrue
  def empty?() true; end
end

class EmptyFalse
  def empty?() false; end
end

class EmptyStripNotEmpty
  def empty?() true; end
  def strip() 'foo'; end
end

class EmptyStripEmpty
  def empty?() true; end
  def strip() ''; end
end

class NotEmptyStripNotEmpty
  def empty?() false; end
  def strip() 'foo'; end
end

class NotEmptyStripEmpty
  def empty?() false; end
  def strip() ''; end
end

class BlankTest < Test::Unit::TestCase
  BLANK = [ EmptyTrue.new, EmptyStripNotEmpty.new, EmptyStripEmpty.new,
            NotEmptyStripEmpty.new, nil, false, '', '   ', "  \n\t  \r ",
            [], {} ]
  NOT   = [ EmptyFalse.new, NotEmptyStripNotEmpty.new, Object.new, true,
            0, 1, 'a', [nil], { nil => 0 } ]
  
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
