require 'abstract_unit'

class ErbUtilTest < ActiveSupport::TestCase
  include ERB::Util

  ERB::Util::HTML_ESCAPE.each do |given, expected|
    define_method "test_html_escape_#{expected.gsub(/\W/, '')}" do
      assert_equal expected, html_escape(given)
    end
  end

  ERB::Util::JSON_ESCAPE.each do |given, expected|
    define_method "test_json_escape_#{expected.gsub(/\W/, '')}" do
      assert_equal ERB::Util::JSON_ESCAPE[given], json_escape(given)
    end
  end

  def test_json_escape_returns_unsafe_strings_when_passed_unsafe_strings
    value = json_escape("asdf")
    assert !value.html_safe?
  end

  def test_json_escape_returns_safe_strings_when_passed_safe_strings
    value = json_escape("asdf".html_safe)
    assert value.html_safe?
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
    (0..127).to_a.map {|int| int.chr }.each do |chr|
      next if %('"&<>).include?(chr)
      assert_equal chr, html_escape(chr)
    end
  end

  def test_html_escape_once
    assert_equal '1 &lt;&gt;&amp;&quot;&#39; 2 &amp; 3', html_escape_once('1 <>&"\' 2 &amp; 3')
  end

  def test_html_escape_once_returns_unsafe_strings_when_passed_unsafe_strings
    value = html_escape_once('1 < 2 &amp; 3')
    assert !value.html_safe?
  end

  def test_html_escape_once_returns_safe_strings_when_passed_safe_strings
    value = html_escape_once('1 < 2 &amp; 3'.html_safe)
    assert value.html_safe?
  end
end
