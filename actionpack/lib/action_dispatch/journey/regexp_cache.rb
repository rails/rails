# frozen_string_literal: true

module ActionDispatch
  # :stopdoc:
  module Journey
    module RegexpCache
      extend self

      ANCHORED = {}

      def anchored(source)
        ANCHORED[source] ||= /\A#{source}\Z/
      end
    end
  end
end