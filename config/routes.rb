# frozen_string_literal: true

Rails.application.routes.draw do
  post "/rails/action_mailroom/inbound_emails" => "action_mailroom/inbound_emails#create", as: :rails_inbound_emails

  # TODO: Should these be mounted within the engine only?
  scope "rails/conductor/action_mailroom/", module: "rails/conductor/action_mailroom" do
    resources :inbound_emails, as: :rails_conductor_inbound_emails
    post ":inbound_email_id/reroute" => "reroutes#create", as: :rails_conductor_inbound_email_reroute
  end
end
