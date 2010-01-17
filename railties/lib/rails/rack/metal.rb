require 'action_dispatch'

module Rails
  module Rack
    class Metal
      def initialize(metal_roots, metals=nil)
        load_list = metals || Dir["{#{metal_roots.join(",")}}/**/*.rb"]

        @metals = load_list.map { |metal|
          metal = File.basename(metal, '.rb')
          require_dependency metal
          metal.camelize.constantize
        }.compact
      end

      def new(app)
        ActionDispatch::Cascade.new(@metals, app)
      end

      def name
        ActionDispatch::Cascade.name
      end
      alias_method :to_s, :name
    end
  end
end
