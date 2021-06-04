Rails.application.routes.draw do
  resources :messages

  namespace :admin do
    resources :messages, only: [:show]
  end
end
