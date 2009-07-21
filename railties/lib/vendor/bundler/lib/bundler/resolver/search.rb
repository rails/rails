module Bundler
  module Resolver
    module Search
      def search(initial, max_depth = (1.0 / 0.0))
        if initial.goal_met?
          return initial
        end

        open << initial

        while open.any?
          current = open.pop
          closed << current

          new = []
          current.each_possibility do |attempt|
            unless closed.include?(attempt)
              if attempt.goal_met?
                return attempt
              elsif attempt.depth < max_depth
                new << attempt
              end
            end
          end
          new.reverse.each do |state|
            open << state
          end
        end

        nil
      end

      def open
        raise "implement #open in #{self.class}"
      end

      def closed
        raise "implement #closed in #{self.class}"
      end

      module Node
        def self.included(base)
          base.extend(ClassMethods)
        end

        module ClassMethods
          def initial(*data)
            new(0, *data)
          end
        end

        def initialize(depth)
          @depth = depth
        end
        attr_reader :depth

        def child(*data)
          self.class.new(@depth + 1, *data)
        end

        def each_possibility
          raise "implement #each_possibility on #{self.class}"
        end

        def goal_met?
          raise "implement #goal_met? on #{self.class}"
        end
      end
    end
  end
end