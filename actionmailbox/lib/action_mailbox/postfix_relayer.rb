# frozen_string_literal: true

require "action_mailbox/version"
require "net/http"
require "uri"

module ActionMailbox
  class PostfixRelayer
    class Result < Struct.new(:output)
      def success?
        !failure?
      end

      def failure?
        output.match?(/\A[45]\.\d{1,3}\.\d{1,3}(\s|\z)/)
      end
    end

    CONTENT_TYPE = "message/rfc822"
    USER_AGENT   = "Action Mailbox Postfix relayer v#{ActionMailbox.version}"

    attr_reader :uri, :username, :password

    def initialize(url:, username: "actionmailbox", password:)
      @uri, @username, @password = URI(url), username, password
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
        client.post uri, source,
          "Content-Type"  => CONTENT_TYPE,
          "User-Agent"    => USER_AGENT,
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
