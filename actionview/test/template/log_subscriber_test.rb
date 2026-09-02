# frozen_string_literal: true

require "abstract_unit"
require "active_support/log_subscriber/test_helper"
require "action_view/log_subscriber"
require "controller/fake_models"
require "active_support/testing/event_reporter_assertions"
require "action_view/structured_event_subscriber"

ActionView::StructuredEventSubscriber.attach_to :action_view

class AVLogSubscriberTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::EventReporterAssertions

  def run(*)
    with_debug_event_reporting do
      super
    end
  end

  def setup
    super
    @logger     = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new
    @old_logger = ActionView::LogSubscriber.logger
    @old_rails_root = ActionView::LogSubscriber.rails_root
    @old_structured_rails_root = ActionView::StructuredEventSubscriber.rails_root
    ActionView::LogSubscriber.logger = @logger
    ActionView::LogSubscriber.rails_root = "#{File.expand_path(FIXTURE_LOAD_PATH)}/".freeze
    ActionView::StructuredEventSubscriber.rails_root = "#{File.expand_path(FIXTURE_LOAD_PATH)}/".freeze

    ActionView::LookupContext::DetailsKey.clear

    view_paths = ActionController::Base.view_paths

    lookup_context = ActionView::LookupContext.new(view_paths, {}, ["test"])
    @view          = ActionView::Base.with_empty_template_cache.with_context(lookup_context)
  end

  def teardown
    super
    ActionView::LogSubscriber.logger = @old_logger
    ActionView::LogSubscriber.rails_root = @old_rails_root
    ActionView::StructuredEventSubscriber.rails_root = @old_structured_rails_root
    ActionController::Base.view_paths.map(&:clear_cache)
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

  def test_render_template_template
    @view.render(template: "test/hello_world")

    assert_equal 1, @logger.logged(:debug).size
    assert_equal 1, @logger.logged(:info).size
    assert_match(/Rendering test\/hello_world\.erb/, @logger.logged(:debug).last)
    assert_match(/Rendered test\/hello_world\.erb/, @logger.logged(:info).last)
  end

  def test_render_template_with_layout
    @view.render(template: "test/hello_world", layout: "layouts/yield")

    assert_equal 2, @logger.logged(:debug).size
    assert_equal 2, @logger.logged(:info).size

    assert_match(/Rendering layout layouts\/yield\.erb/, @logger.logged(:debug).first)
    assert_match(/Rendering test\/hello_world\.erb within layouts\/yield/, @logger.logged(:debug).last)
    assert_match(/Rendered test\/hello_world\.erb within layouts\/yield/, @logger.logged(:info).first)
    assert_match(/Rendered layout layouts\/yield\.erb/, @logger.logged(:info).last)
  end

  def test_render_file_template
    @view.render(file: "#{FIXTURE_LOAD_PATH}/test/hello_world.erb")

    assert_equal 1, @logger.logged(:debug).size
    assert_equal 1, @logger.logged(:info).size
    assert_match(/Rendering test\/hello_world\.erb/, @logger.logged(:debug).last)
    assert_match(/Rendered test\/hello_world\.erb/, @logger.logged(:info).last)
  end

  def test_render_text_template
    @view.render(plain: "TEXT")

    assert_equal 1, @logger.logged(:debug).size
    assert_equal 1, @logger.logged(:info).size
    assert_match(/Rendering text template/, @logger.logged(:debug).last)
    assert_match(/Rendered text template/, @logger.logged(:info).last)
  end

  def test_render_inline_template
    @view.render(inline: "<%= 'TEXT' %>")

    assert_equal 1, @logger.logged(:debug).size
    assert_equal 1, @logger.logged(:info).size
    assert_match(/Rendering inline template/, @logger.logged(:debug).last)
    assert_match(/Rendered inline template/, @logger.logged(:info).last)
  end

  def test_render_partial_with_implicit_path
    @view.render(Customer.new("david"), greeting: "hi")

    assert_equal 1, @logger.logged(:debug).size
    assert_match(/Rendered customers\/_customer\.html\.erb/, @logger.logged(:debug).last)
  end

  def test_render_partial_with_cache_missed
    set_view_cache_dependencies
    set_cache_controller

    @view.render(partial: "test/cached_customer", locals: { cached_customer: Customer.new("david") })

    assert_equal 1, @logger.logged(:debug).size
    assert_match(/Rendered test\/_cached_customer\.erb (.*) \[cache miss\]/, @logger.logged(:debug).last)
  end

  def test_render_partial_with_cache_hitted
    set_view_cache_dependencies
    set_cache_controller

    # Second render should hit cache.
    @view.render(partial: "test/cached_customer", locals: { cached_customer: Customer.new("david") })
    @view.render(partial: "test/cached_customer", locals: { cached_customer: Customer.new("david") })

    assert_equal 2, @logger.logged(:debug).size
    assert_match(/Rendered test\/_cached_customer\.erb (.*) \[cache hit\]/, @logger.logged(:debug).last)
  end

  def test_render_partial_as_layout
    set_view_cache_dependencies
    set_cache_controller

    @view.render(layout: "layouts/yield_only") { "hello" }

    assert_equal 1, @logger.logged(:debug).size
    assert_match(/Rendered layouts\/_yield_only\.erb/, @logger.logged(:debug).first)
  end

  def test_render_partial_with_layout
    set_view_cache_dependencies
    set_cache_controller

    @view.render(partial: "partial", layout: "layouts/yield_only")

    assert_equal 1, @logger.logged(:debug).size
    assert_match(/Rendered test\/_partial\.html\.erb within layouts\/_yield_only/, @logger.logged(:debug).first)
  end

  def test_render_uncached_outer_partial_with_inner_cached_partial_wont_mix_cache_hits_or_misses
    set_view_cache_dependencies
    set_cache_controller

    @view.render(partial: "test/nested_cached_customer", locals: { cached_customer: Customer.new("Stan") })
    *, cached_inner, uncached_outer = @logger.logged(:debug)
    assert_match(/Rendered test\/_cached_customer\.erb (.*) \[cache miss\]/, cached_inner)
    assert_match(/Rendered test\/_nested_cached_customer\.erb \(Duration: .*?ms \| GC: .*?\)$/, uncached_outer)

    # Second render hits the cache for the _cached_customer partial. Outer template's log shouldn't be affected.
    @view.render(partial: "test/nested_cached_customer", locals: { cached_customer: Customer.new("Stan") })
    *, cached_inner, uncached_outer = @logger.logged(:debug)
    assert_match(/Rendered test\/_cached_customer\.erb (.*) \[cache hit\]/, cached_inner)
    assert_match(/Rendered test\/_nested_cached_customer\.erb \(Duration: .*?ms \| GC: .*?\)$/, uncached_outer)
  end

  def test_render_cached_outer_partial_with_cached_inner_partial
    set_view_cache_dependencies
    set_cache_controller

    @view.render(partial: "test/cached_nested_cached_customer", locals: { cached_customer: Customer.new("Stan") })
    *, cached_inner, cached_outer = @logger.logged(:debug)
    assert_match(/Rendered test\/_cached_customer\.erb (.*) \[cache miss\]/, cached_inner)
    assert_match(/Rendered test\/_cached_nested_cached_customer\.erb (.*) \[cache miss\]/, cached_outer)

    # One render: inner partial skipped, because the outer has been cached.
    assert_difference -> { @logger.logged(:debug).size }, +1 do
      @view.render(partial: "test/cached_nested_cached_customer", locals: { cached_customer: Customer.new("Stan") })
    end
    assert_match(/Rendered test\/_cached_nested_cached_customer\.erb (.*) \[cache hit\]/, @logger.logged(:debug).last)
  end

  def test_render_partial_with_cache_hitted_and_missed
    set_view_cache_dependencies
    set_cache_controller

    @view.render(partial: "test/cached_customer", locals: { cached_customer: Customer.new("david") })
    assert_match(/Rendered test\/_cached_customer\.erb (.*) \[cache miss\]/, @logger.logged(:debug).last)

    @view.render(partial: "test/cached_customer", locals: { cached_customer: Customer.new("david") })
    assert_match(/Rendered test\/_cached_customer\.erb (.*) \[cache hit\]/, @logger.logged(:debug).last)

    @view.render(partial: "test/cached_customer", locals: { cached_customer: Customer.new("Stan") })
    assert_match(/Rendered test\/_cached_customer\.erb (.*) \[cache miss\]/, @logger.logged(:debug).last)
  end

  def test_render_collection_template
    set_cache_controller

    @view.render(partial: "test/customer", collection: [ Customer.new("david"), Customer.new("mary") ])

    assert_equal 1, @logger.logged(:debug).size
    assert_match(/Rendered collection of test\/_customer.erb \[2 times\]/, @logger.logged(:debug).last)
  end

  def test_render_collection_template_with_layout
    set_cache_controller

    @view.render(partial: "test/customer", layout: "layouts/yield_only", collection: [ Customer.new("david"), Customer.new("mary") ])

    assert_equal 1, @logger.logged(:debug).size
    assert_match(/Rendered collection of test\/_customer.erb within layouts\/_yield_only \[2 times\]/, @logger.logged(:debug).last)
  end

  def test_render_collection_with_implicit_path
    set_cache_controller

    @view.render([ Customer.new("david"), Customer.new("mary") ], greeting: "hi")

    assert_equal 1, @logger.logged(:debug).size
    assert_match(/Rendered collection of customers\/_customer\.html\.erb \[2 times\]/, @logger.logged(:debug).last)
  end

  def test_render_collection_template_without_path
    set_cache_controller

    @view.render([ GoodCustomer.new("david"), Customer.new("mary") ], greeting: "hi")

    assert_equal 1, @logger.logged(:debug).size
    assert_match(/Rendered collection of templates/, @logger.logged(:debug).last)
  end

  def test_render_collection_with_cached_set
    set_view_cache_dependencies
    set_cache_controller

    @view.render(partial: "customers/customer", collection: [ Customer.new("david"), Customer.new("mary") ], cached: true,
      locals: { greeting: "hi" })

    assert_equal 1, @logger.logged(:debug).size
    assert_match(/Rendered collection of customers\/_customer\.html\.erb \[0 \/ 2 cache hits\]/, @logger.logged(:debug).last)
  end
end
