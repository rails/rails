# frozen_string_literal: true

require "active_support/core_ext/module/delegation"

module CodeStatisticsReport #:nodoc:
  class Base #:nodoc:
    delegate_missing_to :@code_statistics

    def initialize(code_statistics)
      @code_statistics = code_statistics
    end

    def result
      raise NotImplementedError
    end
  end
end
