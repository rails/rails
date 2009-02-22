require 'active_support/ordered_hash'

module Rails
  module Rack
    class Metal
      NotFoundResponse = [404, {}, []].freeze
      NotFound = lambda { NotFoundResponse }

      cattr_accessor :metal_paths
      self.metal_paths = ["#{Rails.root}/app/metal"]

      def self.metals
        matcher = /#{Regexp.escape('/app/metal/')}(.*)\.rb\Z/
        metal_glob = metal_paths.map{ |base| "#{base}/**/*.rb" }

        Dir[*metal_glob].sort.map do |file|
          path = file.match(matcher)[1]
          require path
          path.classify.constantize
        end
      end

      def initialize(app)
        @app = app
        @metals = ActiveSupport::OrderedHash.new
        self.class.metals.each { |app| @metals[app] = true }
        freeze
      end

      def call(env)
        @metals.keys.each do |app|
          result = app.call(env)
          return result unless result[0].to_i == 404
        end
        @app.call(env)
      end
    end
  end
end
