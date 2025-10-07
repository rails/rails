# frozen_string_literal: true

require "active_support/log_subscriber"

module ActiveStorage
  class LogSubscriber < ActiveSupport::LogSubscriber # :nodoc:
    def service_upload(event)
      message = "Uploaded file to key: #{key_in(event)}"
      message += " (checksum: #{event.payload[:checksum]})" if event.payload[:checksum]
      info event, color(message, GREEN)
    end
    subscribe_log_level :service_upload, :info

    def service_download(event)
      info event, color("Downloaded file from key: #{key_in(event)}", BLUE)
    end
    subscribe_log_level :service_download, :info

    alias_method :service_streaming_download, :service_download

    def preview(event)
      info event, color("Previewed file from key: #{key_in(event)}", BLUE)
    end
    subscribe_log_level :preview, :info

    def service_delete(event)
      info event, color("Deleted file from key: #{key_in(event)}", RED)
    end
    subscribe_log_level :service_delete, :info

    def service_delete_prefixed(event)
      info event, color("Deleted files by key prefix: #{event.payload[:prefix]}", RED)
    end
    subscribe_log_level :service_delete_prefixed, :info

    def service_exist(event)
      debug event, color("Checked if file exists at key: #{key_in(event)} (#{event.payload[:exist] ? "yes" : "no"})", BLUE)
    end
    subscribe_log_level :service_exist, :debug

    def service_url(event)
      debug event, color("Generated URL for file at key: #{key_in(event)} (#{event.payload[:url]})", BLUE)
    end
    subscribe_log_level :service_url, :debug

    def service_mirror(event)
      message = "Mirrored file at key: #{key_in(event)}"
      message += " (checksum: #{event.payload[:checksum]})" if event.payload[:checksum]
      debug event, color(message, GREEN)
    end
    subscribe_log_level :service_mirror, :debug

    def logger
      ActiveStorage.logger
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
end

ActiveStorage::LogSubscriber.attach_to :active_storage
