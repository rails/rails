# frozen_string_literal: true

require "active_support/structured_event_subscriber"

module ActionView
  class StructuredEventSubscriber < ActiveSupport::StructuredEventSubscriber # :nodoc:
    VIEWS_PATTERN = /^app\/views\//

    def initialize
      @root = nil
      super
    end

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

    module Utils # :nodoc:
      private
        def from_rails_root(string)
          return unless string

          string = string.sub("#{rails_root}/", "")
          string.sub!(VIEWS_PATTERN, "")
          string
        end

        def rails_root # :doc:
          @root ||= Rails.try(:root)
        end
    end

    include Utils

    class Start # :nodoc:
      include Utils

      def start(name, id, payload)
        ActiveSupport.event_reporter.debug("action_view.render_start",
          is_layout: name == "render_layout.action_view",
          identifier: from_rails_root(payload[:identifier]),
          layout: from_rails_root(payload[:layout]),
        )
      end

      def finish(name, id, payload)
      end
    end

    def self.attach_to(*)
      ActiveSupport::Notifications.subscribe("render_template.action_view", Start.new)
      ActiveSupport::Notifications.subscribe("render_layout.action_view", Start.new)

      super
    end
  end
end

ActionView::StructuredEventSubscriber.attach_to :action_view
