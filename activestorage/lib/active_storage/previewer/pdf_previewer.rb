# frozen_string_literal: true

module ActiveStorage
  class Previewer::PDFPreviewer < Previewer
    def self.accept?(blob)
      blob.content_type == "application/pdf"
    end

    def preview
      download_blob_to_tempfile do |input|
        draw "mutool", "draw", "-F", "png", "-o", "-", input.path, "1" do |output|
          yield io: output, filename: "#{blob.filename.base}.png", content_type: "image/png"
        end
      end
    end
  end
end
