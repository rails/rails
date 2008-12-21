require 'rails/rack/cascade'

module Rails
  module Rack
    module Metal
      NotFoundResponse = [404, {}, []].freeze
      NotFound = lambda { NotFoundResponse }

      class << self
        def new(app)
          Cascade.new(builtins + [app])
        end

        def builtins
          base = "#{Rails.root}/app/metal"
          matcher = /\A#{Regexp.escape(base)}\/(.*)\.rb\Z/

          Dir["#{base}/**/*.rb"].sort.map do |file|
            file.sub!(matcher, '\1')
            require file
            file.classify.constantize
          end
        end
      end
    end
  end
end
