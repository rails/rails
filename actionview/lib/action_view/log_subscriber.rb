module ActionView
  # = Action View Log Subscriber
  #
  # Provides functionality so that Rails can output logs from Action View.
  class LogSubscriber < ActiveSupport::LogSubscriber
    VIEWS_PATTERN = /^app\/views\//.freeze

    def render_template(event)
      return unless logger.info?
      message = "  Rendered #{from_rails_root(event.payload[:identifier])}"
      message << " within #{from_rails_root(event.payload[:layout])}" if event.payload[:layout]
      message << " (#{event.duration.round(1)}ms)"
      info(message)
    end
    alias :render_partial :render_template
    alias :render_collection :render_template

    def logger
      ActionView::Base.logger
    end

  protected

    def from_rails_root(string)
      string.sub("#{Rails.root}/", "").sub(VIEWS_PATTERN, "")
    end
  end
end

ActionView::LogSubscriber.attach_to :action_view
