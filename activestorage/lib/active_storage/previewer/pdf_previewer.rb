# frozen_string_literal: true

module ActiveStorage
  class Previewer::PDFPreviewer < Previewer
    class_attribute :mutool_path, default: "mutool"

    def self.accept?(blob)
      blob.content_type == "application/pdf"
    end

    def preview
      download_blob_to_tempfile do |input|
        draw_first_page_from input do |output|
          yield io: output, filename: "#{blob.filename.base}.png", content_type: "image/png"
        end
      end
    end

    private
      def draw_first_page_from(file, &block)
        draw mutool_path, "draw", "-F", "png", "-o", "-", file.path, "1", &block
      end
  end
end
