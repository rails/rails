require 'action_dispatch'

module Rails
  class Application
    class Metal
      def self.paths
        @paths ||= []
      end

      def self.metals
        @metals ||= []
      end

      def initialize(list=nil)
        metals = []
        list   = Array(list || :all).map(&:to_sym)

        self.class.paths.each do |path|
          matcher = /\A#{Regexp.escape(path)}\/(.*)\.rb\Z/
          Dir.glob("#{path}/**/*.rb").sort.each do |metal_path|
            metal = metal_path.sub(matcher, '\1').to_sym
            next unless list.include?(metal) || list.include?(:all)
            require_dependency metal
            metals << metal
          end
        end

        metals = metals.sort_by do |m|
          [list.index(m) || list.index(:all), m.to_s]
        end

        @metals = metals.map { |m| m.to_s.camelize.constantize }
        self.class.metals.concat(@metals)
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
