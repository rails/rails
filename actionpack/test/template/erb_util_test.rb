require 'abstract_unit'

class ErbUtilTest < Test::Unit::TestCase
  include ERB::Util

  ERB::Util::HTML_ESCAPE.each do |given, expected|
    define_method "test_html_escape_#{expected.gsub /\W/, ''}" do
      assert_equal expected, html_escape(given)
    end

    unless given == '"'
      define_method "test_json_escape_#{expected.gsub /\W/, ''}" do
        assert_equal ERB::Util::JSON_ESCAPE[given], json_escape(given)
      end
    end
  end

  def test_html_escape_is_html_safe
    escaped = h("<p>")
    assert_equal "&lt;p&gt;", escaped
    assert escaped.html_safe?
  end

  def test_html_escape_passes_html_escpe_unmodified
    escaped = h("<p>".html_safe)
    assert_equal "<p>", escaped
    assert escaped.html_safe?
  end
  
  def test_rest_in_ascii
    (0..127).to_a.map(&:chr).each do |chr|
      next if %w(& " < >).include?(chr)
      assert_equal chr, html_escape(chr)
    end
  end
end
