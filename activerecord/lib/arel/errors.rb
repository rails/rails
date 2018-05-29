# frozen_string_literal: true

module Arel # :nodoc: all
  class ArelError < StandardError
  end

  class EmptyJoinError < ArelError
  end
end
