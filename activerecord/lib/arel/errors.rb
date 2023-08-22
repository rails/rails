# frozen_string_literal: true

module Arel # :nodoc: all
  class ArelError < StandardError
  end

  class EmptyJoinError < ArelError
  end

  class BindError < ArelError
    def initialize(message, sql = nil)
      if sql
        super("#{message} in: #{sql.inspect}")
      else
        super(message)
      end
    end
  end
end
