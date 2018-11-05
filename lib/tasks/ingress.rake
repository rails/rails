# frozen_string_literal: true

namespace :action_mailbox do
  namespace :ingress do
    desc "Pipe an inbound email from STDIN to the Postfix ingress at the given URL"
    task :postfix do
      require "active_support"
      require "active_support/core_ext/object/blank"
      require "http"

      unless url = ENV["URL"].presence
        abort "URL is required"
      end

      unless password = ENV["INGRESS_PASSWORD"].presence
        abort "INGRESS_PASSWORD is required"
      end

      begin
        response = HTTP.basic_auth(user: "actionmailbox", pass: password)
          .timeout(connect: 1, write: 10, read: 10)
          .post(url, headers: { "Content-Type" => "message/rfc822", "User-Agent" => "Postfix" }, body: STDIN)

        if response.status.success?
          puts "2.0.0 HTTP #{response.status}"
          exit 0
        else
          puts "4.6.0 HTTP #{response.status}"
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
