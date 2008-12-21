require 'active_support/ordered_hash'

module Rails
  module Rack
    # Try a request on several apps; return the first non-404 response.
    class Cascade
      attr_reader :apps

      def initialize(apps)
        @apps = ActiveSupport::OrderedHash.new
        apps.each { |app| add app }
      end

      def call(env)
        @apps.keys.each do |app|
          result = app.call(env)
          return result unless result[0].to_i == 404
        end
        Metal::NotFoundResponse
      end

      def add(app)
        @apps[app] = true
      end

      def include?(app)
        @apps.include?(app)
      end
    end
  end
end
