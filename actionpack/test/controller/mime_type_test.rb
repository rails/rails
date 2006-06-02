require File.dirname(__FILE__) + '/../abstract_unit'

class MimeTypeTest < Test::Unit::TestCase
  Mime::PNG   = Mime::Type.new("image/png")
  Mime::PLAIN = Mime::Type.new("text/plain")

  def test_parse_single
    Mime::LOOKUP.keys.each do |mime_type|
      assert_equal [Mime::Type.lookup(mime_type)], Mime::Type.parse(mime_type)
    end
  end

  def test_parse_without_q
    accept = "text/xml,application/xhtml+xml,text/yaml,application/xml,text/html,image/png,text/plain,*/*"
    expect = [Mime::HTML, Mime::XML, Mime::YAML, Mime::PNG, Mime::PLAIN, Mime::ALL]
    assert_equal expect, Mime::Type.parse(accept)
  end

  def test_parse_with_q
    accept = "text/xml,application/xhtml+xml,text/yaml; q=0.3,application/xml,text/html; q=0.8,image/png,text/plain; q=0.5,*/*; q=0.2"
    expect = [Mime::HTML, Mime::XML, Mime::PNG, Mime::PLAIN, Mime::YAML, Mime::ALL]
    assert_equal expect, Mime::Type.parse(accept)
  end
  
  def test_custom_type
    Mime::Type.register("image/gif", :gif)
    assert_nothing_raised do 
      Mime::GIF
      assert_equal Mime::GIF, Mime::SET.last
    end
    Mime.send :remove_const, :GIF
  end
end