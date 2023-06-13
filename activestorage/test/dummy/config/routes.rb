Rails.application.routes.draw do
  post "/prefixed_direct_uploads" => "prefixed_direct_uploads#create"
end
