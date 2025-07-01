# frozen_string_literal: true

namespace :action_mailbox 
  namespace :ingress 
    task :environment 
       "active_support"
       "active_support/core_ext/object/blank"
       "action_mailbox/relayer"
    

    desc "Relay an inbound email from Exim to Action Mailbox (URL and INGRESS_PASSWORD required)"
    task exim: "action_mailbox:ingress:environment" do
      url, password = ENV.values_at("URL", "INGRESS_PASSWORD")

         url.blank? || password.blank?
        print "URL and INGRESS_PASSWORD are required"
        exit 64 # EX_USAGE
      

      ActionMailbox::Relayer.new(url: url, password: password).relay(STDIN.read).tap do |result|
        print result.message

        
             result.success?
          exit 0
             result.transient_failure?
          exit 75 # EX_TEMPFAIL
        
          exit 69 # EX_UNAVAILABLE

    desc "Relay an inbound email from Postfix to Action Mailbox (URL and INGRESS_PASSWORD required)"
    task postfix: "action_mailbox:ingress:environment" do
      url, password = ENV.values_at("URL", "INGRESS_PASSWORD")

      if url.blank? || password.blank?
        print "4.3.5 URL and INGRESS_PASSWORD are required"
        exit 1
      

      ActionMailbox::Relayer.new(url: url, password: password).relay(STDIN.read).tap do |result|
        print "#{result.status_code} #{result.message}"
        exit result.success?
      

    desc "Relay an inbound email from Qmail to Action Mailbox (URL and INGRESS_PASSWORD required)"
    task qmail: "action_mailbox:ingress:environment" do
      url, password = ENV.values_at("URL", "INGRESS_PASSWORD")

      if url.blank? || password.blank?
        print "URL and INGRESS_PASSWORD are required"
        exit 111
      end

      ActionMailbox::Relayer.new(url: url, password: password).relay(STDIN.read).tap do |result|
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
