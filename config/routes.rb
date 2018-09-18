# frozen_string_literal: true

Rails.application.routes.draw do
  scope "rails/action_mailroom" do
    post "/inbound_emails" => "action_mailroom/inbound_emails#create", as: :rails_inbound_emails
  end
end
