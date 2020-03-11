# frozen_string_literal: true

module ActiveStorage
  class Previewer::VideoPreviewer < Previewer
    def self.accept?(blob)
      blob.video?
    end

    def preview(**options)
      download_blob_to_tempfile do |input|
        blob.analyze unless blob.metadata["analyzed"]
        seconds = blob.metadata["duration"] ? ([(blob.metadata["duration"] * 0.1).ceil, blob.metadata["duration"]].min).floor : 0
        draw_relevant_frame_from input, seconds do |output|
          yield io: output, filename: "#{blob.filename.base}.jpg", content_type: "image/jpeg", **options
        end
      end
    end

    private
      def draw_relevant_frame_from(file, seconds, &block)
        draw ffmpeg_path, "-ss", seconds.to_s, "-i", file.path, "-y", "-vframes", "1", "-f", "image2", "-", &block
      end

      def ffmpeg_path
        ActiveStorage.paths[:ffmpeg] || "ffmpeg"
      end
  end
end
