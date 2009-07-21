module Bundler
  module Resolver
    module Builders
      def build_index(&block)
        index = Gem::SourceIndex.new
        IndexBuilder.run(index, &block) if block_given?
        index
      end

      def build_spec(name, version, &block)
        spec = Gem::Specification.new
        spec.instance_variable_set(:@name, name)
        spec.instance_variable_set(:@version, Gem::Version.new(version))
        DepBuilder.run(spec, &block) if block_given?
        spec
      end

      def build_dep(name, requirements, type = :runtime)
        Gem::Dependency.new(name, requirements, type)
      end

      class IndexBuilder
        include Builders

        def self.run(index, &block)
          new(index).run(&block)
        end

        def initialize(index)
          @index = index
        end

        def run(&block)
          instance_eval(&block)
        end

        def add_spec(*args, &block)
          @index.add_spec(build_spec(*args, &block))
        end
      end

      class DepBuilder
        def self.run(spec, &block)
          new(spec).run(&block)
        end

        def initialize(spec)
          @spec = spec
        end

        def run(&block)
          instance_eval(&block)
        end

        def runtime(name, requirements)
          @spec.add_runtime_dependency(name, requirements)
        end
      end
    end
  end
end