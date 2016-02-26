require 'active_support/log_subscriber'

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
        message = "  Rendered #{from_rails_root(event.payload[:identifier])}"
        message << " within #{from_rails_root(event.payload[:layout])}" if event.payload[:layout]
        message << " (#{event.duration.round(1)}ms)"
      end
    end
    alias :render_partial :render_template

    def render_collection(event)
      identifier = event.payload[:identifier] || 'templates'

      info do
        "  Rendered collection of #{from_rails_root(identifier)}" \
        " #{render_count(event.payload)} (#{event.duration.round(1)}ms)"
      end
    end

    def start(name, id, payload)
      if name == "render_template.action_view"
        log_rendering_start(payload)
      end

      super
    end

    def logger
      ActionView::Base.logger
    end

  protected

    EMPTY = ''
    def from_rails_root(string)
      string = string.sub(rails_root, EMPTY)
      string.sub!(VIEWS_PATTERN, EMPTY)
      string
    end

    def rails_root
      @root ||= "#{Rails.root}/"
    end

    def render_count(payload)
      if payload[:cache_hits]
        "[#{payload[:cache_hits]} / #{payload[:count]} cache hits]"
      else
        "[#{payload[:count]} times]"
      end
    end

  private

    def log_rendering_start(payload)
      info do
        message = "  Rendering #{from_rails_root(payload[:identifier])}"
        message << " within #{from_rails_root(payload[:layout])}" if payload[:layout]
        message
      end
    end
  end
end

ActionView::LogSubscriber.attach_to :action_view
