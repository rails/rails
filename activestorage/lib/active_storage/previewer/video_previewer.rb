# frozen_string_literal: true

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
        ffmpeg_args = [
          "-i", file.path,
          "-vf",
            # Select the first video frame, plus keyframes and frames
            # that meet the scene change threshold.
            'select=eq(n\,0)+eq(key\,1)+gt(scene\,0.015),' +
            # Loop the first 1-2 selected frames in case we were only
            # able to select 1 frame, then drop the first looped frame.
            # This lets us use the first video frame as a fallback.
            "loop=loop=-1:size=2,trim=start_frame=1",
          "-frames:v", "1",
          "-f", "image2", "-",
        ]

        draw self.class.ffmpeg_path, *ffmpeg_args, &block
      end
  end
end
