# frozen_string_literal: true

module ActiveStorage
  # This is an abstract base class for analyzers, which extract metadata from blobs. See
  # ActiveStorage::Analyzer::ImageAnalyzer for an example of a concrete subclass.
  class Analyzer
    attr_reader :blob

    # Implement this method in a concrete subclass. Have it return true when given a blob from which
    # the analyzer can extract metadata.
    def self.accept?(blob)
      false
    end

    # Implement this method in concrete subclasses. It will determine if blob analysis
    # should be done in a job or performed inline. By default, analysis is enqueued in a job.
    def self.analyze_later?
      true
    end

    def initialize(blob)
      @blob = blob
    end

    # Override this method in a concrete subclass. Have it return a Hash of metadata.
    def metadata
      raise NotImplementedError
    end

    private
      # Downloads the blob to a tempfile on disk. Yields the tempfile.
      def download_blob_to_tempfile(&block) #:doc:
        blob.open tmpdir: tmpdir, &block
      end

      def logger #:doc:
        ActiveStorage.logger
      end

      def tmpdir #:doc:
        Dir.tmpdir
      end
  end
end
