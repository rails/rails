# frozen_string_literal: true

namespace :action_mailbox do
  namespace :ingress do
    desc "Pipe an inbound email from STDIN to the Postfix ingress at the given URL"
    task :postfix do
      require "active_support"
      require "active_support/core_ext/object/blank"
      require "http"

      unless url = ENV["URL"].presence
        abort "5.3.5 URL is required"
      end

      unless password = ENV["INGRESS_PASSWORD"].presence
        abort "5.3.5 INGRESS_PASSWORD is required"
      end

      begin
        response = HTTP.basic_auth(user: "actionmailbox", pass: password)
          .timeout(connect: 1, write: 10, read: 10)
          .post(url, headers: { "Content-Type" => "message/rfc822", "User-Agent" => ENV.fetch("USER_AGENT", "Postfix") }, body: STDIN)

        case
        when response.status.success?
          puts "2.0.0 HTTP #{response.status}"
        when response.status.unauthorized?
          abort "4.7.0 HTTP #{response.status}"
        when response.status.unsupported_media_type?
          abort "5.6.1 HTTP #{response.status}"
        else
          abort "4.0.0 HTTP #{response.status}"
        end
      rescue HTTP::ConnectionError => error
        abort "4.4.2 Error connecting to the Postfix ingress: #{error.message}"
      rescue HTTP::TimeoutError
        abort "4.4.7 Timed out piping to the Postfix ingress"
      end
    end
  end
end
