module ActionDispatch
  class RemoteIp
    class IpSpoofAttackError < StandardError ; end

    class RemoteIpGetter
      # IP v4 and v6 (with compression) validation regexp
      # https://gist.github.com/1289635
      VALID_IP = %r{
          (^(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[0-9]{1,2})(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[0-9]{1,2})){3}$)                                                         | # ip v4
          (^(
           (([0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4})                                                                                                                   | # ip v6 not abbreviated
           (([0-9A-Fa-f]{1,4}:){6}:[0-9A-Fa-f]{1,4})                                                                                                                  | # ip v6 with double colon in the end
           (([0-9A-Fa-f]{1,4}:){5}:([0-9A-Fa-f]{1,4}:)?[0-9A-Fa-f]{1,4})                                                                                              | # - ip addresses v6
           (([0-9A-Fa-f]{1,4}:){4}:([0-9A-Fa-f]{1,4}:){0,2}[0-9A-Fa-f]{1,4})                                                                                          | # - with
           (([0-9A-Fa-f]{1,4}:){3}:([0-9A-Fa-f]{1,4}:){0,3}[0-9A-Fa-f]{1,4})                                                                                          | # - double colon
           (([0-9A-Fa-f]{1,4}:){2}:([0-9A-Fa-f]{1,4}:){0,4}[0-9A-Fa-f]{1,4})                                                                                          | # - in the middle
           (([0-9A-Fa-f]{1,4}:){6} ((\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b)\.){3} (\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b))                            | # ip v6 with compatible to v4
           (([0-9A-Fa-f]{1,4}:){1,5}:((\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b)\.){3}(\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b))                           | # ip v6 with compatible to v4
           (([0-9A-Fa-f]{1,4}:){1}:([0-9A-Fa-f]{1,4}:){0,4}((\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b)\.){3}(\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b))     | # ip v6 with compatible to v4
           (([0-9A-Fa-f]{1,4}:){0,2}:([0-9A-Fa-f]{1,4}:){0,3}((\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b)\.){3}(\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b))   | # ip v6 with compatible to v4
           (([0-9A-Fa-f]{1,4}:){0,3}:([0-9A-Fa-f]{1,4}:){0,2}((\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b)\.){3}(\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b))   | # ip v6 with compatible to v4
           (([0-9A-Fa-f]{1,4}:){0,4}:([0-9A-Fa-f]{1,4}:){1}((\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b)\.){3}(\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b))     | # ip v6 with compatible to v4
           (::([0-9A-Fa-f]{1,4}:){0,5}((\b((25[0-5])|(1\d{2})|(2[0-4]\d) |(\d{1,2}))\b)\.){3}(\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b))                         | # ip v6 with compatible to v4
           ([0-9A-Fa-f]{1,4}::([0-9A-Fa-f]{1,4}:){0,5}[0-9A-Fa-f]{1,4})                                                                                               | # ip v6 with compatible to v4
           (::([0-9A-Fa-f]{1,4}:){0,6}[0-9A-Fa-f]{1,4})                                                                                                               | # ip v6 with double colon at the begining
           (([0-9A-Fa-f]{1,4}:){1,7}:)                                                                                                                                  # ip v6 without ending
          )$)
        }x

      def initialize(env, check_ip_spoofing, trusted_proxies)
        @env = env
        @check_ip_spoofing = check_ip_spoofing
        @trusted_proxies = trusted_proxies
      end

      def remote_addrs
        @remote_addrs ||= begin
          list = @env['REMOTE_ADDR'] ? @env['REMOTE_ADDR'].split(/[,\s]+/) : []
          list.reject { |addr| addr =~ @trusted_proxies || addr !~ VALID_IP }
        end
      end

      def to_s
        return remote_addrs.first if remote_addrs.any?

        forwarded_ips = @env['HTTP_X_FORWARDED_FOR'] ? @env['HTTP_X_FORWARDED_FOR'].strip.split(/[,\s]+/) : []

        if client_ip = @env['HTTP_CLIENT_IP']
          if @check_ip_spoofing && forwarded_ips.first != client_ip
            # We don't know which came from the proxy, and which from the user
            raise IpSpoofAttackError, "IP spoofing attack?!" \
              "HTTP_CLIENT_IP=#{@env['HTTP_CLIENT_IP'].inspect}" \
              "HTTP_X_FORWARDED_FOR=#{@env['HTTP_X_FORWARDED_FOR'].inspect}"
          end
          return client_ip
        end

        if forwarded_ips.first !~ @trusted_proxies && forwarded_ips.first =~ VALID_IP
          forwarded_ips.first
        else
          @env["REMOTE_ADDR"]
        end
      end
    end

    def initialize(app, check_ip_spoofing = true, trusted_proxies = nil)
      @app = app
      @check_ip_spoofing = check_ip_spoofing
      regex = '(^127\.0\.0\.1$|^(10|172\.(1[6-9]|2[0-9]|30|31)|192\.168)\.)|^(fc00::)|^(::1)$'
      regex << "|(#{trusted_proxies})" if trusted_proxies
      @trusted_proxies = Regexp.new(regex, "i")
    end

    def call(env)
      env["action_dispatch.remote_ip"] = RemoteIpGetter.new(env, @check_ip_spoofing, @trusted_proxies)
      @app.call(env)
    end
  end
end