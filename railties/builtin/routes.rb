Rails.application.routes.draw do |map|
  match '/rails/info/properties' => "rails/info#properties"
end
