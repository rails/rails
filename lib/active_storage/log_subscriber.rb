require "active_support/log_subscriber"

# Implements the ActiveSupport::LogSubscriber for logging notifications when
# email is delivered or received.
class ActiveStorage::LogSubscriber < ActiveSupport::LogSubscriber
  def service_upload(event)
    message = color("Uploaded file to key: #{key_in(event)}", GREEN)
    message << color(" (checksum: #{event.payload[:checksum]})", GREEN) if event.payload[:checksum]
    info event, message
  end

  def service_download(event)
    info event, color("Downloaded file from key: #{key_in(event)}", BLUE)
  end

  def service_delete(event)
    info event, color("Deleted file from key: #{key_in(event)}", RED)
  end

  def service_exist(event)
    debug event, color("Checked if file exist at key: #{key_in(event)} (#{event.payload[:exist] ? "yes" : "no"})", BLUE)
  end

  def service_url(event)
    debug event, color("Generated URL for file at key: #{key_in(event)} (#{event.payload[:url]})", BLUE)
  end

  # Use the logger configured for ActiveStorage::Base.logger
  def logger
    ActiveStorage::Service.logger
  end

  private
    def info(event, colored_message)
      super log_prefix_for_service(event) + colored_message
    end

    def debug(event, colored_message)
      super log_prefix_for_service(event) + colored_message
    end

    def log_prefix_for_service(event)
      color "  #{event.payload[:service]} Storage (#{event.duration.round(1)}ms) ", CYAN
    end

    def key_in(event)
      event.payload[:key]
    end
end

ActiveStorage::LogSubscriber.attach_to :active_storage
