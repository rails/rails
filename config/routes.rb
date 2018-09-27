# frozen_string_literal: true

Rails.application.routes.draw do
  scope 'rails/action_mailroom', module: 'action_mailroom' do
    resources :inbound_emails, as: :rails_inbound_emails
  end
end
