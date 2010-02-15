module ActionView
  module Railties
    class LogSubscriber < Rails::LogSubscriber
      def render_template(event)
        message = "Rendered #{from_rails_root(event.payload[:identifier])}"
        message << " within #{from_rails_root(event.payload[:layout])}" if event.payload[:layout]
        message << (" (%.1fms)" % event.duration)
        info(message)        
      end
      alias :render_partial :render_template
      alias :render_collection :render_template

      def logger
        ActionController::Base.logger
      end

    protected

      def from_rails_root(string)
        string.sub("#{Rails.root}/", "").sub(/^app\/views\//, "")
      end
    end
  end
end