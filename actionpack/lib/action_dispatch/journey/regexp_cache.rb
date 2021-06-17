# frozen_string_literal: true

module ActionDispatch
  # :stopdoc:
  module Journey
    module RegexpCache
      extend self

      ANCHORED = ObjectSpace::WeakMap.new

      def anchored(source)
        source = -source.to_s
        ANCHORED[source] ||= /\A#{source}\Z/
      end
    end
  end
end
