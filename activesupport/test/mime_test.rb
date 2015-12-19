require 'abstract_unit'

class MimeTypeTest < ActiveSupport::TestCase
  test "parse single" do
    ActiveSupport::Mime::LOOKUP.each_key do |mime_type|
      unless mime_type == 'image/*'
        assert_equal [ActiveSupport::Mime::Type.lookup(mime_type)], ActiveSupport::Mime::Type.parse(mime_type)
      end
    end
  end

  test "unregister" do
    assert_nil ActiveSupport::Mime[:mobile]

    begin
      mime = ActiveSupport::Mime::Type.register("text/x-mobile", :mobile)
      assert_equal mime, ActiveSupport::Mime[:mobile]
      assert_equal mime, ActiveSupport::Mime::Type.lookup('text/x-mobile')
      assert_equal mime, ActiveSupport::Mime::Type.lookup_by_extension(:mobile)

      ActiveSupport::Mime::Type.unregister(:mobile)
      assert_nil ActiveSupport::Mime[:mobile], "Mime[:mobile] should be nil after unregistering :mobile"
      assert_nil ActiveSupport::Mime::Type.lookup_by_extension(:mobile), "Should be missing MIME extension lookup for :mobile"
    ensure
      ActiveSupport::Mime::Type.unregister :mobile
    end
  end

  test "parse text with trailing star at the beginning" do
    accept = "text/*, text/html, application/json, multipart/form-data"
    expect = [ActiveSupport::Mime[:html], ActiveSupport::Mime[:text], ActiveSupport::Mime[:js], ActiveSupport::Mime[:css], ActiveSupport::Mime[:ics], ActiveSupport::Mime[:csv], ActiveSupport::Mime[:vcf], ActiveSupport::Mime[:xml], ActiveSupport::Mime[:yaml], ActiveSupport::Mime[:json], ActiveSupport::Mime[:multipart_form]]
    parsed = ActiveSupport::Mime::Type.parse(accept)
    assert_equal expect, parsed
  end

  test "parse text with trailing star in the end" do
    accept = "text/html, application/json, multipart/form-data, text/*"
    expect = [ActiveSupport::Mime[:html], ActiveSupport::Mime[:json], ActiveSupport::Mime[:multipart_form], ActiveSupport::Mime[:text], ActiveSupport::Mime[:js], ActiveSupport::Mime[:css], ActiveSupport::Mime[:ics], ActiveSupport::Mime[:csv], ActiveSupport::Mime[:vcf], ActiveSupport::Mime[:xml], ActiveSupport::Mime[:yaml]]
    parsed = ActiveSupport::Mime::Type.parse(accept)
    assert_equal expect, parsed
  end

  test "parse text with trailing star" do
    accept = "text/*"
    expect = [ActiveSupport::Mime[:html], ActiveSupport::Mime[:text], ActiveSupport::Mime[:js], ActiveSupport::Mime[:css], ActiveSupport::Mime[:ics], ActiveSupport::Mime[:csv], ActiveSupport::Mime[:vcf], ActiveSupport::Mime[:xml], ActiveSupport::Mime[:yaml], ActiveSupport::Mime[:json]]
    parsed = ActiveSupport::Mime::Type.parse(accept)
    assert_equal expect, parsed
  end

  test "parse application with trailing star" do
    accept = "application/*"
    expect = [ActiveSupport::Mime[:html], ActiveSupport::Mime[:js], ActiveSupport::Mime[:xml], ActiveSupport::Mime[:rss], ActiveSupport::Mime[:atom], ActiveSupport::Mime[:yaml], ActiveSupport::Mime[:url_encoded_form], ActiveSupport::Mime[:json], ActiveSupport::Mime[:pdf], ActiveSupport::Mime[:zip]]
    parsed = ActiveSupport::Mime::Type.parse(accept)
    assert_equal expect, parsed
  end

  test "parse without q" do
    accept = "text/xml,application/xhtml+xml,text/yaml,application/xml,text/html,image/png,text/plain,application/pdf,*/*"
    expect = [ActiveSupport::Mime[:html], ActiveSupport::Mime[:xml], ActiveSupport::Mime[:yaml], ActiveSupport::Mime[:png], ActiveSupport::Mime[:text], ActiveSupport::Mime[:pdf], '*/*']
    assert_equal expect.map(&:to_s), ActiveSupport::Mime::Type.parse(accept).map(&:to_s)
  end

  test "parse with q" do
    accept = "text/xml,application/xhtml+xml,text/yaml; q=0.3,application/xml,text/html; q=0.8,image/png,text/plain; q=0.5,application/pdf,*/*; q=0.2"
    expect = [ActiveSupport::Mime[:html], ActiveSupport::Mime[:xml], ActiveSupport::Mime[:png], ActiveSupport::Mime[:pdf], ActiveSupport::Mime[:text], ActiveSupport::Mime[:yaml], '*/*']
    assert_equal expect.map(&:to_s), ActiveSupport::Mime::Type.parse(accept).map(&:to_s)
  end

  test "parse single media range with q" do
    accept = "text/html;q=0.9"
    expect = [ActiveSupport::Mime[:html]]
    assert_equal expect, ActiveSupport::Mime::Type.parse(accept)
  end

  test "parse arbitrary media type parameters" do
    accept = 'multipart/form-data; boundary="simple boundary"'
    expect = [ActiveSupport::Mime[:multipart_form]]
    assert_equal expect, ActiveSupport::Mime::Type.parse(accept)
  end

  # Accept header send with user HTTP_USER_AGENT: Sunrise/0.42j (Windows XP)
  test "parse broken acceptlines" do
    accept = "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/*,,*/*;q=0.5"
    expect = [ActiveSupport::Mime[:html], ActiveSupport::Mime[:xml], "image/*", ActiveSupport::Mime[:text], '*/*']
    assert_equal expect.map(&:to_s), ActiveSupport::Mime::Type.parse(accept).map(&:to_s)
  end

  # Accept header send with user HTTP_USER_AGENT: Mozilla/4.0
  #  (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322; InfoPath.1)
  test "parse other broken acceptlines" do
    accept = "image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, application/vnd.ms-excel, application/vnd.ms-powerpoint, application/msword,  , pronto/1.00.00, sslvpn/1.00.00.00, */*"
    expect = ['image/gif', 'image/x-xbitmap', 'image/jpeg','image/pjpeg', 'application/x-shockwave-flash', 'application/vnd.ms-excel', 'application/vnd.ms-powerpoint', 'application/msword', 'pronto/1.00.00', 'sslvpn/1.00.00.00', '*/*']
    assert_equal expect.map(&:to_s), ActiveSupport::Mime::Type.parse(accept).map(&:to_s)
  end

  test "custom type" do
    begin
      type = ActiveSupport::Mime::Type.register("image/foo", :foo)
      assert_equal type, ActiveSupport::Mime[:foo]
    ensure
      ActiveSupport::Mime::Type.unregister(:foo)
    end
  end

  test "custom type with type aliases" do
    begin
      ActiveSupport::Mime::Type.register "text/foobar", :foobar, ["text/foo", "text/bar"]
      %w[text/foobar text/foo text/bar].each do |type|
        assert_equal ActiveSupport::Mime[:foobar], type
      end
    ensure
      ActiveSupport::Mime::Type.unregister(:foobar)
    end
  end

  test "register callbacks" do
    begin
      registered_mimes = []
      ActiveSupport::Mime::Type.register_callback do |mime|
        registered_mimes << mime
      end

      mime = ActiveSupport::Mime::Type.register("text/foo", :foo)
      assert_equal [mime], registered_mimes
    ensure
      ActiveSupport::Mime::Type.unregister(:foo)
    end
  end

  test "custom type with extension aliases" do
    begin
      ActiveSupport::Mime::Type.register "text/foobar", :foobar, [], [:foo, "bar"]
      %w[foobar foo bar].each do |extension|
        assert_equal ActiveSupport::Mime[:foobar], ActiveSupport::Mime::EXTENSION_LOOKUP[extension]
      end
    ensure
      ActiveSupport::Mime::Type.unregister(:foobar)
    end
  end

  test "register alias" do
    begin
      ActiveSupport::Mime::Type.register_alias "application/xhtml+xml", :foobar
      assert_equal ActiveSupport::Mime[:html], ActiveSupport::Mime::EXTENSION_LOOKUP['foobar']
    ensure
      ActiveSupport::Mime::Type.unregister(:foobar)
    end
  end

  test "type should be equal to symbol" do
    assert_equal ActiveSupport::Mime[:html], 'application/xhtml+xml'
    assert_equal ActiveSupport::Mime[:html], :html
  end

  test "type convenience methods" do
    types = ActiveSupport::Mime::SET.symbols.uniq - [:iphone]

    types.each do |type|
      mime = ActiveSupport::Mime[type]
      assert mime.respond_to?("#{type}?"), "#{mime.inspect} does not respond to #{type}?"
      assert_equal type, mime.symbol, "#{mime.inspect} is not #{type}?"
      invalid_types = types - [type]
      invalid_types.delete(:html)
      invalid_types.each { |other_type|
        assert_not_equal mime.symbol, other_type, "#{mime.inspect} is #{other_type}?"
      }
    end
  end

  test "deprecated lookup" do
    assert_deprecated do
      ActiveSupport::Mime::HTML
    end
  end

  test "deprecated const_defined?" do
    assert_deprecated do
      ActiveSupport::Mime.const_defined? :HTML
    end
  end

  test "references gives preference to symbols before strings" do
    assert_equal :html, ActiveSupport::Mime[:html].ref
    another = ActiveSupport::Mime::Type.lookup("foo/bar")
    assert_nil another.to_sym
    assert_equal "foo/bar", another.ref
  end

  test "regexp matcher" do
    assert ActiveSupport::Mime[:js] =~ "text/javascript"
    assert ActiveSupport::Mime[:js] =~ "application/javascript"
    assert ActiveSupport::Mime[:js] !~ "text/html"
    assert !(ActiveSupport::Mime[:js] !~ "text/javascript")
    assert !(ActiveSupport::Mime[:js] !~ "application/javascript")
    assert ActiveSupport::Mime[:html] =~ 'application/xhtml+xml'
  end
end
