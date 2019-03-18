module ResolverSharedTests
  attr_reader :tmpdir

  def run(*args)
    capture_exceptions do
      Dir.mktmpdir(nil, __dir__) { |dir| @tmpdir = dir; super }
    end
  end

  def with_file(filename, source="File at #{filename}")
    path = File.join(tmpdir, filename)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, source)
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

  def test_doesnt_find_template_with_wrong_details
    with_file "test/hello_world.html.erb", "Hello plain text!"

    templates = resolver.find_all("hello_world", "test", false, locale: [], formats: [:xml], variants: :any, handlers: [:builder])
    assert_equal 0, templates.size

    templates = resolver.find_all("hello_world", "test", false, locale: [], formats: [:xml], variants: :any, handlers: [:erb])
    assert_equal 0, templates.size
  end
end
