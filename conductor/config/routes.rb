# frozen_string_literal: true

Rails.application.routes.draw do
  get "rails/conductor" => "rails/conductor/panels#show", as: :rails_conductor
  get "rails/conductor/statistics" => "rails/conductor/statistics#show", as: :rails_conductor_statistics
  get "rails/conductor/notes" => "rails/conductor/notes#show", as: :rails_conductor_notes
end
