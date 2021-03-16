# frozen_string_literal: true

Rails.application.routes.draw do
  scope "/rails/action_mailbox", module: "action_mailbox/ingresses" do
    post "/postmark/inbound_emails" => "postmark/inbound_emails#create", as: :rails_postmark_inbound_emails
    post "/relay/inbound_emails"    => "relay/inbound_emails#create",    as: :rails_relay_inbound_emails
    post "/sendgrid/inbound_emails" => "sendgrid/inbound_emails#create", as: :rails_sendgrid_inbound_emails

    # Mandrill checks for the existence of a URL with a HEAD request before it will create the webhook.
    get "/mandrill/inbound_emails"  => "mandrill/inbound_emails#health_check", as: :rails_mandrill_inbound_health_check
    post "/mandrill/inbound_emails" => "mandrill/inbound_emails#create",       as: :rails_mandrill_inbound_emails

    # Mailgun requires that a webhook's URL end in 'mime' for it to receive the raw contents of emails.
    post "/mailgun/inbound_emails/mime" => "mailgun/inbound_emails#create", as: :rails_mailgun_inbound_emails
  end

  # TODO: Should these be mounted within the engine only?
  scope "rails/conductor/action_mailbox/", module: "rails/conductor/action_mailbox" do
    resources :inbound_emails, as: :rails_conductor_inbound_emails
    get  "inbound_emails/sources/new", to: "inbound_emails/sources#new", as: :new_rails_conductor_inbound_email_source
    post "inbound_emails/sources", to: "inbound_emails/sources#create", as: :rails_conductor_inbound_email_sources

    post ":inbound_email_id/reroute" => "reroutes#create", as: :rails_conductor_inbound_email_reroute
  end
end if ActionMailbox.draw_routes
