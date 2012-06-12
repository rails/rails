module ActionDispatch
  # A simple Rack application that renders exceptions in the given public path.
  class PublicExceptions
    attr_accessor :public_path

    def initialize(public_path)
      @public_path = public_path
    end

    def call(env)
      exception    = env["action_dispatch.exception"]
      status       = env["PATH_INFO"][1..-1]
      request      = ActionDispatch::Request.new(env)
      content_type = request.formats.first
      format       = (mime = Mime[content_type]) && "to_#{mime.to_sym}"
      body         = { :status => status, :error => exception.message }

      render(status, body, :format => format, :content_type => content_type)
    end

    private

    def render(status, body, options)
      format = options[:format]

      if format && body.respond_to?(format)
        render_format(status, body.public_send(format), options)
      else
        render_html(status)
      end
    end

    def render_format(status, body, options)
      [status, {'Content-Type' => "#{options[:content_type]}; charset=#{ActionDispatch::Response.default_charset}",
                'Content-Length' => body.bytesize.to_s}, [body]]
    end

    def render_html(status)
      found = false
      path = "#{public_path}/#{status}.#{I18n.locale}.html" if I18n.locale
      path = "#{public_path}/#{status}.html" unless path && (found = File.exist?(path))

      if found || File.exist?(path)
        body = File.read(path)
        [status, {'Content-Type' => "text/html; charset=#{Response.default_charset}", 'Content-Length' => body.bytesize.to_s}, [body]]
      else
        [404, { "X-Cascade" => "pass" }, []]
      end
    end
  end
end
