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
  
  def test_rest_in_ascii
    (0..127).to_a.map {|int| int.chr }.each do |chr|
      next if %w(& " < >).include?(chr)
      assert_equal chr, html_escape(chr)
    end
  end
end
