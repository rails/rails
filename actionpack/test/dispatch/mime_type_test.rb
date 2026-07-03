# frozen_string_literal: true

require "abstract_unit"
require "active_support/testing/ractors_assertions"

class MimeTypeTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::RactorsAssertions

  test "Mime::Type instances are shareable" do
    assert_ractor_shareable Mime[:html]
    assert_ractor_shareable Mime::ALL
    assert_ractor_shareable Mime::Type.new("application/x-custom")
  end

  test "parse single" do
    Mime.lookup_by_string.each_key do |mime_type|
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

  test "Mime::SET, Mime::LOOKUP and Mime::EXTENSION_LOOKUP are deprecated" do
    assert_deprecated("Mime::SET", ActionDispatch.deprecator) { Mime::SET.symbols }
    assert_deprecated("Mime::LOOKUP", ActionDispatch.deprecator) { Mime::LOOKUP.key?("text/html") }
    assert_deprecated("Mime::EXTENSION_LOOKUP", ActionDispatch.deprecator) { Mime::EXTENSION_LOOKUP["html"] }
  end

  test "parse text with trailing star at the beginning" do
    accept = "text/*, text/html, application/json, multipart/form-data"
    expect = [Mime[:html], Mime[:text], Mime[:js], Mime[:css], Mime[:ics], Mime[:csv], Mime[:vcf], Mime[:vtt], Mime[:markdown], Mime[:xml], Mime[:yaml], Mime[:json], Mime[:multipart_form]]
    parsed = Mime::Type.parse(accept)
    assert_equal expect.map(&:to_s), parsed.map(&:to_s)
  end

  test "parse text with trailing star in the end" do
    accept = "text/html, application/json, multipart/form-data, text/*"
    expect = [Mime[:html], Mime[:json], Mime[:multipart_form], Mime[:text], Mime[:js], Mime[:css], Mime[:ics], Mime[:csv], Mime[:vcf], Mime[:vtt], Mime[:markdown], Mime[:xml], Mime[:yaml]]
    parsed = Mime::Type.parse(accept)
    assert_equal expect.map(&:to_s), parsed.map(&:to_s)
  end

  test "parse text with trailing star" do
    accept = "text/*"
    expect = [Mime[:html], Mime[:text], Mime[:js], Mime[:css], Mime[:ics], Mime[:csv], Mime[:vcf], Mime[:vtt], Mime[:xml], Mime[:yaml], Mime[:json], Mime[:markdown]]
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

  test "parse with q and media type parameters" do
    accept = "text/xml,application/xhtml+xml,text/yaml; q=0.3,application/xml,text/html; q=0.8,image/png,text/plain; q=0.5,application/pdf,*/*; encoding=UTF-8; q=0.2"
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

  test "parse arbitrary media type parameters with comma" do
    accept = 'multipart/form-data; boundary="simple, boundary"'
    expect = [Mime[:multipart_form]]
    assert_equal expect, Mime::Type.parse(accept)
  end

  test "parse arbitrary media type parameters with comma and additional media type" do
    accept = 'multipart/form-data; boundary="simple, boundary", text/xml'
    expect = [Mime[:multipart_form], Mime[:xml]]
    assert_equal expect, Mime::Type.parse(accept)
  end

  test "parse wildcard with arbitrary media type parameters" do
    accept = '*/*; boundary="simple"'
    expect = ["*/*"]
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
    type = Mime::Type.register("image/foo", :foo)
    assert_equal type, Mime[:foo]
  ensure
    Mime::Type.unregister(:foo)
  end

  test "extensions enumerates every registered extension, including synonyms" do
    assert_includes Mime.extensions, "html"
    assert_includes Mime.extensions, "jpg"
    assert_includes Mime.extensions, "jpeg"
  end

  test "extensions includes custom extension aliases" do
    Mime::Type.register "text/foobar", :foobar, [], [:foo, "bar"]
    assert_includes Mime.extensions, "foobar"
    assert_includes Mime.extensions, "foo"
    assert_includes Mime.extensions, "bar"
  ensure
    Mime::Type.unregister(:foobar)
  end

  test "custom type with type aliases" do
    Mime::Type.register "text/foobar", :foobar, ["text/foo", "text/bar"]
    %w[text/foobar text/foo text/bar].each do |type|
      assert_equal Mime[:foobar], type
    end
  ensure
    Mime::Type.unregister(:foobar)
  end

  test "custom type with url parameter" do
    accept = 'application/vnd.api+json; profile="https://jsonapi.org/profiles/example"'
    type = Mime::Type.register(accept, :example_api)
    assert_equal type, Mime[:example_api]
    assert_equal [type], Mime::Type.parse(accept)
  ensure
    Mime::Type.unregister(:example_api)
  end

  test "on_change callbacks fire on register and unregister" do
    changes = []
    Mime::Type.on_change do |mime, registered|
      changes << [mime, registered]
    end

    mime = Mime::Type.register("text/foo", :foo)
    assert_equal [[mime, true]], changes

    Mime::Type.unregister(:foo)
    assert_equal [[mime, true], [mime, false]], changes
  ensure
    Mime::Type.unregister(:foo)
  end

  test "register_callback is deprecated and only fires on register" do
    registered_mimes = []
    assert_deprecated("register_callback is deprecated", ActionDispatch.deprecator) do
      Mime::Type.register_callback { |mime| registered_mimes << mime }
    end

    mime = Mime::Type.register("text/foo", :foo)
    assert_equal [mime], registered_mimes

    Mime::Type.unregister(:foo)
    assert_equal [mime], registered_mimes
  ensure
    Mime::Type.unregister(:foo)
  end

  test "custom type with extension aliases" do
    Mime::Type.register "text/foobar", :foobar, [], [:foo, "bar"]
    %w[foobar foo bar].each do |extension|
      assert_equal Mime[:foobar], Mime[extension]
    end
  ensure
    Mime::Type.unregister(:foobar)
  end

  test "register alias" do
    Mime::Type.register_alias "application/xhtml+xml", :foobar
    assert_equal Mime[:html], Mime["foobar"]
  ensure
    Mime::Type.unregister(:foobar)
  end

  test "type should be equal to symbol" do
    assert_operator Mime[:html], :==, "application/xhtml+xml"
    assert_operator Mime[:html], :==, :html
  end

  test "type convenience methods" do
    types = Mime.symbols.uniq - [:iphone]

    types.each do |type|
      mime = Mime[type]
      assert_respond_to mime, "#{type}?"
      assert_equal type, mime.symbol, "#{mime.inspect} is not #{type}?"
      invalid_types = types - [type]
      invalid_types.delete(:html)
      invalid_types.each { |other_type|
        assert_not_equal mime.symbol, other_type, "#{mime.inspect} is #{other_type}?"
      }
    end
  end

  test "html? is true for the html symbol and for any type whose string contains \"html\"" do
    assert_predicate Mime[:html], :html?
    assert_predicate Mime::Type.new("application/xhtml+xml"), :html?
    assert_not_predicate Mime[:json], :html?
    assert_not_predicate Mime[:xml], :html?
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
    assert_not (Mime[:js] !~ "text/javascript")
    assert_not (Mime[:js] !~ "application/javascript")
    assert Mime[:html] =~ "application/xhtml+xml"
  end

  test "match?" do
    assert Mime[:js].match?("text/javascript")
    assert Mime[:js].match?("application/javascript")
    assert_not Mime[:js].match?("text/html")
  end

  test "=~ and match? return false for nil" do
    assert_not (Mime[:js] =~ nil)
    assert_not Mime[:js].match?(nil)
  end

  test "=== matches when the type is included in an array" do
    assert Mime[:html] === [Mime[:html], Mime[:xml]]
    assert_not Mime[:html] === [Mime[:xml], Mime[:json]]
  end

  test "can be initialized with wildcards" do
    assert_equal "*/*", Mime::Type.new("*/*").to_s
    assert_equal "text/*", Mime::Type.new("text/*").to_s
    assert_equal "video/*", Mime::Type.new("video/*").to_s
  end

  test "can be initialized with parameters" do
    assert_equal "text/html; parameter", Mime::Type.new("text/html; parameter").to_s
    assert_equal "text/html; parameter=abc", Mime::Type.new("text/html; parameter=abc").to_s
    assert_equal 'text/html; parameter="abc"', Mime::Type.new('text/html; parameter="abc"').to_s
    assert_equal 'text/html; parameter=abc; parameter2="xyz"', Mime::Type.new('text/html; parameter=abc; parameter2="xyz"').to_s
  end

  test "can be initialized with parameters without having space after ;" do
    assert_equal "text/html;parameter", Mime::Type.new("text/html;parameter").to_s
    assert_equal 'text/html;parameter=abc;parameter2="xyz"', Mime::Type.new('text/html;parameter=abc;parameter2="xyz"').to_s
  end

  test "invalid mime types raise error" do
    assert_raises Mime::Type::InvalidMimeType do
      Mime::Type.new("too/many/slash")
    end

    assert_raises Mime::Type::InvalidMimeType do
      Mime::Type.new("missingslash")
    end

    assert_raises Mime::Type::InvalidMimeType do
      Mime::Type.new("improper/semicolon;")
    end

    assert_raises Mime::Type::InvalidMimeType do
      Mime::Type.new('improper/semicolon; parameter=abc; parameter2="xyz";')
    end

    assert_raises Mime::Type::InvalidMimeType do
      Mime::Type.new("text/html, text/plain")
    end

    assert_raises Mime::Type::InvalidMimeType do
      Mime::Type.new("*/html")
    end

    assert_raises Mime::Type::InvalidMimeType do
      Mime::Type.new("")
    end

    assert_raises Mime::Type::InvalidMimeType do
      Mime::Type.new(nil)
    end

    assert_raises Mime::Type::InvalidMimeType do
      Timeout.timeout(1) do # Shouldn't take more than 1s
        Mime::Type.new("text/html ;0 ;0 ;0 ;0 ;0 ;0 ;0 ;0 ;0 ;0 ;0 ;0 ;0 ;0 ;0 ;0 ;0 ;0;")
      end
    end
  end

  test "Mime.symbols returns a live reference that tracks register and unregister" do
    symbols = Mime.symbols

    Mime::Type.register_alias "application/xhtml+xml", :foobar
    assert_includes symbols, :foobar

    Mime::Type.unregister(:foobar)
    assert_not_includes symbols, :foobar
  ensure
    Mime::Type.unregister(:foobar)
  end
end

class MimeTypeRegistryFreezeTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation
  include ActiveSupport::Testing::RactorsAssertions

  test "after eager_load! the registries are shareable" do
    Mime.eager_load!

    assert_ractor_shareable Mime.registry
    assert_ractor_shareable Mime.lookup_by_string
    assert_ractor_shareable Mime.lookup_by_extension
  end

  test "registering after eager_load! is deprecated, falls back to copy-on-write, and stays shareable" do
    Mime.eager_load!

    assert_deprecated("after the application has been initialized", ActionDispatch.deprecator) do
      Mime::Type.register("text/x-ractor", :ractor)
    end

    assert_equal Mime[:ractor], Mime::Type.lookup("text/x-ractor")
    assert_includes Mime.symbols, :ractor

    assert_ractor_shareable Mime.registry
    assert_ractor_shareable Mime.lookup_by_string
    assert_ractor_shareable Mime.lookup_by_extension
  end

  test "after eager_load! a reference captured before the freeze no longer tracks unregister" do
    Mime::Type.register_alias "application/xhtml+xml", :foobar
    captured = Mime.symbols
    Mime.eager_load!

    assert_includes captured, :foobar

    assert_deprecated("after the application has been initialized", ActionDispatch.deprecator) do
      Mime::Type.unregister(:foobar)
    end

    assert_not_includes Mime.symbols, :foobar
    assert_includes captured, :foobar
  end

  test "deprecated Mime::SET, Mime::LOOKUP and Mime::EXTENSION_LOOKUP proxies reflect registration after eager_load!" do
    Mime.eager_load!

    assert_deprecated("after the application has been initialized", ActionDispatch.deprecator) do
      Mime::Type.register("text/x-ractor", :ractor)
    end

    assert_deprecated("Mime::SET is deprecated", ActionDispatch.deprecator) do
      assert_includes Mime::SET.symbols, :ractor
    end
    assert_deprecated("Mime::LOOKUP is deprecated", ActionDispatch.deprecator) do
      assert_equal Mime[:ractor], Mime::LOOKUP["text/x-ractor"]
    end
    assert_deprecated("Mime::EXTENSION_LOOKUP is deprecated", ActionDispatch.deprecator) do
      assert_equal Mime[:ractor], Mime::EXTENSION_LOOKUP["ractor"]
    end
  end
end
