# frozen_string_literal: true

require "abstract_unit"
require "active_support/testing/event_reporter_assertions"
require "action_view/structured_event_subscriber"
require "controller/fake_models"

module ActionView
  class StructuredEventSubscriberTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::EventReporterAssertions

    def setup
      super

      ActionView::LookupContext::DetailsKey.clear

      view_paths = ActionController::Base.view_paths

      lookup_context = ActionView::LookupContext.new(view_paths, {}, ["test"])
      @view          = ActionView::Base.with_empty_template_cache.with_context(lookup_context)

      unless Rails.respond_to?(:root)
        @defined_root = true
        Rails.define_singleton_method(:root) { :defined_root } # Minitest `stub` expects the method to be defined.
      end
    end

    def teardown
      super
      ActionController::Base.view_paths.map(&:clear_cache)

      # We need to undef `root`, RenderTestCases don't want this to be defined
      Rails.instance_eval { undef :root } if defined?(@defined_root)
    end

    def test_render_template
      Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
        with_debug_event_reporting do
          assert_event_reported("action_view.render_start", payload: { identifier: "test/hello_world.erb", layout: nil }) do
            event = assert_event_reported("action_view.render_template", payload: { identifier: "test/hello_world.erb", layout: nil }) do
              @view.render(template: "test/hello_world")
            end

            assert(event[:payload][:gc_ms] >= 0)
            assert(event[:payload][:duration_ms] >= 0)
          end
        end
      end
    end

    def test_render_template_with_layout
      Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
        with_debug_event_reporting do
          payload = { identifier: "test/hello_world.erb", layout: "layouts/yield" }
          assert_event_reported("action_view.render_start", payload:) do
            event = assert_event_reported("action_view.render_template", payload:) do
              @view.render(template: "test/hello_world", layout: "layouts/yield")
            end

            assert(event[:payload][:gc_ms] >= 0)
            assert(event[:payload][:duration_ms] >= 0)
          end
        end
      end
    end

    def test_render_file_template
      Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
        with_debug_event_reporting do
          assert_event_reported("action_view.render_start", payload: { identifier: "test/hello_world.erb", layout: nil }) do
            event = assert_event_reported("action_view.render_template", payload: { identifier: "test/hello_world.erb", layout: nil }) do
              @view.render(file: "#{FIXTURE_LOAD_PATH}/test/hello_world.erb")
            end

            assert(event[:payload][:gc_ms] >= 0)
            assert(event[:payload][:duration_ms] >= 0)
          end
        end
      end
    end

    def test_render_text_template
      Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
        with_debug_event_reporting do
          assert_event_reported("action_view.render_start", payload: { identifier: "text template", layout: nil }) do
            event = assert_event_reported("action_view.render_template", payload: { identifier: "text template", layout: nil }) do
              @view.render(plain: "TEXT")
            end

            assert(event[:payload][:gc_ms] >= 0)
            assert(event[:payload][:duration_ms] >= 0)
          end
        end
      end
    end

    def test_render_inline_template
      Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
        with_debug_event_reporting do
          assert_event_reported("action_view.render_start", payload: { identifier: "inline template", layout: nil }) do
            event = assert_event_reported("action_view.render_template", payload: { identifier: "inline template", layout: nil }) do
              @view.render(inline: "<%= 'TEXT' %>")
            end

            assert(event[:payload][:gc_ms] >= 0)
            assert(event[:payload][:duration_ms] >= 0)
          end
        end
      end
    end

    def test_render_partial_with_implicit_path
      Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
        with_debug_event_reporting do
          payload = { identifier: "customers/_customer.html.erb", layout: nil, cache_hit: nil }
          event = assert_event_reported("action_view.render_partial", payload:) do
            @view.render(Customer.new("david"), greeting: "hi")
          end

          assert(event[:payload][:gc_ms] >= 0)
          assert(event[:payload][:duration_ms] >= 0)
        end
      end
    end

    def test_render_partial_with_cache_is_missed
      Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
        set_view_cache_dependencies
        set_cache_controller

        with_debug_event_reporting do
          payload = { identifier: "test/_cached_customer.erb", layout: nil, cache_hit: :miss }
          event = assert_event_reported("action_view.render_partial", payload:) do
            @view.render(partial: "test/cached_customer", locals: { cached_customer: Customer.new("david") })
          end

          assert(event[:payload][:gc_ms] >= 0)
          assert(event[:payload][:duration_ms] >= 0)
        end
      end
    end

    def test_render_partial_with_cache_is_hit
      Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
        set_view_cache_dependencies
        set_cache_controller

        @view.render(partial: "test/cached_customer", locals: { cached_customer: Customer.new("david") })

        with_debug_event_reporting do
          payload = { identifier: "test/_cached_customer.erb", layout: nil, cache_hit: :hit }
          event = assert_event_reported("action_view.render_partial", payload:) do
            # Second render should hit cache.
            @view.render(partial: "test/cached_customer", locals: { cached_customer: Customer.new("david") })
          end

          assert(event[:payload][:gc_ms] >= 0)
          assert(event[:payload][:duration_ms] >= 0)
        end
      end
    end

    def test_render_partial_as_layout
      Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
        set_view_cache_dependencies
        set_cache_controller

        with_debug_event_reporting do
          event = assert_event_reported("action_view.render_partial", payload: { identifier: "layouts/_yield_only.erb", layout: nil }) do
            @view.render(layout: "layouts/yield_only") { "hello" }
          end

          assert(event[:payload][:gc_ms] >= 0)
          assert(event[:payload][:duration_ms] >= 0)
        end
      end
    end

    def test_render_partial_with_layout
      Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
        set_view_cache_dependencies
        set_cache_controller

        with_debug_event_reporting do
          payload = { identifier: "test/_partial.html.erb", layout: "layouts/_yield_only" }
          event = assert_event_reported("action_view.render_partial", payload:) do
            @view.render(partial: "partial", layout: "layouts/yield_only")
          end

          assert(event[:payload][:gc_ms] >= 0)
          assert(event[:payload][:duration_ms] >= 0)
        end
      end
    end

    def test_render_uncached_outer_partial_with_inner_cached_partial_wont_mix_cache_hits_or_misses
      Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
        set_view_cache_dependencies
        set_cache_controller

        with_debug_event_reporting do
          event = assert_event_reported("action_view.render_partial", payload: { identifier: "test/_cached_customer.erb", layout: nil }) do
            @view.render(partial: "test/nested_cached_customer", locals: { cached_customer: Customer.new("Stan") })
          end

          assert(event[:payload][:gc_ms] >= 0)
          assert(event[:payload][:duration_ms] >= 0)

          payload = { identifier: "test/_cached_customer.erb", layout: nil, cache_hit: :hit }
          event = assert_event_reported("action_view.render_partial", payload:) do
            # Second render hits the cache for the _cached_customer partial. Outer template's log shouldn't be affected.
            @view.render(partial: "test/nested_cached_customer", locals: { cached_customer: Customer.new("Stan") })
          end

          assert(event[:payload][:gc_ms] >= 0)
          assert(event[:payload][:duration_ms] >= 0)
        end
      end
    end

    def test_render_cached_outer_partial_with_cached_inner_partial
      Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
        set_view_cache_dependencies
        set_cache_controller

        with_debug_event_reporting do
          assert_event_reported("action_view.render_partial", payload: { identifier: "test/_cached_customer.erb", layout: nil }) do
            assert_event_reported("action_view.render_partial", payload: { identifier: "test/_cached_nested_cached_customer.erb", layout: nil, cache_hit: :miss }) do
              @view.render(partial: "test/cached_nested_cached_customer", locals: { cached_customer: Customer.new("Stan") })
            end
          end

          # One render: inner partial skipped, because the outer has been cached.
          assert_no_event_reported("action_view.render_partial", payload: { identifier: "test/_cached_customer.erb", layout: nil }) do
            assert_event_reported("action_view.render_partial", payload: { identifier: "test/_cached_nested_cached_customer.erb", layout: nil, cache_hit: :hit }) do
              @view.render(partial: "test/cached_nested_cached_customer", locals: { cached_customer: Customer.new("Stan") })
            end
          end
        end
      end
    end

    def test_render_partial_with_cache_hit_and_missed
      Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
        set_view_cache_dependencies
        set_cache_controller

        with_debug_event_reporting do
          assert_event_reported("action_view.render_partial", payload: { identifier: "test/_cached_customer.erb", layout: nil, cache_hit: :miss }) do
            @view.render(partial: "test/cached_customer", locals: { cached_customer: Customer.new("david") })
          end
          assert_event_reported("action_view.render_partial", payload: { identifier: "test/_cached_customer.erb", layout: nil, cache_hit: :hit }) do
            @view.render(partial: "test/cached_customer", locals: { cached_customer: Customer.new("david") })
          end

          assert_event_reported("action_view.render_partial", payload: { identifier: "test/_cached_customer.erb", layout: nil, cache_hit: :miss }) do
            @view.render(partial: "test/cached_customer", locals: { cached_customer: Customer.new("Stan") })
          end
        end
      end
    end

    def test_render_collection_template
      Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
        set_cache_controller

        with_debug_event_reporting do
          event = assert_event_reported("action_view.render_collection", payload: { identifier: "test/_customer.erb", layout: nil, cache_hits: nil, count: 2 }) do
            @view.render(partial: "test/customer", collection: [ Customer.new("david"), Customer.new("mary") ])
          end

          assert(event[:payload][:gc_ms] >= 0)
          assert(event[:payload][:duration_ms] >= 0)
        end
      end
    end

    def test_render_collection_template_with_layout
      Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
        set_cache_controller

        with_debug_event_reporting do
          event = assert_event_reported("action_view.render_collection", payload: { identifier: "test/_customer.erb", layout: "layouts/_yield_only", cache_hits: nil, count: 2 }) do
            @view.render(partial: "test/customer", layout: "layouts/yield_only", collection: [ Customer.new("david"), Customer.new("mary") ])
          end

          assert(event[:payload][:gc_ms] >= 0)
          assert(event[:payload][:duration_ms] >= 0)
        end
      end
    end

    def test_render_collection_with_implicit_path
      Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
        set_cache_controller

        with_debug_event_reporting do
          event = assert_event_reported("action_view.render_collection", payload: { identifier: "customers/_customer.html.erb", layout: nil, cache_hits: nil, count: 2 }) do
            @view.render([ Customer.new("david"), Customer.new("mary") ], greeting: "hi")
          end

          assert(event[:payload][:gc_ms] >= 0)
          assert(event[:payload][:duration_ms] >= 0)
        end
      end
    end

    def test_render_collection_template_without_path
      Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
        set_cache_controller

        with_debug_event_reporting do
          event = assert_event_reported("action_view.render_collection", payload: { identifier: "templates", layout: nil, cache_hits: nil, count: 2 }) do
            @view.render([ GoodCustomer.new("david"), Customer.new("mary") ], greeting: "hi")
          end

          assert(event[:payload][:gc_ms] >= 0)
          assert(event[:payload][:duration_ms] >= 0)
        end
      end
    end

    def test_render_start_does_not_filter_payload
      old_filter_parameters = ActiveSupport.filter_parameters
      ActiveSupport.filter_parameters = [:identifier]
      ActiveSupport.event_reporter.reload_payload_filter

      Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
        with_debug_event_reporting do
          event = assert_event_reported("action_view.render_start", payload: { identifier: "test/hello_world.erb" }) do
            @view.render(template: "test/hello_world")
          end

          assert_equal "test/hello_world.erb", event[:payload][:identifier]
        end
      end
    ensure
      ActiveSupport.filter_parameters = old_filter_parameters
      ActiveSupport.event_reporter.reload_payload_filter
    end

    def test_render_collection_with_cached_set
      Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
        set_view_cache_dependencies
        set_cache_controller

        with_debug_event_reporting do
          event = assert_event_reported("action_view.render_collection", payload: { identifier: "customers/_customer.html.erb", layout: nil, cache_hits: 0, count: 2 }) do
            @view.render(partial: "customers/customer", collection: [ Customer.new("david"), Customer.new("mary") ], cached: true,
              locals: { greeting: "hi" })
          end

          assert(event[:payload][:gc_ms] >= 0)
          assert(event[:payload][:duration_ms] >= 0)
        end
      end
    end

    private
      def set_cache_controller
        controller = ActionController::Base.new
        controller.perform_caching = true
        controller.cache_store = ActiveSupport::Cache::MemoryStore.new
        @view.controller = controller
      end

      def set_view_cache_dependencies
        def @view.view_cache_dependencies; []; end
        def @view.combined_fragment_cache_key(*); "ahoy_2 `controller` dependency"; end
      end
  end
end
