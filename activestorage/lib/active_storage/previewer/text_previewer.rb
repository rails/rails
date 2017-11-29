# frozen_string_literal: true

module ActiveStorage
  class Previewer::TextPreviewer < Previewer
    def self.accept?(blob)
      blob.text?
    end

    def preview
      download_blob_to_tempfile do |input|
        draw_text_preview_from input do |output|
          yield io: output, filename: "#{blob.filename.base}.png", content_type: "image/png"
        end
      end
    end

    private
      def draw_text_preview_from(file, &block)
        draw "convert", "-size", "300x300", "xc:white", "-pointsize", "18",
          "-draw", "text 10 28 '#{ escape file.read }'", "png:-", &block
      end

      def escape(string)
        string.gsub("'", "\\'")
      end
  end
end
