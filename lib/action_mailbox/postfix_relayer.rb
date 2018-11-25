# frozen_string_literal: true

require "net/http"
require "uri"

module ActionMailbox
  class PostfixRelayer
    class Result < Struct.new(:output)
      def success?
        !failure?
      end

      def failure?
        output.match?(/\A[45]\.\d\.\d /)
      end
    end

    attr_reader :uri, :username, :password, :user_agent

    def initialize(url:, username: "actionmailbox", password:, user_agent: nil)
      @uri, @username, @password, @user_agent = URI(url), username, password, user_agent || "Postfix"
    end

    def relay(source)
      case response = post(source)
      when Net::HTTPSuccess
        Result.new "2.0.0 Successfully relayed message to Postfix ingress"
      when Net::HTTPUnauthorized
        Result.new "4.7.0 Invalid credentials for Postfix ingress"
      else
        Result.new "4.0.0 HTTP #{response.code}"
      end
    rescue IOError, SocketError, SystemCallError => error
      Result.new "4.4.2 Network error relaying to Postfix ingress: #{error.message}"
    rescue Timeout::Error
      Result.new "4.4.2 Timed out relaying to Postfix ingress"
    rescue => error
      Result.new "4.0.0 Error relaying to Postfix ingress: #{error.message}"
    end

    private
      def post(source)
        client.post uri.path, source,
          "Content-Type"  => "message/rfc822",
          "User-Agent"    => user_agent,
          "Authorization" => "Basic #{Base64.strict_encode64(username + ":" + password)}"
      end

      def client
        @client ||= Net::HTTP.new(uri.host, uri.port).tap do |connection|
          if uri.scheme == "https"
            require "openssl"

            connection.use_ssl     = true
            connection.verify_mode = OpenSSL::SSL::VERIFY_PEER
          end

          connection.open_timeout = 1
          connection.read_timeout = 10
        end
      end
  end
end
