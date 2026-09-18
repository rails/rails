# frozen_string_literal: true

require "abstract_unit"
require "action_view/erb_precompiler"
require "active_support/core_ext/object/with"
require "tmpdir"

class ERBCompilationCacheTest < ActiveSupport::TestCase
  class << Rails
    attr_accessor :root unless method_defined?(:root)
  end

  class CacheableImplementation
    class << self
      attr_accessor :calls

      def erb_compilation_cache_key
        ["cacheable-test-implementation", 1]
      end

      def new(source, options)
        self.calls += 1
        compiled = +"#{options[:preamble]}@output_buffer.safe_append=#{source.inspect};"
        compiled << (options[:postamble] || "@output_buffer")
        Struct.new(:src).new(compiled)
      end
    end
  end

  setup do
    @handler = ActionView::Template::Handlers::ERB.new
    CacheableImplementation.calls = 0
    ActionView::ERBCompilationCache.clear
  end

  teardown do
    ActionView::ERBCompilationCache.clear
  end

  test "reuses compiled ERB after the application is moved to another root" do
    Dir.mktmpdir do |build_root|
      Dir.mktmpdir do |runtime_root|
        build_identifier_root = "#{build_root}-engine"
        runtime_identifier_root = "#{runtime_root}-engine"

        Rails.with(root: Pathname.new(build_root)) do
          ActionView::ERBCompilationCache.build do
            compile(template(build_identifier_root, "<p><%= message %></p>"))
          end
        end

        runtime_cache = File.join(runtime_root, "tmp/cache/action_view")
        FileUtils.mkdir_p(runtime_cache)
        FileUtils.cp_r(File.join(build_root, "tmp/cache/action_view/erb"), runtime_cache)
        ActionView::ERBCompilationCache.clear

        Rails.with(root: Pathname.new(runtime_root)) do
          compile(template(runtime_identifier_root, "<p><%= message %></p>"))
        end

        assert_equal 1, CacheableImplementation.calls
      end
    end
  end

  test "does not cache when rendered view annotations are enabled" do
    Dir.mktmpdir do |root|
      Rails.with(root: Pathname.new(root)) do
        source = "<p><%= message %></p>"
        template = template(root, source)

        ActionView::Base.with(annotate_rendered_view_with_filenames: true) do
          ActionView::ERBCompilationCache.build do
            compile(template)
          end
          compile(template)
        end

        assert_equal 2, CacheableImplementation.calls
      end
    end
  end

  test "does not use an entry when the template changes" do
    Dir.mktmpdir do |root|
      Rails.with(root: Pathname.new(root)) do
        ActionView::ERBCompilationCache.build do
          compile(template(root, "before"))
        end

        compile(template(root, "after"))
      end

      assert_equal 2, CacheableImplementation.calls
    end
  end

  test "does not replace an existing cache when compilation fails" do
    Dir.mktmpdir do |root|
      Rails.with(root: Pathname.new(root)) do
        ActionView::ERBCompilationCache.build do
          compile(template(root, "working"))
        end
        manifest = File.binread(File.join(root, "tmp/cache/action_view/erb/manifest.json"))

        assert_raises(RuntimeError) do
          ActionView::ERBCompilationCache.build do
            compile(template(root, "replacement"))
            raise "failed build"
          end
        end

        assert_equal manifest, File.binread(File.join(root, "tmp/cache/action_view/erb/manifest.json"))
      end
    end
  end

  test "compiles normally without a Rails root" do
    Rails.with(root: nil) do
      compile(template("somewhere", "uncached"))
    end

    assert_equal 1, CacheableImplementation.calls
  end

  test "skips resolvers that cannot enumerate templates" do
    Dir.mktmpdir do |root|
      result = Rails.with(root: Pathname.new(root)) do
        ActionView::ERBPrecompiler.call([Object.new])
      end

      assert_equal 0, result.templates
      assert_equal 0, result.entries
      assert_equal 1, result.skipped_resolvers
    end
  end

  private
    def template(identifier_root, source)
      ActionView::Template.new(
        source,
        File.join(identifier_root, "engine/app/views/messages/show.html.erb"),
        @handler,
        format: :html,
        virtual_path: "messages/show",
        locals: []
      )
    end

    def compile(template)
      @handler.call(template, template.encode!, implementation: CacheableImplementation)
    end
end
