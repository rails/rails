require 'active_support/log_subscriber'

module ActionView
  # = Action View Log Subscriber
  #
  # Provides functionality so that Rails can output logs from Action View.
  class LogSubscriber < ActiveSupport::LogSubscriber
    def initialize
      @root = nil
      super
    end

    def render_template(event)
      info do
        message = "  Rendered #{scrub_rails_root(event.payload[:identifier])}"
        message << " within #{scrub_rails_root(event.payload[:layout])}" if event.payload[:layout]
        message << " (#{event.duration.round(1)}ms)"
      end
    end
    alias :render_partial :render_template
    alias :render_collection :render_template

    def logger
      ActionView::Base.logger
    end

    private
    def scrub_rails_root(string)
      @scrubber ||= %r(\A#{Rails.root}/(?:app/views/)?)
      string.sub(@scrubber, ''.freeze)
    end
  end
end

ActionView::LogSubscriber.attach_to :action_view
