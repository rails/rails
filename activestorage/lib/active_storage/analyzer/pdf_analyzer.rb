# frozen_string_literal: true

module ActiveStorage
  # Extracts width, height in pixels and number of pages from a pdf blob.
  #
  # Example:
  #
  #   ActiveStorage::Analyzer::PDFAnalyzer::Poppler.new(blob).metadata
  #   # => { width: 4104, height: 2736, pages: 10 }
  class Analyzer::PDFAnalyzer < Analyzer
    def self.accept?(blob)
      blob.content_type == "application/pdf"
    end

    def metadata
      { width: width, height: height, pages: pages }.compact
    end

    private
      def width
        raise NotImplementedError
      end

      def height
        raise NotImplementedError
      end

      def pages
        raise NotImplementedError
      end
  end
end
