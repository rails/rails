require 'abstract_unit'

class MimeTypeTest < ActiveSupport::TestCase
  Mime::Type.register "image/png", :png unless defined? Mime::PNG
  Mime::Type.register "application/pdf", :pdf unless defined? Mime::PDF

  test "parse single" do
    Mime::LOOKUP.keys.each do |mime_type|
      assert_equal [Mime::Type.lookup(mime_type)], Mime::Type.parse(mime_type)
    end
  end

  test "parse without q" do
    accept = "text/xml,application/xhtml+xml,text/yaml,application/xml,text/html,image/png,text/plain,application/pdf,*/*"
    expect = [Mime::HTML, Mime::XML, Mime::YAML, Mime::PNG, Mime::TEXT, Mime::PDF, Mime::ALL]
    assert_equal expect, Mime::Type.parse(accept)
  end

  test "parse with q" do
    accept = "text/xml,application/xhtml+xml,text/yaml; q=0.3,application/xml,text/html; q=0.8,image/png,text/plain; q=0.5,application/pdf,*/*; q=0.2"
    expect = [Mime::HTML, Mime::XML, Mime::PNG, Mime::PDF, Mime::TEXT, Mime::YAML, Mime::ALL]
    assert_equal expect, Mime::Type.parse(accept)
  end

  # Accept header send with user HTTP_USER_AGENT: Sunrise/0.42j (Windows XP)
  test "parse crappy broken acceptlines" do
    accept = "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/*,,*/*;q=0.5"
    expect = [Mime::HTML, Mime::XML, "image/*", Mime::TEXT, Mime::ALL]
    assert_equal expect, Mime::Type.parse(accept).collect { |c| c.to_s }
  end

  # Accept header send with user HTTP_USER_AGENT: Mozilla/4.0
  #  (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322; InfoPath.1)
  test "parse crappy broken acceptlines2" do
    accept = "image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, application/vnd.ms-excel, application/vnd.ms-powerpoint, application/msword,  , pronto/1.00.00, sslvpn/1.00.00.00, */*"
    expect = ['image/gif', 'image/x-xbitmap', 'image/jpeg','image/pjpeg', 'application/x-shockwave-flash', 'application/vnd.ms-excel', 'application/vnd.ms-powerpoint', 'application/msword', 'pronto/1.00.00', 'sslvpn/1.00.00.00', Mime::ALL  ]
    assert_equal expect, Mime::Type.parse(accept).collect { |c| c.to_s }
  end

  test "custom type" do
    begin
      Mime::Type.register("image/gif", :gif)
      assert_nothing_raised do
        Mime::GIF
        assert_equal Mime::GIF, Mime::SET.last
      end
    ensure
      Mime.module_eval { remove_const :GIF if const_defined?(:GIF) }
    end
  end

  test "type should be equal to symbol" do
    assert_equal Mime::HTML, 'application/xhtml+xml'
    assert_equal Mime::HTML, :html
  end

  test "type convenience methods" do
    # Don't test Mime::ALL, since it Mime::ALL#html? == true
    types = Mime::SET.symbols.uniq - [:all]

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

  test "mime all is html" do
    assert Mime::ALL.all?,  "Mime::ALL is not all?"
    assert Mime::ALL.html?, "Mime::ALL is not html?"
  end

  test "verifiable mime types" do
    all_types = Mime::SET.symbols
    all_types.uniq!
    # Remove custom Mime::Type instances set in other tests, like Mime::GIF and Mime::IPHONE
    all_types.delete_if { |type| !Mime.const_defined?(type.to_s.upcase) }
    verified, unverified = all_types.partition { |type| Mime::Type.browser_generated_types.include? type }
    assert verified.each   { |type| assert  Mime.const_get(type.to_s.upcase).verify_request?, "Verifiable Mime Type is not verified: #{type.inspect}" }
    assert unverified.each { |type| assert !Mime.const_get(type.to_s.upcase).verify_request?, "Nonverifiable Mime Type is verified: #{type.inspect}" }
  end

  test "regexp matcher" do
    assert Mime::JS =~ "text/javascript"
    assert Mime::JS =~ "application/javascript"
    assert Mime::JS !~ "text/html"
    assert !(Mime::JS !~ "text/javascript")
    assert !(Mime::JS !~ "application/javascript")
    assert Mime::HTML =~ 'application/xhtml+xml'
  end
end
