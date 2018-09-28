# frozen_string_literal: true

Rails.application.routes.draw do
  post "/rails/action_mailbox/inbound_emails" => "action_mailbox/inbound_emails#create", as: :rails_inbound_emails

  # TODO: Should these be mounted within the engine only?
  scope "rails/conductor/action_mailbox/", module: "rails/conductor/action_mailbox" do
    resources :inbound_emails, as: :rails_conductor_inbound_emails
    post ":inbound_email_id/reroute" => "reroutes#create", as: :rails_conductor_inbound_email_reroute
  end
end
