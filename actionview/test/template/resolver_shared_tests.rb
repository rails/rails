# frozen_string_literal: true

module ResolverSharedTests
  attr_reader :tmpdir

  def run(*args)
    capture_exceptions do
      Dir.mktmpdir(nil, __dir__) { |dir| @tmpdir = dir; super }
    end
  end

  def with_file(filename, source = "File at #{filename}")
    path = File.join(tmpdir, filename)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, source)
  end

  def context
    @context ||= ActionView::LookupContext.new(resolver)
  end

  def test_can_find_with_no_extensions
    with_file "test/hello_world", "Hello default!"

    templates = resolver.find_all("hello_world", "test", false, locale: [:en], formats: [:html], variants: [:phone], handlers: [:erb])
    assert_equal 1, templates.size
    assert_equal "Hello default!",   templates[0].source
    assert_equal "test/hello_world", templates[0].virtual_path
    assert_nil templates[0].format
    assert_nil templates[0].variant
    assert_kind_of ActionView::Template::Handlers::Raw, templates[0].handler
  end

  def test_can_find_with_just_handler
    with_file "test/hello_world.erb", "Hello erb!"

    templates = resolver.find_all("hello_world", "test", false, locale: [:en], formats: [:html], variants: [:phone], handlers: [:erb])
    assert_equal 1, templates.size
    assert_equal "Hello erb!",   templates[0].source
    assert_equal "test/hello_world", templates[0].virtual_path
    assert_nil templates[0].format
    assert_nil templates[0].variant
    assert_kind_of ActionView::Template::Handlers::ERB, templates[0].handler
  end

  def test_can_find_with_format_and_handler
    with_file "test/hello_world.text.builder", "Hello plain text!"

    templates = resolver.find_all("hello_world", "test", false, locale: [:en], formats: [:html, :text], variants: [:phone], handlers: [:erb, :builder])
    assert_equal 1, templates.size
    assert_equal "Hello plain text!", templates[0].source
    assert_equal "test/hello_world",  templates[0].virtual_path
    assert_equal :text, templates[0].format
    assert_nil templates[0].variant
    assert_kind_of ActionView::Template::Handlers::Builder, templates[0].handler
  end

  def test_can_find_with_variant_format_and_handler
    with_file "test/hello_world.html+phone.erb", "Hello plain text!"

    templates = resolver.find_all("hello_world", "test", false, locale: [:en], formats: [:html], variants: [:phone], handlers: [:erb])
    assert_equal 1, templates.size
    assert_equal "Hello plain text!", templates[0].source
    assert_equal "test/hello_world",  templates[0].virtual_path
    assert_equal :html, templates[0].format
    assert_equal "phone", templates[0].variant
    assert_kind_of ActionView::Template::Handlers::ERB, templates[0].handler
  end

  def test_can_find_with_any_variant_format_and_handler
    with_file "test/hello_world.html+phone.erb", "Hello plain text!"

    templates = resolver.find_all("hello_world", "test", false, locale: [:en], formats: [:html], variants: :any, handlers: [:erb])
    assert_equal 1, templates.size
    assert_equal "Hello plain text!", templates[0].source
    assert_equal "test/hello_world",  templates[0].virtual_path
    assert_equal :html, templates[0].format
    assert_equal "phone", templates[0].variant
    assert_kind_of ActionView::Template::Handlers::ERB, templates[0].handler
  end

  def test_can_find_when_special_chars_in_path
    dir = "test +()[]{}"
    with_file "#{dir}/hello_world", "Hello funky path!"

    templates = resolver.find_all("hello_world", dir, false, locale: [:en], formats: [:html], variants: [:phone], handlers: [:erb])
    assert_equal 1, templates.size
    assert_equal "Hello funky path!", templates[0].source
    assert_equal "#{dir}/hello_world", templates[0].virtual_path
  end

  def test_doesnt_find_template_with_wrong_details
    with_file "test/hello_world.html.erb", "Hello plain text!"

    templates = resolver.find_all("hello_world", "test", false, locale: [], formats: [:xml], variants: :any, handlers: [:builder])
    assert_equal 0, templates.size

    templates = resolver.find_all("hello_world", "test", false, locale: [], formats: [:xml], variants: :any, handlers: [:erb])
    assert_equal 0, templates.size
  end

  def test_found_template_is_cached
    with_file "test/hello_world.html.erb", "Hello HTML!"

    a = context.find("hello_world", "test", false, [], {})
    b = context.find("hello_world", "test", false, [], {})
    assert_same a, b
  end

  def test_different_templates_when_cache_disabled
    with_file "test/hello_world.html.erb", "Hello HTML!"

    a = context.find("hello_world", "test", false, [], {})
    b = context.disable_cache { context.find("hello_world", "test", false, [], {}) }
    c = context.find("hello_world", "test", false, [], {})

    # disable_cache should give us a new object
    assert_not_same a, b

    # but it should not clear the cache
    assert_same a, c
  end

  def test_same_template_from_different_details_is_same_object
    with_file "test/hello_world.html.erb", "Hello HTML!"

    a = context.find("hello_world", "test", false, [], locale: [:en])
    b = context.find("hello_world", "test", false, [], locale: [:fr])
    assert_same a, b
  end

  def test_templates_with_optional_locale_shares_common_object
    with_file "test/hello_world.text.erb", "Generic plain text!"
    with_file "test/hello_world.fr.text.erb", "Texte en Francais!"

    en = context.find_all("hello_world", "test", false, [], locale: [:en])
    fr = context.find_all("hello_world", "test", false, [], locale: [:fr])

    assert_equal 1, en.size
    assert_equal 2, fr.size

    assert_equal "Generic plain text!", en[0].source
    assert_equal "Texte en Francais!",  fr[0].source
    assert_equal "Generic plain text!", fr[1].source

    assert_same en[0], fr[1]
  end

  def test_templates_sort_by_formats_json_first
    with_file "test/hello_world.html.erb", "Hello HTML!"
    with_file "test/hello_world.json.builder", "Hello JSON!"

    templates = resolver.find_all("hello_world", "test", false, locale: [], formats: [:json, :html], variants: :any, handlers: [:erb, :builder])

    assert_equal 2, templates.size
    assert_equal "Hello JSON!", templates[0].source
    assert_equal :json, templates[0].format
    assert_equal "Hello HTML!", templates[1].source
    assert_equal :html, templates[1].format
  end

  def test_templates_sort_by_formats_html_first
    with_file "test/hello_world.html.erb", "Hello HTML!"
    with_file "test/hello_world.json.builder", "Hello JSON!"

    templates = resolver.find_all("hello_world", "test", false, locale: [], formats: [:html, :json], variants: :any, handlers: [:erb, :builder])

    assert_equal 2, templates.size
    assert_equal "Hello HTML!", templates[0].source
    assert_equal :html, templates[0].format
    assert_equal "Hello JSON!", templates[1].source
    assert_equal :json, templates[1].format
  end

  def test_templates_with_variant
    with_file "test/hello_world.html+mobile.erb", "Hello HTML!"

    templates = resolver.find_all("hello_world", "test", false, locale: [], formats: [:html, :json], variants: :any, handlers: [:erb, :builder])

    assert_equal 1, templates.size
    assert_equal "Hello HTML!", templates[0].source
    assert_kind_of ActionView::Template::Handlers::ERB, templates[0].handler
    assert_equal :html, templates[0].format
    assert_equal "mobile", templates[0].variant
  end

  def test_finds_variants_in_order
    with_file "test/hello_world.html+tricorder.erb", "Hello Spock!"
    with_file "test/hello_world.html+lcars.erb", "Hello Geordi!"

    tricorder = context.find("hello_world", "test", false, [], { variants: [:tricorder] })
    lcars = context.find("hello_world", "test", false, [], { variants: [:lcars] })

    assert_equal "Hello Spock!", tricorder.source
    assert_equal "tricorder", tricorder.variant
    assert_equal "Hello Geordi!", lcars.source
    assert_equal "lcars", lcars.variant

    templates = context.find_all("hello_world", "test", false, [], { variants: [:tricorder, :lcars] })
    assert_equal [tricorder, lcars], templates

    templates = context.find_all("hello_world", "test", false, [], { variants: [:lcars, :tricorder] })
    assert_equal [lcars, tricorder], templates
  end

  def test_templates_no_format_with_variant
    with_file "test/hello_world+mobile.erb", "Hello HTML!"

    templates = resolver.find_all("hello_world", "test", false, locale: [], formats: [:html, :json], variants: :any, handlers: [:erb, :builder])

    assert_equal 1, templates.size
    assert_equal "Hello HTML!", templates[0].source
    assert_kind_of ActionView::Template::Handlers::ERB, templates[0].handler
    assert_nil templates[0].format
    assert_equal "mobile", templates[0].variant
  end

  def test_templates_no_format_or_handler_with_variant
    with_file "test/hello_world+mobile", "Hello HTML!"

    templates = resolver.find_all("hello_world", "test", false, locale: [], formats: [:html, :json], variants: :any, handlers: [:erb, :builder])

    assert_equal 1, templates.size
    assert_equal "Hello HTML!", templates[0].source
    assert_kind_of ActionView::Template::Handlers::Raw, templates[0].handler
    assert_nil templates[0].format
    assert_equal "mobile", templates[0].variant
  end

  def test_returns_no_results_with_dot
    with_file "test/hello_world.html.erb", "Hello html!"

    assert_empty context.find_all("hello_world.html", "test", false, [], {})
  end

  def test_finds_template_with_lowdash_format
    with_file "test/hello_world.es_AR.text.erb", "Texto simple!"

    es_ar = context.find_all("hello_world", "test", false, [], locale: [:es_AR])

    assert_equal 1, es_ar.size

    assert_equal "Texto simple!", es_ar[0].source
  end

  def test_finds_template_with_arbitrarily_formatted_locale
    I18n.backend.store_translations(:en_customer1, { hello: "hello" })
    with_file "test/hello_world.en_customer1.text.erb", "Good day, world."

    templates = context.find_all("hello_world", "test", false, [], locale: [:en_customer1])

    assert_equal 1, templates.size
    assert_equal "Good day, world.", templates[0].source
  ensure
    I18n.reload!
  end
end
