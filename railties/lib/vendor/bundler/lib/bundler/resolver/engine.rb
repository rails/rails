module Bundler
  module Resolver
    class ClosedSet < Set
    end

    class Engine
      include Search, Inspect

      def self.resolve(deps, source_index, logger)
        new(deps, source_index, logger).resolve
      end

      def initialize(deps, source_index, logger)
        @deps, @source_index, @logger = deps, source_index, logger
        logger.debug "searching for #{gem_resolver_inspect(@deps)}"
      end
      attr_reader :deps, :source_index, :logger, :solution

      def resolve
        state = State.initial(self, [], Stack.new, Stack.new([[[], @deps.dup]]))
        if solution = search(state)
          logger.info "got the solution with #{solution.all_specs.size} specs"
          solution.dump(Logger::INFO)
          solution
        end
      end

      def open
        @open ||= []
      end

      def closed
        @closed ||= ClosedSet.new
      end
    end
  end

end