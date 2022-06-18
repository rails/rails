# frozen_string_literal: true

require "shellwords"

module ActiveStorage
  class Previewer::VideoPreviewer < Previewer
    class << self
      def accept?(blob)
        blob.video? && ffmpeg_exists?
      end

      def ffmpeg_exists?
        return @ffmpeg_exists if defined?(@ffmpeg_exists)

        @ffmpeg_exists = system(ffmpeg_path, "-version", out: File::NULL, err: File::NULL)
      end

      def ffmpeg_path
        ActiveStorage.paths[:ffmpeg] || "ffmpeg"
      end
    end

    def preview(**options)
      download_blob_to_tempfile do |input|
        draw_relevant_frame_from input do |output|
          yield io: output, filename: "#{blob.filename.base}.jpg", content_type: "image/jpeg", **options
        end
      end
    end

    private
      def draw_relevant_frame_from(file, &block)
        draw self.class.ffmpeg_path, "-i", file.path, *Shellwords.split(ActiveStorage.video_preview_arguments), "-", &block
      end
  end
end
