# frozen_string_literal: true

require "active_support/log_subscriber"

module ActionView
  # = Action View Log Subscriber
  #
  # Provides functionality so that Rails can output logs from Action View.
  class LogSubscriber < ActiveSupport::LogSubscriber
    VIEWS_PATTERN = /^app\/views\//

    def initialize
      @root = nil
      super
    end

    def render_template(event)
      info do
        message = +"  Rendered #{from_rails_root(event.payload[:identifier])}"
        message << " within #{from_rails_root(event.payload[:layout])}" if event.payload[:layout]
        message << " (Duration: #{event.duration.round(1)}ms | Allocations: #{event.allocations})"
      end
    end

    def render_partial(event)
      debug do
        message = +"  Rendered #{from_rails_root(event.payload[:identifier])}"
        message << " within #{from_rails_root(event.payload[:layout])}" if event.payload[:layout]
        message << " (Duration: #{event.duration.round(1)}ms | Allocations: #{event.allocations})"
        message << " #{cache_message(event.payload)}" unless event.payload[:cache_hit].nil?
        message
      end
    end

    def render_layout(event)
      info do
        message = +"  Rendered layout #{from_rails_root(event.payload[:identifier])}"
        message << " (Duration: #{event.duration.round(1)}ms | Allocations: #{event.allocations})"
      end
    end

    def render_collection(event)
      identifier = event.payload[:identifier] || "templates"

      debug do
        message = +"  Rendered collection of #{from_rails_root(identifier)}"
        message << " within #{from_rails_root(event.payload[:layout])}" if event.payload[:layout]
        message << " #{render_count(event.payload)} (Duration: #{event.duration.round(1)}ms | Allocations: #{event.allocations})"
        message
      end
    end

    def start(name, id, payload)
      log_rendering_start(payload, name)

      super
    end

    def logger
      ActionView::Base.logger
    end

  private
    EMPTY = ""
    def from_rails_root(string) # :doc:
      string = string.sub(rails_root, EMPTY)
      string.sub!(VIEWS_PATTERN, EMPTY)
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

    def log_rendering_start(payload, name)
      debug do
        qualifier =
          case name
          when "render_template.action_view"
            ""
          when "render_layout.action_view"
            "layout "
          end

        return unless qualifier

        message = +"  Rendering #{qualifier}#{from_rails_root(payload[:identifier])}"
        message << " within #{from_rails_root(payload[:layout])}" if payload[:layout]
        message
      end
    end
  end
end

ActionView::LogSubscriber.attach_to :action_view
