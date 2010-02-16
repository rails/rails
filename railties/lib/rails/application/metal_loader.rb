require 'action_dispatch'

module Rails
  class Application
    class MetalLoader
      attr_reader :paths, :metals

      def initialize
        @paths, @metals = [], []
      end

      def build_middleware(list=nil)
        load_metals!(list)
        self
      end

      def new(app)
        ActionDispatch::Cascade.new(@metals, app)
      end

      def name
        ActionDispatch::Cascade.name
      end
      alias :to_s :name

    protected

      def load_metals!(list)
        metals = []
        list = Array(list || :all).map(&:to_sym)

        paths.each do |path|
          matcher = /\A#{Regexp.escape(path)}\/(.*)\.rb\Z/
          Dir.glob("#{path}/**/*.rb").sort.each do |metal_path|
            metal = metal_path.sub(matcher, '\1').to_sym
            next unless list.include?(metal) || list.include?(:all)
            require_dependency metal.to_s
            metals << metal
          end
        end

        metals = metals.sort_by do |m|
          [list.index(m) || list.index(:all), m.to_s]
        end

        @metals = metals.map { |m| m.to_s.camelize.constantize }
      end
    end
  end
end
