require 'active_support/ordered_hash'

module Rails
  module Rack
    class Metal
      NotFoundResponse = [404, {}, []].freeze
      NotFound = lambda { NotFoundResponse }

      def self.metals
        base = "#{Rails.root}/app/metal"
        matcher = /\A#{Regexp.escape(base)}\/(.*)\.rb\Z/

        Dir["#{base}/**/*.rb"].sort.map do |file|
          file.sub!(matcher, '\1')
          require file
          file.classify.constantize
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
