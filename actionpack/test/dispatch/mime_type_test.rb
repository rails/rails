require 'abstract_unit'

class MimeTypeTest < ActiveSupport::TestCase
  Mime::Type.register "image/png", :png unless defined? Mime::PNG
  Mime::Type.register "application/pdf", :pdf unless defined? Mime::PDF

  test "parse single" do
    Mime::LOOKUP.keys.each do |mime_type|
      unless mime_type == 'image/*'
        assert_equal [Mime::Type.lookup(mime_type)], Mime::Type.parse(mime_type)
      end
    end
  end

  test "unregister" do
    begin
      Mime::Type.register("text/x-mobile", :mobile)
      assert defined?(Mime::MOBILE)
      assert_equal Mime::MOBILE, Mime::LOOKUP['text/x-mobile']
      assert_equal Mime::MOBILE, Mime::EXTENSION_LOOKUP['mobile']

      Mime::Type.unregister(:mobile)
      assert !defined?(Mime::MOBILE), "Mime::MOBILE should not be defined"
      assert !Mime::LOOKUP.has_key?('text/x-mobile'), "Mime::LOOKUP should not have key ['text/x-mobile]"
      assert !Mime::EXTENSION_LOOKUP.has_key?('mobile'), "Mime::EXTENSION_LOOKUP should not have key ['mobile]"
    ensure
      Mime.module_eval { remove_const :MOBILE if const_defined?(:MOBILE) }
      Mime::LOOKUP.reject!{|key,_| key == 'text/x-mobile'}
    end
  end

  test "parse text with trailing star at the beginning" do
    accept = "text/*, text/html, application/json, multipart/form-data"
    expect = [Mime::HTML, Mime::TEXT, Mime::JS, Mime::CSS, Mime::ICS, Mime::CSV, Mime::XML, Mime::YAML, Mime::JSON, Mime::MULTIPART_FORM]
    parsed = Mime::Type.parse(accept)
    assert_equal expect, parsed
  end

  test "parse text with trailing star in the end" do
    accept = "text/html, application/json, multipart/form-data, text/*"
    expect = [Mime::HTML, Mime::JSON, Mime::MULTIPART_FORM, Mime::TEXT, Mime::JS, Mime::CSS, Mime::ICS, Mime::CSV, Mime::XML, Mime::YAML]
    parsed = Mime::Type.parse(accept)
    assert_equal expect, parsed
  end

  test "parse text with trailing star" do
    accept = "text/*"
    expect = [Mime::HTML, Mime::TEXT, Mime::JS, Mime::CSS, Mime::ICS, Mime::CSV, Mime::XML, Mime::YAML, Mime::JSON]
    parsed = Mime::Type.parse(accept)
    assert_equal expect, parsed
  end

  test "parse application with trailing star" do
    accept = "application/*"
    expect = [Mime::HTML, Mime::JS, Mime::XML, Mime::RSS, Mime::ATOM, Mime::YAML, Mime::URL_ENCODED_FORM, Mime::JSON, Mime::PDF, Mime::ZIP]
    parsed = Mime::Type.parse(accept)
    assert_equal expect, parsed
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

  test "parse single media range with q" do
    accept = "text/html;q=0.9"
    expect = [Mime::HTML]
    assert_equal expect, Mime::Type.parse(accept)
  end

  test "parse arbitarry media type parameters" do
    accept = 'multipart/form-data; boundary="simple boundary"'
    expect = [Mime::MULTIPART_FORM]
    assert_equal expect, Mime::Type.parse(accept)
  end

  # Accept header send with user HTTP_USER_AGENT: Sunrise/0.42j (Windows XP)
  test "parse broken acceptlines" do
    accept = "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/*,,*/*;q=0.5"
    expect = [Mime::HTML, Mime::XML, "image/*", Mime::TEXT, Mime::ALL]
    assert_equal expect, Mime::Type.parse(accept).collect { |c| c.to_s }
  end

  # Accept header send with user HTTP_USER_AGENT: Mozilla/4.0
  #  (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322; InfoPath.1)
  test "parse other broken acceptlines" do
    accept = "image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, application/vnd.ms-excel, application/vnd.ms-powerpoint, application/msword,  , pronto/1.00.00, sslvpn/1.00.00.00, */*"
    expect = ['image/gif', 'image/x-xbitmap', 'image/jpeg','image/pjpeg', 'application/x-shockwave-flash', 'application/vnd.ms-excel', 'application/vnd.ms-powerpoint', 'application/msword', 'pronto/1.00.00', 'sslvpn/1.00.00.00', Mime::ALL]
    assert_equal expect, Mime::Type.parse(accept).collect { |c| c.to_s }
  end

  test "custom type" do
    begin
      Mime::Type.register("image/foo", :foo)
      assert_nothing_raised do
        assert_equal Mime::FOO, Mime::SET.last
      end
    ensure
      Mime::Type.unregister(:FOO)
    end
  end

  test "custom type with type aliases" do
    begin
      Mime::Type.register "text/foobar", :foobar, ["text/foo", "text/bar"]
      %w[text/foobar text/foo text/bar].each do |type|
        assert_equal Mime::FOOBAR, type
      end
    ensure
      Mime::Type.unregister(:FOOBAR)
    end
  end

  test "register callbacks" do
    begin
      registered_mimes = []
      Mime::Type.register_callback do |mime|
        registered_mimes << mime
      end

      Mime::Type.register("text/foo", :foo)
      assert_equal registered_mimes, [Mime::FOO]
    ensure
      Mime::Type.unregister(:FOO)
    end
  end

  test "custom type with extension aliases" do
    begin
      Mime::Type.register "text/foobar", :foobar, [], [:foo, "bar"]
      %w[foobar foo bar].each do |extension|
        assert_equal Mime::FOOBAR, Mime::EXTENSION_LOOKUP[extension]
      end
    ensure
      Mime::Type.unregister(:FOOBAR)
    end
  end

  test "register alias" do
    begin
      Mime::Type.register_alias "application/xhtml+xml", :foobar
      assert_equal Mime::HTML, Mime::EXTENSION_LOOKUP['foobar']
    ensure
      Mime::Type.unregister(:FOOBAR)
    end
  end

  test "type should be equal to symbol" do
    assert_equal Mime::HTML, 'application/xhtml+xml'
    assert_equal Mime::HTML, :html
  end

  test "type convenience methods" do
    # Don't test Mime::ALL, since it Mime::ALL#html? == true
    types = Mime::SET.symbols.uniq - [:all, :iphone]

    # Remove custom Mime::Type instances set in other tests, like Mime::GIF and Mime::IPHONE
    types.delete_if { |type| !Mime.const_defined?(type.upcase) }


    types.each do |type|
      mime = Mime.const_get(type.upcase)
      assert mime.respond_to?("#{type}?"), "#{mime.inspect} does not respond to #{type}?"
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
    all_types.delete_if { |type| !Mime.const_defined?(type.upcase) }
    assert_deprecated do
      verified, unverified = all_types.partition { |type| Mime::Type.browser_generated_types.include? type }
      assert verified.each   { |type| assert  Mime.const_get(type.upcase).verify_request?, "Verifiable Mime Type is not verified: #{type.inspect}" }
      assert unverified.each { |type| assert !Mime.const_get(type.upcase).verify_request?, "Nonverifiable Mime Type is verified: #{type.inspect}" }
    end
  end

  test "references gives preference to symbols before strings" do
    assert_equal :html, Mime::HTML.ref
    another = Mime::Type.lookup("foo/bar")
    assert_nil another.to_sym
    assert_equal "foo/bar", another.ref
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
