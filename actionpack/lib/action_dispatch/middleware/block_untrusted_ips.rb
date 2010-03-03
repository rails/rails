module ActionDispatch
  class BlockUntrustedIps
    class SpoofAttackError < StandardError ; end

    def initialize(app)
      @app = app
    end

    def call(env)
      if @env['HTTP_X_FORWARDED_FOR'] && @env['HTTP_CLIENT_IP']
        remote_ips = @env['HTTP_X_FORWARDED_FOR'].split(',')

        unless remote_ips.include?(@env['HTTP_CLIENT_IP'])
          http_client_ip     = @env['HTTP_CLIENT_IP'].inspect
          http_forwarded_for = @env['HTTP_X_FORWARDED_FOR'].inspect

          raise SpoofAttackError, "IP spoofing attack?!\n  " \
            "HTTP_CLIENT_IP=#{http_client_ip}\n  HTTP_X_FORWARDED_FOR=http_forwarded_for"
        end
      end

      @app.call(env)
    end
  end
end