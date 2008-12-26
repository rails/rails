require 'abstract_unit'

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

  # Accept header send with user HTTP_USER_AGENT: Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322; InfoPath.1)
  def test_parse_crappy_broken_acceptlines2
    accept = "image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, application/vnd.ms-excel, application/vnd.ms-powerpoint, application/msword,  , pronto/1.00.00, sslvpn/1.00.00.00, */*"
    expect = ['image/gif', 'image/x-xbitmap', 'image/jpeg','image/pjpeg', 'application/x-shockwave-flash', 'application/vnd.ms-excel', 'application/vnd.ms-powerpoint', 'application/msword', 'pronto/1.00.00', 'sslvpn/1.00.00.00', Mime::ALL  ]
    assert_equal expect, Mime::Type.parse(accept).collect { |c| c.to_s }
  end
  
  def test_custom_type
    Mime::Type.register("image/gif", :gif)
    assert_nothing_raised do 
      Mime::GIF
      assert_equal Mime::GIF, Mime::SET.last
    end
  ensure
    Mime.module_eval { remove_const :GIF if const_defined?(:GIF) }
  end
  
  def test_type_should_be_equal_to_symbol
    assert_equal Mime::HTML, 'application/xhtml+xml'
    assert_equal Mime::HTML, :html
  end

  def test_type_convenience_methods
    # Don't test Mime::ALL, since it Mime::ALL#html? == true
    types = Mime::SET.to_a.map(&:to_sym).uniq - [:all]

    # Remove custom Mime::Type instances set in other tests, like Mime::GIF and Mime::IPHONE
    types.delete_if { |type| !Mime.const_defined?(type.to_s.upcase) }

    types.each do |type|
      mime = Mime.const_get(type.to_s.upcase)
      assert mime.send("#{type}?"), "#{mime.inspect} is not #{type}?"
      invalid_types = types - [type]
      invalid_types.delete(:html) if Mime::Type.html_types.include?(type)
      invalid_types.each { |other_type| assert !mime.send("#{other_type}?"), "#{mime.inspect} is #{other_type}?" }
    end
  end

  def test_mime_all_is_html
    assert Mime::ALL.all?,  "Mime::ALL is not all?"
    assert Mime::ALL.html?, "Mime::ALL is not html?"
  end

  def test_verifiable_mime_types
    all_types = Mime::SET.to_a.map(&:to_sym)
    all_types.uniq!
    # Remove custom Mime::Type instances set in other tests, like Mime::GIF and Mime::IPHONE
    all_types.delete_if { |type| !Mime.const_defined?(type.to_s.upcase) }
    verified, unverified = all_types.partition { |type| Mime::Type.browser_generated_types.include? type }
    assert verified.each   { |type| assert  Mime.const_get(type.to_s.upcase).verify_request?, "Verifiable Mime Type is not verified: #{type.inspect}" }
    assert unverified.each { |type| assert !Mime.const_get(type.to_s.upcase).verify_request?, "Nonverifiable Mime Type is verified: #{type.inspect}" }
  end

  def test_regexp_matcher
    assert Mime::JS =~ "text/javascript"
    assert Mime::JS =~ "application/javascript"
    assert Mime::JS !~ "text/html"
    assert !(Mime::JS !~ "text/javascript")
    assert !(Mime::JS !~ "application/javascript")
    assert Mime::HTML =~ 'application/xhtml+xml'
  end
end
