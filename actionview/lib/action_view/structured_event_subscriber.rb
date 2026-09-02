# frozen_string_literal: true

require "active_support/structured_event_subscriber"

module ActionView
  class StructuredEventSubscriber < ActiveSupport::StructuredEventSubscriber # :nodoc:
    VIEWS_PATTERN = /^app\/views\//

    def render_template(event)
      emit_debug_event("action_view.render_template",
        identifier: from_rails_root(event.payload[:identifier]),
        layout: from_rails_root(event.payload[:layout]),
        duration_ms: event.duration.round(2),
        gc_ms: event.gc_time.round(2),
      )
    end
    debug_only :render_template

    def render_partial(event)
      emit_debug_event("action_view.render_partial",
        identifier: from_rails_root(event.payload[:identifier]),
        layout: from_rails_root(event.payload[:layout]),
        duration_ms: event.duration.round(2),
        gc_ms: event.gc_time.round(2),
        cache_hit: event.payload[:cache_hit],
      )
    end
    debug_only :render_partial

    def render_layout(event)
      emit_event("action_view.render_layout",
        identifier: from_rails_root(event.payload[:identifier]),
        duration_ms: event.duration.round(2),
        gc_ms: event.gc_time.round(2),
      )
    end
    debug_only :render_layout

    def render_collection(event)
      emit_debug_event("action_view.render_collection",
        identifier: from_rails_root(event.payload[:identifier] || "templates"),
        layout: from_rails_root(event.payload[:layout]),
        duration_ms: event.duration.round(2),
        gc_ms: event.gc_time.round(2),
        cache_hits: event.payload[:cache_hits],
        count: event.payload[:count],
      )
    end
    debug_only :render_collection

    class << self
      def rails_root
        Utils.rails_root
      end

      def rails_root=(rails_root)
        Utils.rails_root = rails_root
      end
    end

    module Utils # :nodoc:
      class << self
        attr_accessor :rails_root
      end

      self.rails_root = "/"

      private
        def from_rails_root(string)
          return unless string

          string = string.sub(rails_root, "")
          string.sub!(VIEWS_PATTERN, "")
          string
        end

        def rails_root # :doc:
          Utils.rails_root
        end
    end

    include Utils

    class Start # :nodoc:
      include Utils

      def start(name, id, payload)
        ActiveSupport.event_reporter.debug("action_view.render_start",
          filter_payload: false,
          is_layout: name == "render_layout.action_view",
          identifier: from_rails_root(payload[:identifier]),
          layout: from_rails_root(payload[:layout]),
        )
      end

      def finish(name, id, payload)
      end
    end

    class << self
      def attach_to(*)
        @start_template_subscription = ActiveSupport::Notifications.subscribe("render_template.action_view", Start.new)
        @start_layout_subscription = ActiveSupport::Notifications.subscribe("render_layout.action_view", Start.new)

        super
      end

      # Detach the subscriber and its monotonic +Start+ listeners.
      # Called from the +ActionView::Railtie+ when the event reporter is
      # not in debug mode, so non-debug apps stop paying to allocate and
      # dispatch +render_*.action_view+ notifications that would otherwise
      # be discarded (see #57781).
      def detach! # :nodoc:
        detach_from :action_view
        ActiveSupport::Notifications.unsubscribe(@start_template_subscription) if @start_template_subscription
        ActiveSupport::Notifications.unsubscribe(@start_layout_subscription) if @start_layout_subscription
        @start_template_subscription = @start_layout_subscription = nil
      end
    end
  end
end

ActionView::StructuredEventSubscriber.attach_to :action_view
