# frozen_string_literal: true
module Arel
  module Visitors
    class BindSubstitute
      def initialize delegate
        @delegate = delegate
      end
    end
  end
end
