# frozen_string_literal: true

Rails.application.routes.draw do
  get "rails/conductor" => "rails/conductor/panels#show", as: :rails_conductor
end
