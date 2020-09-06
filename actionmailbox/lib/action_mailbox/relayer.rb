# frozen_string_literal: true

require "action_mailbox/version"
require "net/http"
require "uri"

module ActionMailbox
  class Relayer
    class Result < Struct.new(:status_code, :message)
      def success?
        !failure?
      end

      def failure?
        transient_failure? || permanent_failure?
      end

      def transient_failure?
        status_code.start_with?("4.")
      end

      def permanent_failure?
        status_code.start_with?("5.")
      end
    end

    CONTENT_TYPE = "message/rfc822"
    USER_AGENT   = "Action Mailbox relayer v#{ActionMailbox.version}"

    attr_reader :uri, :username, :password

    def initialize(url:, password:, username: "actionmailbox")
      @uri, @username, @password = URI(url), username, password
    end

    def relay(source)
      case response = post(source)
      when Net::HTTPSuccess
        Result.new "2.0.0", "Successfully relayed message to ingress"
      when Net::HTTPUnauthorized
        Result.new "4.7.0", "Invalid credentials for ingress"
      else
        Result.new "4.0.0", "HTTP #{response.code}"
      end
    rescue IOError, SocketError, SystemCallError => error
      Result.new "4.4.2", "Network error relaying to ingress: #{error.message}"
    rescue Timeout::Error
      Result.new "4.4.2", "Timed out relaying to ingress"
    rescue => error
      Result.new "4.0.0", "Error relaying to ingress: #{error.message}"
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
