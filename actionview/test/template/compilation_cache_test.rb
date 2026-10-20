# frozen_string_literal: true

require "abstract_unit"
require "tmpdir"

class TemplateCompilationCacheTest < ActiveSupport::TestCase
  class Handler
    attr_reader :calls

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
    ActionView::Template::CompilationCache.instance_variable_set(:@entries, Ractor.make_shareable({}))
    FileUtils.remove_entry(@directory)
  end

  test "falls back to the handler for templates missing from the cache" do
    precompile_and_load
    file = write_template("added later")
    template(file).send(:compiled_source)

    assert_equal 1, @handler.calls
  end

  test "loaded cache is reused across locals" do
    file = write_template("<%= message %>")
    precompile_and_load
    view = ActionView::Base.with_empty_template_cache.empty

    assert_equal "hello", template(file, locals: [:message]).render(view, { message: "hello" })
    assert_equal "bye", template(file, locals: [:message, :extra]).render(view, { message: "bye", extra: 1 })
    assert_equal 0, @handler.calls
  end

  test "preserves strict locals on cache hits" do
    file = write_template("<%# locals: (message:) %><%= message %>")
    precompile_and_load
    view = ActionView::Base.with_empty_template_cache.empty

    assert_equal "hello", template(file, locals: [:message]).render(view, { message: "hello" })
    assert_raises(ActionView::Template::Error) { template(file).render(view, {}) }
    assert_equal 0, @handler.calls
  end

  test "does not use the cache for templates without a file source" do
    file = write_template("from disk")
    precompile_and_load
    ActionView::Template.new("inline", file, @handler, locals: [], format: :html).send(:compiled_source)

    assert_equal 1, @handler.calls
  end

  test "compiles normally when no cache is loaded" do
    file = write_template("hello")
    2.times { template(file).send(:compiled_source) }

    assert_equal 2, @handler.calls
  end

  private
    def precompile_and_load
      ActionView::Template::CompilationCache.precompile(@directory, [ActionView::FileSystemResolver.new(@views)])
      ActionView::Template::CompilationCache.load(@directory)
    end

    def write_template(source, name = "show.html.erb")
      File.join(@views, name).tap { |path| File.write(path, source) }
    end

    def template(file, locals: [])
      ActionView::Template.new(
        ActionView::Template::Sources::File.new(file), file, @handler,
        locals: locals, format: :html, virtual_path: "show"
      )
    end
end
