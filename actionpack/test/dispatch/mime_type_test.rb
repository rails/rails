require 'abstract_unit'

class MimeTypeTest < ActiveSupport::TestCase

  test "parse single" do
    Mime::LOOKUP.each_key do |mime_type|
      unless mime_type == 'image/*'
        assert_equal [Mime::Type.lookup(mime_type)], Mime::Type.parse(mime_type)
      end
    end
  end

  test "unregister" do
    begin
      Mime::Type.register("text/x-mobile", :mobile)
      assert Mime::Type.registered?(:MOBILE)
      assert_equal Mime::Type[:MOBILE], Mime::LOOKUP['text/x-mobile']
      assert_equal Mime::Type[:MOBILE], Mime::EXTENSION_LOOKUP['mobile']

      Mime::Type.unregister(:mobile)
      assert !Mime.const_defined?(:MOBILE), "Mime::MOBILE should not be defined"
      assert !Mime::LOOKUP.has_key?('text/x-mobile'), "Mime::LOOKUP should not have key ['text/x-mobile]"
      assert !Mime::EXTENSION_LOOKUP.has_key?('mobile'), "Mime::EXTENSION_LOOKUP should not have key ['mobile]"
    ensure
      Mime::LOOKUP.reject!{|key,_| key == 'text/x-mobile'}
    end
  end

  test "parse text with trailing star at the beginning" do
    accept = "text/*, text/html, application/json, multipart/form-data"
    expect = [Mime::Type[:HTML], Mime::Type[:TEXT], Mime::Type[:JS], Mime::Type[:CSS], Mime::Type[:ICS], Mime::Type[:CSV], Mime::Type[:VCF], Mime::Type[:XML], Mime::Type[:YAML], Mime::Type[:JSON], Mime::Type[:MULTIPART_FORM]]
    parsed = Mime::Type.parse(accept)
    assert_equal expect, parsed
  end

  test "parse text with trailing star in the end" do
    accept = "text/html, application/json, multipart/form-data, text/*"
    expect = [Mime::Type[:HTML], Mime::Type[:JSON], Mime::Type[:MULTIPART_FORM], Mime::Type[:TEXT], Mime::Type[:JS], Mime::Type[:CSS], Mime::Type[:ICS], Mime::Type[:CSV], Mime::Type[:VCF], Mime::Type[:XML], Mime::Type[:YAML]]
    parsed = Mime::Type.parse(accept)
    assert_equal expect, parsed
  end

  test "parse text with trailing star" do
    accept = "text/*"
    expect = [Mime::Type[:HTML], Mime::Type[:TEXT], Mime::Type[:JS], Mime::Type[:CSS], Mime::Type[:ICS], Mime::Type[:CSV], Mime::Type[:VCF], Mime::Type[:XML], Mime::Type[:YAML], Mime::Type[:JSON]]
    parsed = Mime::Type.parse(accept)
    assert_equal expect, parsed
  end

  test "parse application with trailing star" do
    accept = "application/*"
    expect = [Mime::Type[:HTML], Mime::Type[:JS], Mime::Type[:XML], Mime::Type[:RSS], Mime::Type[:ATOM], Mime::Type[:YAML], Mime::Type[:URL_ENCODED_FORM], Mime::Type[:JSON], Mime::Type[:PDF], Mime::Type[:ZIP]]
    parsed = Mime::Type.parse(accept)
    assert_equal expect, parsed
  end

  test "parse without q" do
    accept = "text/xml,application/xhtml+xml,text/yaml,application/xml,text/html,image/png,text/plain,application/pdf,*/*"
    expect = [Mime::Type[:HTML], Mime::Type[:XML], Mime::Type[:YAML], Mime::Type[:PNG], Mime::Type[:TEXT], Mime::Type[:PDF], Mime::Type[:ALL]]
    assert_equal expect, Mime::Type.parse(accept)
  end

  test "parse with q" do
    accept = "text/xml,application/xhtml+xml,text/yaml; q=0.3,application/xml,text/html; q=0.8,image/png,text/plain; q=0.5,application/pdf,*/*; q=0.2"
    expect = [Mime::Type[:HTML], Mime::Type[:XML], Mime::Type[:PNG], Mime::Type[:PDF], Mime::Type[:TEXT], Mime::Type[:YAML], Mime::Type[:ALL]]
    assert_equal expect, Mime::Type.parse(accept)
  end

  test "parse single media range with q" do
    accept = "text/html;q=0.9"
    expect = [Mime::Type[:HTML]]
    assert_equal expect, Mime::Type.parse(accept)
  end

  test "parse arbitrary media type parameters" do
    accept = 'multipart/form-data; boundary="simple boundary"'
    expect = [Mime::Type[:MULTIPART_FORM]]
    assert_equal expect, Mime::Type.parse(accept)
  end

  # Accept header send with user HTTP_USER_AGENT: Sunrise/0.42j (Windows XP)
  test "parse broken acceptlines" do
    accept = "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/*,,*/*;q=0.5"
    expect = [Mime::Type[:HTML], Mime::Type[:XML], "image/*", Mime::Type[:TEXT], Mime::Type[:ALL]]
    assert_equal expect, Mime::Type.parse(accept).collect(&:to_s)
  end

  # Accept header send with user HTTP_USER_AGENT: Mozilla/4.0
  #  (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322; InfoPath.1)
  test "parse other broken acceptlines" do
    accept = "image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, application/vnd.ms-excel, application/vnd.ms-powerpoint, application/msword,  , pronto/1.00.00, sslvpn/1.00.00.00, */*"
    expect = ['image/gif', 'image/x-xbitmap', 'image/jpeg','image/pjpeg', 'application/x-shockwave-flash', 'application/vnd.ms-excel', 'application/vnd.ms-powerpoint', 'application/msword', 'pronto/1.00.00', 'sslvpn/1.00.00.00', Mime::Type[:ALL]]
    assert_equal expect, Mime::Type.parse(accept).collect(&:to_s)
  end

  test "custom type" do
    begin
      type = Mime::Type.register("image/foo", :foo)
      assert_equal Mime::Type[:FOO], type
      assert Mime::Type.registered?(:FOO)
    ensure
      Mime::Type.unregister(:FOO)
    end
  end

  test "custom type with type aliases" do
    begin
      Mime::Type.register "text/foobar", :foobar, ["text/foo", "text/bar"]
      %w[text/foobar text/foo text/bar].each do |type|
        assert_equal Mime::Type[:FOOBAR], type
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
      assert_equal [Mime::Type[:FOO]], registered_mimes
    ensure
      Mime::Type.unregister(:FOO)
    end
  end

  test "custom type with extension aliases" do
    begin
      Mime::Type.register "text/foobar", :foobar, [], [:foo, "bar"]
      %w[foobar foo bar].each do |extension|
        assert_equal Mime::Type[:FOOBAR], Mime::EXTENSION_LOOKUP[extension]
      end
    ensure
      Mime::Type.unregister(:FOOBAR)
    end
  end

  test "register alias" do
    begin
      Mime::Type.register_alias "application/xhtml+xml", :foobar
      assert_equal Mime::Type[:HTML], Mime::EXTENSION_LOOKUP['foobar']
    ensure
      Mime::Type.unregister(:FOOBAR)
    end
  end

  test "type should be equal to symbol" do
    assert_equal Mime::Type[:HTML], 'application/xhtml+xml'
    assert_equal Mime::Type[:HTML], :html
  end

  test "type convenience methods" do
    # Don't test Mime::Type[:ALL], since it Mime::Type[:ALL].html? == true
    types = Mime::SET.symbols.uniq - [:all, :iphone]

    # Remove custom Mime::Type instances set in other tests, like Mime::Type[:GIF] and Mime::Type[:IPHONE]
    types.delete_if { |type| !Mime::Type.registered?(type.upcase) }

    types.each do |type|
      mime = Mime::Type[type.upcase]
      assert mime.respond_to?("#{type}?"), "#{mime.inspect} does not respond to #{type}?"
      assert_equal type, mime.symbol, "#{mime.inspect} is not #{type}?"
      invalid_types = types - [type]
      invalid_types.delete(:html)
      invalid_types.each { |other_type|
        assert_not_equal mime.symbol, other_type, "#{mime.inspect} is #{other_type}?"
      }
    end
  end

  test "mime all is html" do
    assert Mime::Type[:ALL].all?,  "Mime::ALL is not all?"
    assert Mime::Type[:ALL].html?, "Mime::ALL is not html?"
  end

  test "deprecated lookup" do
    assert_deprecated do
      assert Mime::ALL.all?,  "Mime::ALL is not all?"
    end
  end

  test "verifiable mime types" do
    all_types = Mime::SET.symbols
    all_types.uniq!
    # Remove custom Mime::Type instances set in other tests, like Mime::Type[:GIF] and Mime::Type[:IPHONE]
    all_types.delete_if { |type| !Mime::Type.registered?(type.upcase) }
  end

  test "references gives preference to symbols before strings" do
    assert_equal :html, Mime::Type[:HTML].ref
    another = Mime::Type.lookup("foo/bar")
    assert_nil another.to_sym
    assert_equal "foo/bar", another.ref
  end

  test "regexp matcher" do
    assert Mime::Type[:JS] =~ "text/javascript"
    assert Mime::Type[:JS] =~ "application/javascript"
    assert Mime::Type[:JS] !~ "text/html"
    assert !(Mime::Type[:JS] !~ "text/javascript")
    assert !(Mime::Type[:JS] !~ "application/javascript")
    assert Mime::Type[:HTML] =~ 'application/xhtml+xml'
  end
end
