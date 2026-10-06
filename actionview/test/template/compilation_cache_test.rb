# frozen_string_literal: true

require "abstract_unit"
require "action_view/template_precompiler"
require "active_support/core_ext/object/with"
require "bootsnap"
require "bootsnap/compile_cache/iseq"
require "tmpdir"

class TemplateCompilationCacheTest < ActiveSupport::TestCase
  class Handler
    attr_accessor :calls

    def initialize
      @calls = 0
      @erb = ActionView::Template::Handlers::ERB.new
    end

    def call(template, source)
      @calls += 1
      @erb.call(template, source)
    end
  end

  setup do
    @directory = Dir.mktmpdir
    @views = File.join(@directory, "views")
    FileUtils.mkdir_p(@views)
    @handler = Handler.new
  end

  teardown do
    FileUtils.remove_entry(@directory)
  end

  test "reuses handler output with different locals" do
    with_cache do
      file = write_template("<%= message %>")
      template(file).compiled_handler_source

      view = ActionView::Base.with_empty_template_cache.empty
      assert_equal "hello", template(file, locals: [:message]).render(view, { message: "hello" })
      assert_equal "goodbye", template(file, locals: [:message, :extra]).render(view, { message: "goodbye", extra: true })
      assert_equal 1, @handler.calls
    end
  end

  test "detects source changes with unchanged size and mtime" do
    with_cache do
      file = write_template("before")
      original_time = File.mtime(file)
      before = template(file).compiled_handler_source
      File.write(file, "after!")
      File.utime(original_time, original_time, file)

      assert_not_equal before, template(file).compiled_handler_source
      assert_equal 2, @handler.calls
    end
  end

  test "preserves strict locals on cache hits" do
    with_cache do
      file = write_template("<%# locals: (message:) %><%= message %>")
      template(file).compiled_handler_source

      view = ActionView::Base.with_empty_template_cache.empty
      assert_equal "hello", template(file, locals: [:message]).render(view, { message: "hello" })
      assert_raises(ActionView::Template::Error) { template(file).render(view, {}) }
      assert_equal 1, @handler.calls
    end
  end

  test "rebuilds views without clearing other Bootsnap caches" do
    with_cache do
      write_template("hello\n")
      resolver = ActionView::FileSystemResolver.new(@views)
      ActionView::TemplatePrecompiler.call([resolver])
      before = resolver.all_unbound_templates.first.bind_locals([]).compiled_handler_source
      directory = ActionView::Template::CompilationCache.cache_dir
      sentinel = File.join(directory, "old-build")
      File.write(sentinel, "old")
      FileUtils.mkdir_p(Bootsnap::CompileCache::ISeq.cache_dir)
      other_cache = File.join(Bootsnap::CompileCache::ISeq.cache_dir, "other")
      File.write(other_cache, "keep")

      ActionView::Template::Handlers::ERB.with(strip_trailing_newlines: true) do
        ActionView::TemplatePrecompiler.call([resolver])
        after = resolver.all_unbound_templates.first.bind_locals([]).compiled_handler_source
        assert_not_equal before, after
      end

      assert_not File.exist?(sentinel)
      assert_equal "keep", File.read(other_cache)
    end
  end

  test "supports frozen string literals" do
    with_cache do
      file = write_template("hello")
      ActionView::Template.with(frozen_string_literal: true) do
        template(file).compiled_handler_source
        view = ActionView::Base.with_empty_template_cache.empty
        assert_equal "hello", template(file).render(view, {})
      end

      assert_equal 1, @handler.calls
    end
  end

  test "supports filename annotations" do
    with_cache do
      file = write_template("hello")

      ActionView::Base.with(annotate_rendered_view_with_filenames: true) do
        first = template(file).compiled_handler_source
        assert_includes first, "<!-- BEGIN #{file}"
        assert_equal first, template(file).compiled_handler_source
      end

      assert_equal 1, @handler.calls
    end
  end

  test "preserves generated source encoding" do
    with_cache do
      file = write_template("hello")
      handler = ->(_, _) { "'hello'".encode(Encoding::ISO_8859_1) }

      first = template(file, handler: handler).compiled_handler_source
      second = template(file, handler: handler).compiled_handler_source
      assert_equal first, second
      assert_equal Encoding::ISO_8859_1, second.encoding
    end
  end

  test "does not cache inline templates with file identifiers" do
    with_cache do
      file = write_template("from disk")
      2.times do
        inline = ActionView::Template.new("inline", file, @handler, locals: [], format: :html)
        inline.compiled_handler_source
      end

      assert_equal 2, @handler.calls
    end
  end

  test "compiles without a configured cache" do
    Bootsnap::CompileCache::ISeq.stub(:cache_dir, nil) do
      file = write_template("hello")
      2.times { template(file).compiled_handler_source }
      assert_equal 2, @handler.calls
    end
  end

  test "caches callable handlers" do
    with_cache do
      file = write_template("hello")
      calls = 0
      handler = ->(_, source) { calls += 1; source.inspect }
      2.times { template(file, handler: handler).compiled_handler_source }
      template(file, handler: handler, locals: [:message]).compiled_handler_source

      assert_equal 1, calls
    end
  end

  test "supports read-only caches" do
    with_cache do
      cached = write_template("cached")
      template(cached).compiled_handler_source
      missing = write_template("missing", "other.html.erb")
      Bootsnap::CompileCache::Native.readonly = true

      template(cached).compiled_handler_source
      assert_equal 1, @handler.calls
      2.times { template(missing).compiled_handler_source }
      assert_equal 3, @handler.calls
    ensure
      Bootsnap::CompileCache::Native.readonly = false
    end
  end

  test "precompiles all handlers and reports skipped resolvers" do
    with_cache do
      write_template("hello")
      write_template("hello", "show.text.erb")
      write_template("xml.message 'hello'", "show.xml.builder")
      write_template("hello", "show.html")
      write_template("hello", "show.raw")
      write_template("'hello'", "show.ruby")
      resolver = ActionView::FileSystemResolver.new(@views)

      result = ActionView::TemplatePrecompiler.call([resolver, resolver, Object.new])

      assert_equal 6, result.templates
      assert_equal 1, result.skipped_resolvers
      resolver.all_unbound_templates.each do |unbound|
        bound = unbound.bind_locals([])
        handler = bound.handler.dup
        cached = ActionView::Template.new(
          ActionView::Template::Sources::File.new(bound.identifier), bound.identifier, handler,
          locals: [], format: bound.format, virtual_path: bound.virtual_path
        )
        assert_not_called(handler, :call) { cached.compiled_handler_source }
      end
    end
  end

  test "precompilation fails on read-only cache misses" do
    with_cache do
      write_template("hello")
      Bootsnap::CompileCache::Native.readonly = true

      error = assert_raises(ActionView::TemplatePrecompiler::CompilationError) do
        ActionView::TemplatePrecompiler.call([ActionView::FileSystemResolver.new(@views)])
      end
      assert_includes error.message, "Bootsnap could not persist"
    ensure
      Bootsnap::CompileCache::Native.readonly = false
    end
  end

  test "precompilation writes without fetching" do
    with_cache do
      file = write_template("<%= message %>")
      bound = template(file)
      bound.strict_locals!

      assert_not_called(Bootsnap::CompileCache::Native, :fetch) do
        ActionView::Template::CompilationCache.precompile(bound, bound.encode!)
      end

      assert_equal 1, @handler.calls
      view = ActionView::Base.with_empty_template_cache.empty
      assert_equal "hello", template(file, locals: [:message]).render(view, { message: "hello" })
      assert_equal 1, @handler.calls
    end
  end

  test "precompilation reports the template and original error" do
    with_cache do
      file = write_template("hello")
      @handler.define_singleton_method(:call) { |_, _| raise SyntaxError, "invalid template" }
      unbound = Object.new
      bound = template(file)
      unbound.define_singleton_method(:bind_locals) { |_| bound }
      resolver = Object.new
      resolver.define_singleton_method(:all_unbound_templates) { [unbound] }

      error = assert_raises(ActionView::TemplatePrecompiler::CompilationError) do
        ActionView::TemplatePrecompiler.call([resolver])
      end
      assert_includes error.message, file
      assert_kind_of SyntaxError, error.cause
    end
  end

  test "precompilation requires Bootsnap" do
    Bootsnap::CompileCache::ISeq.stub(:cache_dir, nil) do
      error = assert_raises(RuntimeError) { ActionView::TemplatePrecompiler.call([]) }
      assert_match "requires Bootsnap", error.message
    end
  end

  private
    def with_cache(&block)
      Bootsnap::CompileCache::ISeq.stub(:cache_dir, File.join(@directory, "cache-iseq"), &block)
    end

    def write_template(source, name = "show.html.erb")
      File.join(@views, name).tap { |path| File.write(path, source) }
    end

    def template(file, locals: [], handler: @handler)
      ActionView::Template.new(
        ActionView::Template::Sources::File.new(file), file, handler,
        locals: locals, format: :html, virtual_path: "show"
      )
    end
end
