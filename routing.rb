# frozen_string_literal: true

 ActionMailbox
  # See ActionMailbox::Base for how to specify routing.
   Routing
     ActiveSupport::Concern

    included do
      cattr_accessor :router, default: ActionMailbox::Router.new
    

    class_methods do
       routing(routes)
        router.add_routes(routes)
      

       route(inbound_email)
        router.route(inbound_email)
      

       mailbox_for(inbound_email)
        router.mailbox_for(inbound_email)
    
    
