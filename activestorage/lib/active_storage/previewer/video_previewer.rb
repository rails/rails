# frozen_string_literal: true

module ActiveStorage
  class Previewer::VideoPreviewer < Previewer
    def self.accept?(blob)
      blob.video?
    end

    def preview
      download_blob_to_tempfile do |input|
        draw_relevant_frame_from input do |output|
          yield io: output, filename: "#{blob.filename.base}.jpg", content_type: "image/jpeg"
        end
      end
    end

    private
      def draw_relevant_frame_from(file, &block)
        draw ffmpeg_path, "-i", file.path, "-y", "-vframes", "1", "-f", "image2", "-", &block
      end

      def ffmpeg_path
        ActiveStorage.paths[:ffmpeg] || "ffmpeg"
      end
  end
end
