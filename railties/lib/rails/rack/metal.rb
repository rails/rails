require 'active_support/ordered_hash'
require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/dependencies'

module Rails
  module Rack
    class Metal
      NotFoundResponse = [404, {}, []].freeze
      NotFound = lambda { NotFoundResponse }

      cattr_accessor :metal_paths
      self.metal_paths = ["#{Rails.root}/app/metal"]
      cattr_accessor :requested_metals
      
      cattr_accessor :pass_through_on
      self.pass_through_on = 404

      def self.metals
        matcher = /#{Regexp.escape('/app/metal/')}(.*)\.rb\Z/
        metal_glob = metal_paths.map{ |base| "#{base}/**/*.rb" }
        all_metals = {}

        metal_glob.each do |glob|
          Dir[glob].sort.map do |file|
            file = file.match(matcher)[1]
            all_metals[file.camelize] = file
          end
        end

        load_list = requested_metals || all_metals.keys

        load_list.map do |requested_metal|
          if metal = all_metals[requested_metal]
            require_dependency metal
            requested_metal.constantize
          end
        end.compact
      end

      def initialize(app)
        @app = app
        @pass_through_on = {}
        [*self.class.pass_through_on].each { |status| @pass_through_on[status] = true }
        
        @metals = ActiveSupport::OrderedHash.new
        self.class.metals.each { |app| @metals[app] = true }
        freeze
      end

      def call(env)
        @metals.keys.each do |app|
          result = app.call(env)
          return result unless @pass_through_on.include?(result[0].to_i)
        end
        @app.call(env)
      end
    end
  end
end
