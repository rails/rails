module Folder
  class MetalA < Rails::Rack::Metal
    def self.call(env)
      [200, { "Content-Type" => "text/html"}, ["Hi"]]
    end
  end
end
