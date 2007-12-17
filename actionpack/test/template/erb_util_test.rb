require "#{File.dirname(__FILE__)}/../abstract_unit"

class ErbUtilTest < Test::Unit::TestCase
  include ERB::Util
  
  def test_amp
    assert_equal '&amp;', html_escape('&')
  end
  
  def test_quot
    assert_equal '&quot;', html_escape('"')
  end

  def test_lt
    assert_equal '&lt;', html_escape('<')
  end

  def test_gt
    assert_equal '&gt;', html_escape('>')
  end
  
  def test_rest_in_ascii
    (0..127).to_a.map(&:chr).each do |chr|
      next if %w(& " < >).include?(chr)
      assert_equal chr, html_escape(chr)
    end
  end
end
require "#{File.dirname(__FILE__)}/../abstract_unit"

class ErbUtilTest < Test::Unit::TestCase
  include ERB::Util
  
  def test_amp
    assert_equal '&amp;', html_escape('&')
  end
  
  def test_quot
    assert_equal '&quot;', html_escape('"')
  end

  def test_lt
    assert_equal '&lt;', html_escape('<')
  end

  def test_gt
    assert_equal '&gt;', html_escape('>')
  end
  
  def test_rest_in_ascii
    (0..127).to_a.map(&:chr).each do |chr|
      next if %w(& " < >).include?(chr)
      assert_equal chr, html_escape(chr)
    end
  end
end