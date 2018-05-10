# frozen_string_literal: true

module ActiveStorage
  class Analyzer::NullAnalyzer < Analyzer # :nodoc:
    def self.accept?(_blob)
      true
    end

    def metadata
      {}
    end
  end
end
