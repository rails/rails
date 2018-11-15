# frozen_string_literal: true

namespace :action_mailbox do
  namespace :ingress do
    desc "Pipe an inbound email from STDIN to the Postfix ingress at the given URL"
    task :postfix do
      require "active_support"
      require "active_support/core_ext/object/blank"
      require "http"

      url, password = ENV.values_at("URL", "INGRESS_PASSWORD")

      if url.blank? || password.blank?
        puts "4.3.5 URL and INGRESS_PASSWORD are required"
        exit 1
      end

      begin
        response = HTTP.basic_auth(user: "actionmailbox", pass: password)
          .timeout(connect: 1, write: 10, read: 10)
          .post(url, body: STDIN.read,
            headers: { "Content-Type" => "message/rfc822", "User-Agent" => ENV.fetch("USER_AGENT", "Postfix") })

        case
        when response.status.success?
          puts "2.0.0 HTTP #{response.status}"
        when response.status.unauthorized?
          puts "4.7.0 HTTP #{response.status}"
          exit 1
        when response.status.unsupported_media_type?
          puts "5.6.1 HTTP #{response.status}"
          exit 1
        else
          puts "4.0.0 HTTP #{response.status}"
          exit 1
        end
      rescue HTTP::ConnectionError => error
        puts "4.4.2 Error connecting to the Postfix ingress: #{error.message}"
        exit 1
      rescue HTTP::TimeoutError
        puts "4.4.7 Timed out piping to the Postfix ingress"
        exit 1
      end
    end
  end
end
