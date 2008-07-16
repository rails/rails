require 'digest/md5'

module ActionController
  class AbstractResponse #:nodoc:
    DEFAULT_HEADERS = { "Cache-Control" => "no-cache" }
    attr_accessor :request
    attr_accessor :body, :headers, :session, :cookies, :assigns, :template, :redirected_to, :redirected_to_method_params, :layout

    def initialize
      @body, @headers, @session, @assigns = "", DEFAULT_HEADERS.merge("cookie" => []), [], []
    end

    def content_type=(mime_type)
      self.headers["Content-Type"] = charset ? "#{mime_type}; charset=#{charset}" : mime_type
    end
    
    def content_type
      content_type = String(headers["Content-Type"] || headers["type"]).split(";")[0]
      content_type.blank? ? nil : content_type
    end
    
    def charset=(encoding)
      self.headers["Content-Type"] = "#{content_type || Mime::HTML}; charset=#{encoding}"
    end
    
    def charset
      charset = String(headers["Content-Type"] || headers["type"]).split(";")[1]
      charset.blank? ? nil : charset.strip.split("=")[1]
    end

    def redirect(to_url, response_status)
      self.headers["Status"] = response_status
      self.headers["Location"] = to_url

      self.body = "<html><body>You are being <a href=\"#{to_url}\">redirected</a>.</body></html>"
    end

    def prepare!
      handle_conditional_get!
      convert_content_type!
      set_content_length!
    end

    # Sets the Last-Modified response header. Returns whether it's older than
    # the If-Modified-Since request header.
    def last_modified!(utc_time)
      headers['Last-Modified'] ||= utc_time.httpdate
      if request && since = request.headers['HTTP_IF_MODIFIED_SINCE']
        utc_time <= Time.rfc2822(since)
      end
    end

    # Sets the ETag response header. Returns whether it matches the
    # If-None-Match request header.
    def etag!(tag)
      headers['ETag'] ||= %("#{Digest::MD5.hexdigest(ActiveSupport::Cache.expand_cache_key(tag))}")
      if request && request.headers['HTTP_IF_NONE_MATCH'] == headers['ETag']
        true
      end
    end

    private
      def handle_conditional_get!
        if nonempty_ok_response?
          set_conditional_cache_control!

          if etag!(body)
            headers['Status'] = '304 Not Modified'
            self.body = ''
          end
        end
      end

      def nonempty_ok_response?
        status = headers['Status']
        ok = !status || status[0..2] == '200'
        ok && body.is_a?(String) && !body.empty?
      end

      def set_conditional_cache_control!
        if headers['Cache-Control'] == DEFAULT_HEADERS['Cache-Control']
          headers['Cache-Control'] = 'private, max-age=0, must-revalidate'
        end
      end

      def convert_content_type!
        if content_type = headers.delete("Content-Type")
          self.headers["type"] = content_type
        end
        if content_type = headers.delete("Content-type")
          self.headers["type"] = content_type
        end
        if content_type = headers.delete("content-type")
          self.headers["type"] = content_type
        end
      end
    
      # Don't set the Content-Length for block-based bodies as that would mean reading it all into memory. Not nice
      # for, say, a 2GB streaming file.
      def set_content_length!
        self.headers["Content-Length"] = body.size unless body.respond_to?(:call)
      end
  end
end
