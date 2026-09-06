# frozen_string_literal: true

require "active_support/core_ext/hash/except"

module ActiveStorage::FileServer # :nodoc:
  DEFAULT_SEND_FILE_TYPE        = ActionController::DataStreaming::DEFAULT_SEND_FILE_TYPE
  DEFAULT_SEND_FILE_DISPOSITION = ActionController::DataStreaming::DEFAULT_SEND_FILE_DISPOSITION

  private
    def serve_file(path, content_type:, disposition:)
      ::Rack::Files.new(nil).serving(request, path).tap do |(status, headers, body)|
        self.status = status
        self.response_body = body

        headers.each do |name, value|
          response.headers[name] = value
        end

        response.headers.except!("X-Cascade", "x-cascade") if status == 416
        response.headers["Content-Type"] = content_type || DEFAULT_SEND_FILE_TYPE
        response.headers["Content-Disposition"] = disposition || DEFAULT_SEND_FILE_DISPOSITION
      end
    end
end
