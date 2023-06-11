# frozen_string_literal: true

Rails.application.routes.draw do
  get "/streaming", to: "streaming#index"
end
