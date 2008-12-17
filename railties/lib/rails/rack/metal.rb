module Rails
  module Rack
    class Metal
      def self.new(app)
        apps = Dir["#{Rails.root}/app/metal/*.rb"].map do |file|
          File.basename(file, '.rb').camelize.constantize
        end
        apps << app
        ::Rack::Cascade.new(apps)
      end

      NotFound = lambda { |env|
        [404, {"Content-Type" => "text/html"}, "Not Found"]
      }
    end
  end
end
