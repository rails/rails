module ActionDispatch
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
      body         = { :status => status, :error => exception.message }

      render(status, content_type, body)
    end

    private

    def render(status, content_type, body)
      format = content_type && "to_#{content_type.to_sym}"
      if format && body.respond_to?(format)
        render_format(status, content_type, body.public_send(format))
      else
        render_html(status)
      end
    end

    def render_format(status, content_type, body)
      [status, {'Content-Type' => "#{content_type}; charset=#{ActionDispatch::Response.default_charset}",
                'Content-Length' => body.bytesize.to_s}, [body]]
    end

    def render_html(status)
      found = false
      path = "#{public_path}/#{status}.#{I18n.locale}.html" if I18n.locale
      path = "#{public_path}/#{status}.html" unless path && (found = File.exist?(path))

      if found || File.exist?(path)
        render_format(status, 'text/html', File.read(path))
      else
        [404, { "X-Cascade" => "pass" }, []]
      end
    end
  end
end
