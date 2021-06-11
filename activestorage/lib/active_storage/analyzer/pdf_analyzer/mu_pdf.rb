# frozen_string_literal: true

module ActiveStorage
  # This analyzer requires the {MuPDF}[https://mupdf.com/] system library, which is not provided by Rails.
  class Analyzer::PDFAnalyzer::MuPDF < Analyzer::PDFAnalyzer
    class << self
      def accept?(blob)
        super && mutool_exists?
      end

      def mutool_path
        ActiveStorage.paths[:mutool] || "mutool"
      end

      def mutool_exists?
        return @mutool_exists if defined?(@mutool_exists) && !@mutool_exists.nil?

        system mutool_path, out: File::NULL, err: File::NULL

        @mutool_exists = $?.exitstatus == 1
      end
    end

    private
      def pages
        info.xpath("//page").count
      end

      def width
        (right - left).floor if cropbox.present?
      end

      def height
        (top - bottom).floor if cropbox.present?
      end

      def left
        Float cropbox["l"]
      end

      def bottom
        Float cropbox["b"]
      end

      def right
        Float cropbox["r"]
      end

      def top
        Float cropbox["t"]
      end

      def cropbox
        return @cropbox if defined?(@cropbox)
        @cropbox = info.xpath("//CropBox").first || []
      end

      def info
        @info ||= download_blob_to_tempfile { |file| info_from(file) }
      end

      def info_from(file)
        IO.popen([self.class.mutool_path, "pages", file.path]) do |output|
          Nokogiri::XML output.readlines[1..-1].join
        end
      rescue Errno::ENOENT
        logger.info "Skipping pdf analysis due to an error"
        {}
      end
  end
end
