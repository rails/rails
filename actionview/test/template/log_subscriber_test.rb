# frozen_string_literal: true

require "abstract_unit"
require "active_support/log_subscriber/test_helper"
require "action_view/log_subscriber"
require "controller/fake_models"

class AVLogSubscriberTest < ActiveSupport::TestCase
  include ActiveSupport::LogSubscriber::TestHelper

  def setup
    super

    view_paths     = ActionController::Base.view_paths
    lookup_context = ActionView::LookupContext.new(view_paths, {}, ["test"])
    renderer       = ActionView::Renderer.new(lookup_context)
    @view          = ActionView::Base.new(renderer, {})

    ActionView::LogSubscriber.attach_to :action_view

    unless Rails.respond_to?(:root)
      @defined_root = true
      def Rails.root; :defined_root; end # Minitest `stub` expects the method to be defined.
    end
  end

  def teardown
    super

    ActiveSupport::LogSubscriber.log_subscribers.clear

    # We need to undef `root`, RenderTestCases don't want this to be defined
    Rails.instance_eval { undef :root } if defined?(@defined_root)
  end

  def set_logger(logger)
    ActionView::Base.logger = logger
  end

  def set_cache_controller
    controller = ActionController::Base.new
    controller.perform_caching = true
    controller.cache_store = ActiveSupport::Cache::MemoryStore.new
    @view.controller = controller
  end

  def set_view_cache_dependencies
    def @view.view_cache_dependencies; []; end
    def @view.combined_fragment_cache_key(*); "ahoy `controller` dependency"; end
  end

  def test_render_file_template
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      @view.render(file: "test/hello_world")
      wait

      assert_equal 2, @logger.logged(:info).size
      assert_match(/Rendering test\/hello_world\.erb/, @logger.logged(:info).first)
      assert_match(/Rendered test\/hello_world\.erb/, @logger.logged(:info).last)
    end
  end

  def test_render_text_template
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      @view.render(plain: "TEXT")
      wait

      assert_equal 2, @logger.logged(:info).size
      assert_match(/Rendering text template/, @logger.logged(:info).first)
      assert_match(/Rendered text template/, @logger.logged(:info).last)
    end
  end

  def test_render_inline_template
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      @view.render(inline: "<%= 'TEXT' %>")
      wait

      assert_equal 2, @logger.logged(:info).size
      assert_match(/Rendering inline template/, @logger.logged(:info).first)
      assert_match(/Rendered inline template/, @logger.logged(:info).last)
    end
  end

  def test_render_partial_with_implicit_path
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      @view.render(Customer.new("david"), greeting: "hi")
      wait

      assert_equal 1, @logger.logged(:info).size
      assert_match(/Rendered customers\/_customer\.html\.erb/, @logger.logged(:info).last)
    end
  end

  def test_render_partial_with_cache_missed
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      set_view_cache_dependencies
      set_cache_controller

      @view.render(partial: "test/cached_customer", locals: { cached_customer: Customer.new("david") })
      wait

      assert_equal 1, @logger.logged(:info).size
      assert_match(/Rendered test\/_cached_customer\.erb (.*) \[cache miss\]/, @logger.logged(:info).last)
    end
  end

  def test_render_partial_with_cache_hitted
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      set_view_cache_dependencies
      set_cache_controller

      # Second render should hit cache.
      @view.render(partial: "test/cached_customer", locals: { cached_customer: Customer.new("david") })
      @view.render(partial: "test/cached_customer", locals: { cached_customer: Customer.new("david") })
      wait

      assert_equal 2, @logger.logged(:info).size
      assert_match(/Rendered test\/_cached_customer\.erb (.*) \[cache hit\]/, @logger.logged(:info).last)
    end
  end

  def test_render_uncached_outer_partial_with_inner_cached_partial_wont_mix_cache_hits_or_misses
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      set_view_cache_dependencies
      set_cache_controller

      @view.render(partial: "test/nested_cached_customer", locals: { cached_customer: Customer.new("Stan") })
      wait
      *, cached_inner, uncached_outer = @logger.logged(:info)
      assert_match(/Rendered test\/_cached_customer\.erb (.*) \[cache miss\]/, cached_inner)
      assert_match(/Rendered test\/_nested_cached_customer\.erb \(.*?ms\)$/, uncached_outer)

      # Second render hits the cache for the _cached_customer partial. Outer template's log shouldn't be affected.
      @view.render(partial: "test/nested_cached_customer", locals: { cached_customer: Customer.new("Stan") })
      wait
      *, cached_inner, uncached_outer = @logger.logged(:info)
      assert_match(/Rendered test\/_cached_customer\.erb (.*) \[cache hit\]/, cached_inner)
      assert_match(/Rendered test\/_nested_cached_customer\.erb \(.*?ms\)$/, uncached_outer)
    end
  end

  def test_render_cached_outer_partial_with_cached_inner_partial
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      set_view_cache_dependencies
      set_cache_controller

      @view.render(partial: "test/cached_nested_cached_customer", locals: { cached_customer: Customer.new("Stan") })
      wait
      *, cached_inner, cached_outer = @logger.logged(:info)
      assert_match(/Rendered test\/_cached_customer\.erb (.*) \[cache miss\]/, cached_inner)
      assert_match(/Rendered test\/_cached_nested_cached_customer\.erb (.*) \[cache miss\]/, cached_outer)

      # One render: inner partial skipped, because the outer has been cached.
      assert_difference -> { @logger.logged(:info).size }, +1 do
        @view.render(partial: "test/cached_nested_cached_customer", locals: { cached_customer: Customer.new("Stan") })
        wait
      end
      assert_match(/Rendered test\/_cached_nested_cached_customer\.erb (.*) \[cache hit\]/, @logger.logged(:info).last)
    end
  end

  def test_render_partial_with_cache_hitted_and_missed
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      set_view_cache_dependencies
      set_cache_controller

      @view.render(partial: "test/cached_customer", locals: { cached_customer: Customer.new("david") })
      wait
      assert_match(/Rendered test\/_cached_customer\.erb (.*) \[cache miss\]/, @logger.logged(:info).last)

      @view.render(partial: "test/cached_customer", locals: { cached_customer: Customer.new("david") })
      wait
      assert_match(/Rendered test\/_cached_customer\.erb (.*) \[cache hit\]/, @logger.logged(:info).last)

      @view.render(partial: "test/cached_customer", locals: { cached_customer: Customer.new("Stan") })
      wait
      assert_match(/Rendered test\/_cached_customer\.erb (.*) \[cache miss\]/, @logger.logged(:info).last)
    end
  end

  def test_render_collection_template
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      @view.render(partial: "test/customer", collection: [ Customer.new("david"), Customer.new("mary") ])
      wait

      assert_equal 1, @logger.logged(:info).size
      assert_match(/Rendered collection of test\/_customer.erb \[2 times\]/, @logger.logged(:info).last)
    end
  end

  def test_render_collection_with_implicit_path
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      @view.render([ Customer.new("david"), Customer.new("mary") ], greeting: "hi")
      wait

      assert_equal 1, @logger.logged(:info).size
      assert_match(/Rendered collection of customers\/_customer\.html\.erb \[2 times\]/, @logger.logged(:info).last)
    end
  end

  def test_render_collection_template_without_path
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      @view.render([ GoodCustomer.new("david"), Customer.new("mary") ], greeting: "hi")
      wait

      assert_equal 1, @logger.logged(:info).size
      assert_match(/Rendered collection of templates/, @logger.logged(:info).last)
    end
  end

  def test_render_collection_with_cached_set
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      set_view_cache_dependencies

      @view.render(partial: "customers/customer", collection: [ Customer.new("david"), Customer.new("mary") ], cached: true,
        locals: { greeting: "hi" })
      wait

      assert_equal 1, @logger.logged(:info).size
      assert_match(/Rendered collection of customers\/_customer\.html\.erb \[0 \/ 2 cache hits\]/, @logger.logged(:info).last)
    end
  end
end
