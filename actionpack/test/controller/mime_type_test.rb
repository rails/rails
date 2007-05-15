require File.dirname(__FILE__) + '/../abstract_unit'

class MimeTypeTest < Test::Unit::TestCase
  Mime::Type.register "image/png", :png
  Mime::Type.register "application/pdf", :pdf

  def test_parse_single
    Mime::LOOKUP.keys.each do |mime_type|
      assert_equal [Mime::Type.lookup(mime_type)], Mime::Type.parse(mime_type)
    end
  end

  def test_parse_without_q
    accept = "text/xml,application/xhtml+xml,text/yaml,application/xml,text/html,image/png,text/plain,application/pdf,*/*"
    expect = [Mime::HTML, Mime::XML, Mime::YAML, Mime::PNG, Mime::TEXT, Mime::PDF, Mime::ALL]
    assert_equal expect, Mime::Type.parse(accept)
  end

  def test_parse_with_q
    accept = "text/xml,application/xhtml+xml,text/yaml; q=0.3,application/xml,text/html; q=0.8,image/png,text/plain; q=0.5,application/pdf,*/*; q=0.2"
    expect = [Mime::HTML, Mime::XML, Mime::PNG, Mime::PDF, Mime::TEXT, Mime::YAML, Mime::ALL]
    assert_equal expect, Mime::Type.parse(accept)
  end
  
  # Accept header send with user HTTP_USER_AGENT: Sunrise/0.42j (Windows XP)
  def test_parse_crappy_broken_acceptlines
    accept = "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/*,,*/*;q=0.5"
    expect = [Mime::HTML, Mime::XML, "image/*", Mime::TEXT, Mime::ALL]
    assert_equal expect, Mime::Type.parse(accept).collect { |c| c.to_s }
  end
  
  def test_custom_type
    Mime::Type.register("image/gif", :gif)
    assert_nothing_raised do 
      Mime::GIF
      assert_equal Mime::GIF, Mime::SET.last
    end
    Mime.send :remove_const, :GIF
  end
  
  def test_type_convenience_methods
    types = [:html, :xml, :png, :pdf, :yaml, :url_encoded_form]
    types.each do |type|
      mime = Mime.const_get(type.to_s.upcase)
      assert mime.send("#{type}?"), "Mime::#{type.to_s.upcase} is not #{type}?"
      (types - [type]).each { |t| assert !mime.send("#{t}?"), "Mime::#{t.to_s.upcase} is #{t}?" }
    end
  end
  
  def test_mime_all_is_html
    assert Mime::ALL.all?,  "Mime::ALL is not all?"
    assert Mime::ALL.html?, "Mime::ALL is not html?"
  end
end
