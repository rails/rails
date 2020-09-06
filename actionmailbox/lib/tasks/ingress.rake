# frozen_string_literal: true

namespace :action_mailbox do
  namespace :ingress do
    task :environment do
      require "active_support"
      require "active_support/core_ext/object/blank"
      require "action_mailbox/relayer"
    end

    desc "Relay an inbound email from Exim to Action Mailbox (URL and INGRESS_PASSWORD required)"
    task exim: "action_mailbox:ingress:environment" do
      url, password = ENV.values_at("URL", "INGRESS_PASSWORD")

      if url.blank? || password.blank?
        print "URL and INGRESS_PASSWORD are required"
        exit 64 # EX_USAGE
      end

      ActionMailbox::Relayer.new(url: url, password: password).relay($stdin.read).tap do |result|
        print result.message

        case
        when result.success?
          exit 0
        when result.transient_failure?
          exit 75 # EX_TEMPFAIL
        else
          exit 69 # EX_UNAVAILABLE
        end
      end
    end

    desc "Relay an inbound email from Postfix to Action Mailbox (URL and INGRESS_PASSWORD required)"
    task postfix: "action_mailbox:ingress:environment" do
      url, password = ENV.values_at("URL", "INGRESS_PASSWORD")

      if url.blank? || password.blank?
        print "4.3.5 URL and INGRESS_PASSWORD are required"
        exit 1
      end

      ActionMailbox::Relayer.new(url: url, password: password).relay($stdin.read).tap do |result|
        print "#{result.status_code} #{result.message}"
        exit result.success?
      end
    end

    desc "Relay an inbound email from Qmail to Action Mailbox (URL and INGRESS_PASSWORD required)"
    task qmail: "action_mailbox:ingress:environment" do
      url, password = ENV.values_at("URL", "INGRESS_PASSWORD")

      if url.blank? || password.blank?
        print "URL and INGRESS_PASSWORD are required"
        exit 111
      end

      ActionMailbox::Relayer.new(url: url, password: password).relay($stdin.read).tap do |result|
        print result.message

        case
        when result.success?
          exit 0
        when result.transient_failure?
          exit 111
        else
          exit 100
        end
      end
    end
  end
end
