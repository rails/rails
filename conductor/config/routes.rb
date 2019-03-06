# frozen_string_literal: true

Rails.application.routes.draw do
  get "rails/conductor" => "rails/conductor/panels#show", as: :rails_conductor
  get "rails/conductor/source/statistics" => "rails/conductor/source/statistics#show", as: :rails_conductor_source_statistics
  get "rails/conductor/source/notes" => "rails/conductor/source/notes#show", as: :rails_conductor_source_notes
end
