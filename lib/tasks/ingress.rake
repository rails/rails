# frozen_string_literal: true

namespace :action_mailbox do
  namespace :ingress do
    desc "Pipe an inbound email from STDIN to the Postfix ingress (URL and INGRESS_PASSWORD required)"
    task :postfix do
      require "active_support"
      require "active_support/core_ext/object/blank"
      require "action_mailbox/postfix_relayer"

      url, password, user_agent = ENV.values_at("URL", "INGRESS_PASSWORD", "USER_AGENT")

      if url.blank? || password.blank?
        print "4.3.5 URL and INGRESS_PASSWORD are required"
        exit 1
      end

      ActionMailbox::PostfixRelayer.new(url: url, password: password, user_agent: user_agent)
        .relay(STDIN.read).tap do |result|
          print result.output
          exit result.success? ? 0 : 1
        end
    end
  end
end
