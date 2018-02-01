# frozen_string_literal: true

require "active_storage/downloading"

module ActiveStorage
  # This is an abstract base class for analyzers, which extract metadata from blobs. See
  # ActiveStorage::Analyzer::ImageAnalyzer for an example of a concrete subclass.
  class Analyzer
    include Downloading

    attr_reader :blob

    # Implement this method in a concrete subclass. Have it return true when given a blob from which
    # the analyzer can extract metadata.
    def self.accept?(blob)
      false
    end

    def initialize(blob)
      @blob = blob
    end

    # Override this method in a concrete subclass. Have it return a Hash of metadata.
    def metadata
      raise NotImplementedError
    end

    private
      def logger #:doc:
        ActiveStorage.logger
      end
  end
end
