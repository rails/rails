# frozen_string_literal: true

module ActiveStorage
  class Analyzer::NullAnalyzer < Analyzer # :nodoc:
    def self.accept?(blob)
      true
    end

    def self.analyze_later?
      false
    end

    def metadata
      {}
    end
  end
end
