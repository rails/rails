ActionDispatch::Routing::Routes.draw do |map|
  match '/rails/info/properties' => "rails/info#properties"
end
