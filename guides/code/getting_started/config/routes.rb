Rails.application.routes.draw do
  resources :posts do
    resources :comments
  end

  root "welcome#index"
end
