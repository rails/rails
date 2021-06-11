# frozen_string_literal: true

module ActiveStorage
  # This analyzer requires the {poppler}[https://poppler.freedesktop.org/] system library, which is not provided by Rails.
  class Analyzer::PDFAnalyzer::PopplerPDF < Analyzer::PDFAnalyzer
    class << self
      def accept?(blob)
        super && pdfinfo_exists?
      end

      def pdfinfo_path
        ActiveStorage.paths[:pdfinfo] || "pdfinfo"
      end

      def pdfinfo_exists?
        return @pdfinfo_exists if defined?(@pdfinfo_exists)

        @pdfinfo_exists = system(pdfinfo_path, "-v", out: File::NULL, err: File::NULL)
      end
    end

    private
      def pages
        pages = info["Pages"]
        Integer(pages) if pages
      end

      def width
        (right - left).floor if cropbox.present?
      end

      def height
        (top - bottom).floor if cropbox.present?
      end

      def left
        Float cropbox[0]
      end

      def bottom
        Float cropbox[1]
      end

      def right
        Float cropbox[2]
      end

      def top
        Float cropbox[3]
      end

      def cropbox
        return @cropbox if defined?(@cropbox)
        @cropbox = (info["CropBox"] || "").split
      end

      def info
        @info ||= download_blob_to_tempfile { |file| info_from(file) }
      end

      def info_from(file)
        IO.popen([self.class.pdfinfo_path, "-box", file.path]) do |output|
          output.read.scan(/^(.*?): *(.*)?/).to_h
        end
      rescue Errno::ENOENT
        logger.info "Skipping pdf analysis due to an error"
        {}
      end
  end
end
