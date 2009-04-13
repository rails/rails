class LegacyRoutes < Rails::Rack::Metal
  def self.call(env)
    [301, { "Location" => "http://example.com"}, []]
  end
end
