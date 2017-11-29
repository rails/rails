# frozen_string_literal: true

require "abstract_unit"

class MimeTypeTest < ActiveSupport::TestCase
  test "parse single" do
    Mime::LOOKUP.each_key do |mime_type|
      unless mime_type == "image/*"
        assert_equal [Mime::Type.lookup(mime_type)], Mime::Type.parse(mime_type)
      end
    end
  end

  test "unregister" do
    assert_nil Mime[:mobile]

    begin
      mime = Mime::Type.register("text/x-mobile", :mobile)
      assert_equal mime, Mime[:mobile]
      assert_equal mime, Mime::Type.lookup("text/x-mobile")
      assert_equal mime, Mime::Type.lookup_by_extension(:mobile)

      Mime::Type.unregister(:mobile)
      assert_nil Mime[:mobile], "Mime[:mobile] should be nil after unregistering :mobile"
      assert_nil Mime::Type.lookup_by_extension(:mobile), "Should be missing MIME extension lookup for :mobile"
    ensure
      Mime::Type.unregister :mobile
    end
  end

  test "parse text with trailing star at the beginning" do
    accept = "text/*, text/html, application/json, multipart/form-data"
    expect = [Mime[:html], Mime[:text], Mime[:js], Mime[:css], Mime[:ics], Mime[:csv], Mime[:vcf], Mime[:vtt], Mime[:xml], Mime[:yaml], Mime[:json], Mime[:multipart_form]]
    parsed = Mime::Type.parse(accept)
    assert_equal expect.map(&:to_s), parsed.map(&:to_s)
  end

  test "parse text with trailing star in the end" do
    accept = "text/html, application/json, multipart/form-data, text/*"
    expect = [Mime[:html], Mime[:json], Mime[:multipart_form], Mime[:text], Mime[:js], Mime[:css], Mime[:ics], Mime[:csv], Mime[:vcf], Mime[:vtt], Mime[:xml], Mime[:yaml]]
    parsed = Mime::Type.parse(accept)
    assert_equal expect.map(&:to_s), parsed.map(&:to_s)
  end

  test "parse text with trailing star" do
    accept = "text/*"
    expect = [Mime[:html], Mime[:text], Mime[:js], Mime[:css], Mime[:ics], Mime[:csv], Mime[:vcf], Mime[:vtt], Mime[:xml], Mime[:yaml], Mime[:json]]
    parsed = Mime::Type.parse(accept)
    assert_equal expect.map(&:to_s).sort!, parsed.map(&:to_s).sort!
  end

  test "parse application with trailing star" do
    accept = "application/*"
    expect = [Mime[:html], Mime[:js], Mime[:xml], Mime[:rss], Mime[:atom], Mime[:yaml], Mime[:url_encoded_form], Mime[:json], Mime[:pdf], Mime[:zip], Mime[:gzip]]
    parsed = Mime::Type.parse(accept)
    assert_equal expect.map(&:to_s).sort!, parsed.map(&:to_s).sort!
  end

  test "parse without q" do
    accept = "text/xml,application/xhtml+xml,text/yaml,application/xml,text/html,image/png,text/plain,application/pdf,*/*"
    expect = [Mime[:html], Mime[:xml], Mime[:yaml], Mime[:png], Mime[:text], Mime[:pdf], "*/*"]
    assert_equal expect.map(&:to_s), Mime::Type.parse(accept).map(&:to_s)
  end

  test "parse with q" do
    accept = "text/xml,application/xhtml+xml,text/yaml; q=0.3,application/xml,text/html; q=0.8,image/png,text/plain; q=0.5,application/pdf,*/*; q=0.2"
    expect = [Mime[:html], Mime[:xml], Mime[:png], Mime[:pdf], Mime[:text], Mime[:yaml], "*/*"]
    assert_equal expect.map(&:to_s), Mime::Type.parse(accept).map(&:to_s)
  end

  test "parse single media range with q" do
    accept = "text/html;q=0.9"
    expect = [Mime[:html]]
    assert_equal expect, Mime::Type.parse(accept)
  end

  test "parse arbitrary media type parameters" do
    accept = 'multipart/form-data; boundary="simple boundary"'
    expect = [Mime[:multipart_form]]
    assert_equal expect, Mime::Type.parse(accept)
  end

  # Accept header send with user HTTP_USER_AGENT: Sunrise/0.42j (Windows XP)
  test "parse broken acceptlines" do
    accept = "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/*,,*/*;q=0.5"
    expect = [Mime[:html], Mime[:xml], "image/*", Mime[:text], "*/*"]
    assert_equal expect.map(&:to_s), Mime::Type.parse(accept).map(&:to_s)
  end

  # Accept header send with user HTTP_USER_AGENT: Mozilla/4.0
  #  (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322; InfoPath.1)
  test "parse other broken acceptlines" do
    accept = "image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, application/vnd.ms-excel, application/vnd.ms-powerpoint, application/msword,  , pronto/1.00.00, sslvpn/1.00.00.00, */*"
    expect = ["image/gif", "image/x-xbitmap", "image/jpeg", "image/pjpeg", "application/x-shockwave-flash", "application/vnd.ms-excel", "application/vnd.ms-powerpoint", "application/msword", "pronto/1.00.00", "sslvpn/1.00.00.00", "*/*"]
    assert_equal expect.map(&:to_s), Mime::Type.parse(accept).map(&:to_s)
  end

  test "custom type" do
    begin
      type = Mime::Type.register("image/foo", :foo)
      assert_equal type, Mime[:foo]
    ensure
      Mime::Type.unregister(:foo)
    end
  end

  test "custom type with type aliases" do
    begin
      Mime::Type.register "text/foobar", :foobar, ["text/foo", "text/bar"]
      %w[text/foobar text/foo text/bar].each do |type|
        assert_equal Mime[:foobar], type
      end
    ensure
      Mime::Type.unregister(:foobar)
    end
  end

  test "register callbacks" do
    begin
      registered_mimes = []
      Mime::Type.register_callback do |mime|
        registered_mimes << mime
      end

      mime = Mime::Type.register("text/foo", :foo)
      assert_equal [mime], registered_mimes
    ensure
      Mime::Type.unregister(:foo)
    end
  end

  test "custom type with extension aliases" do
    begin
      Mime::Type.register "text/foobar", :foobar, [], [:foo, "bar"]
      %w[foobar foo bar].each do |extension|
        assert_equal Mime[:foobar], Mime::EXTENSION_LOOKUP[extension]
      end
    ensure
      Mime::Type.unregister(:foobar)
    end
  end

  test "register alias" do
    begin
      Mime::Type.register_alias "application/xhtml+xml", :foobar
      assert_equal Mime[:html], Mime::EXTENSION_LOOKUP["foobar"]
    ensure
      Mime::Type.unregister(:foobar)
    end
  end

  test "type should be equal to symbol" do
    assert_equal Mime[:html], "application/xhtml+xml"
    assert_equal Mime[:html], :html
  end

  test "type convenience methods" do
    types = Mime::SET.symbols.uniq - [:iphone]

    types.each do |type|
      mime = Mime[type]
      assert mime.respond_to?("#{type}?"), "#{mime.inspect} does not respond to #{type}?"
      assert_equal type, mime.symbol, "#{mime.inspect} is not #{type}?"
      invalid_types = types - [type]
      invalid_types.delete(:html)
      invalid_types.each { |other_type|
        assert_not_equal mime.symbol, other_type, "#{mime.inspect} is #{other_type}?"
      }
    end
  end

  test "references gives preference to symbols before strings" do
    assert_equal :html, Mime[:html].ref
    another = Mime::Type.lookup("foo/bar")
    assert_nil another.to_sym
    assert_equal "foo/bar", another.ref
  end

  test "regexp matcher" do
    assert Mime[:js] =~ "text/javascript"
    assert Mime[:js] =~ "application/javascript"
    assert Mime[:js] !~ "text/html"
    assert !(Mime[:js] !~ "text/javascript")
    assert !(Mime[:js] !~ "application/javascript")
    assert Mime[:html] =~ "application/xhtml+xml"
  end
end
