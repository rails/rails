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

    def redirect(to_url, permanently = false)
      self.headers["Status"]   = "302 Found" unless headers["Status"] == "301 Moved Permanently"
      self.headers["Location"] = to_url

      self.body = "<html><body>You are being <a href=\"#{to_url}\">redirected</a>.</body></html>"
    end

    def prepare!
      handle_conditional_get!
      convert_content_type!
      set_content_length!
    end


    private
      def handle_conditional_get!
        if body.is_a?(String) && (headers['Status'] ? headers['Status'][0..2] == '200' : true)  && !body.empty?
          self.headers['ETag'] ||= %("#{Digest::MD5.hexdigest(body)}")
          self.headers['Cache-Control'] = 'private, max-age=0, must-revalidate' if headers['Cache-Control'] == DEFAULT_HEADERS['Cache-Control']

          if request.headers['HTTP_IF_NONE_MATCH'] == headers['ETag']
            self.headers['Status'] = '304 Not Modified'
            self.body = ''
          end
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