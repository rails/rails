# frozen_string_literal: true

module ActionDispatch
  # When called, this middleware renders an error page. By default if an HTML
  # response is expected it will render static error pages from the <tt>/public</tt>
  # directory. For example when this middleware receives a 500 response it will
  # render the template found in <tt>/public/500.html</tt>.
  # If an internationalized locale is set, this middleware will attempt to render
  # the template in <tt>/public/500.<locale>.html</tt>. If an internationalized template
  # is not found it will fall back on <tt>/public/500.html</tt>.
  #
  # When a request with a content type other than HTML is made, this middleware
  # will attempt to convert error information into the appropriate response type.
  class PublicExceptions
    attr_accessor :public_path

    def initialize(public_path)
      @public_path = public_path
    end

    def call(env)
      request      = ActionDispatch::Request.new(env)
      status       = request.path_info[1..-1].to_i
      content_type = request.formats.first
      body         = { status: status, error: Rack::Utils::HTTP_STATUS_CODES.fetch(status, Rack::Utils::HTTP_STATUS_CODES[500]) }

      render(status, content_type, body)
    end

    private

      def render(status, content_type, body)
        format = "to_#{content_type.to_sym}" if content_type
        if format && body.respond_to?(format)
          render_format(status, content_type, body.public_send(format))
        else
          render_html(status)
        end
      end

      def render_format(status, content_type, body)
        [status, { "Content-Type" => "#{content_type}; charset=#{ActionDispatch::Response.default_charset}",
                  "Content-Length" => body.bytesize.to_s }, [body]]
      end

      def render_html(status)
        path = "#{public_path}/#{status}.#{I18n.locale}.html"
        path = "#{public_path}/#{status}.html" unless (found = File.exist?(path))

        if found || File.exist?(path)
          render_format(status, "text/html", File.read(path))
        else
          [404, { "X-Cascade" => "pass" }, []]
        end
      end
  end
end
