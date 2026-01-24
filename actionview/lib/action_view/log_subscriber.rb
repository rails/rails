# frozen_string_literal: true

require "active_support/log_subscriber"

module ActionView
  class LogSubscriber < ActiveSupport::EventReporter::LogSubscriber # :nodoc:
    VIEWS_PATTERN = /^app\/views\//

    self.namespace = "action_view"

    def initialize
      @root = nil
      super
    end

    def render_template(event)
      info do
        message = +"  Rendered #{from_rails_root(event[:payload][:identifier])}"
        message << " within #{from_rails_root(event[:payload][:layout])}" if event[:payload][:layout]
        message << " (Duration: #{event[:payload][:duration_ms].round(1)}ms | GC: #{event[:payload][:gc_ms].round(1)}ms)"
      end
    end
    event_log_level :render_template, :debug

    def render_partial(event)
      debug do
        message = +"  Rendered #{from_rails_root(event[:payload][:identifier])}"
        message << " within #{from_rails_root(event[:payload][:layout])}" if event[:payload][:layout]
        message << " (Duration: #{event[:payload][:duration_ms].round(1)}ms | GC: #{event[:payload][:gc_ms].round(1)}ms)"
        message << " #{cache_message(event[:payload])}" unless event[:payload][:cache_hit].nil?
        message
      end
    end
    event_log_level :render_partial, :debug

    def render_layout(event)
      info do
        message = +"  Rendered layout #{from_rails_root(event[:payload][:identifier])}"
        message << " (Duration: #{event[:payload][:duration_ms].round(1)}ms | GC: #{event[:payload][:gc_ms].round(1)}ms)"
      end
    end
    event_log_level :render_layout, :info

    def render_collection(event)
      identifier = event[:payload][:identifier] || "templates"

      debug do
        message = +"  Rendered collection of #{from_rails_root(identifier)}"
        message << " within #{from_rails_root(event[:payload][:layout])}" if event[:payload][:layout]
        message << " #{render_count(event[:payload])} (Duration: #{event[:payload][:duration_ms].round(1)}ms | GC: #{event[:payload][:gc_ms].round(1)}ms)"
        message
      end
    end
    event_log_level :render_collection, :debug

    def render_start(event)
      debug do
        payload = event[:payload]

        message = +"  Rendering #{payload[:is_layout] ? "layout " : ""}#{from_rails_root(payload[:identifier])}"
        message << " within #{from_rails_root(payload[:layout])}" if payload[:layout]
        message
      end
    end
    event_log_level :render_start, :debug

    def self.default_logger
      ActionView::Base.logger
    end

    private
      def from_rails_root(string)
        string = string.sub(rails_root, "")
        string.sub!(VIEWS_PATTERN, "")
        string
      end

      def rails_root # :doc:
        @root ||= "#{Rails.root}/"
      end

      def render_count(payload) # :doc:
        if payload[:cache_hits]
          "[#{payload[:cache_hits]} / #{payload[:count]} cache hits]"
        else
          "[#{payload[:count]} times]"
        end
      end

      def cache_message(payload) # :doc:
        case payload[:cache_hit]
        when :hit
          "[cache hit]"
        when :miss
          "[cache miss]"
        end
      end
  end
end

ActiveSupport.event_reporter.subscribe(
  ActionView::LogSubscriber.new, &ActionView::LogSubscriber.subscription_filter
)
