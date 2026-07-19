# frozen_string_literal: true

require "shellwords"

module ActiveStorage
  class Previewer::VideoPreviewer < Previewer
    class << self
      def accept?(blob)
        blob.video? && ffmpeg_exists?
      end

      def ffmpeg_exists?
        return @ffmpeg_exists unless @ffmpeg_exists.nil?

        @ffmpeg_exists = system(ffmpeg_path, "-version", out: File::NULL, err: File::NULL)
      end

      def ffmpeg_path
        ActiveStorage.paths[:ffmpeg] || "ffmpeg"
      end

      def ffprobe_path
        ActiveStorage.paths[:ffprobe] || "ffprobe"
      end
    end

    def preview(**options)
      download_blob_to_tempfile do |input|
        # ffmpeg can't extract a frame from a container that has no video stream
        # (e.g. an audio-only file with a video/* content type). Skip previewing
        # such a blob instead of raising an ActiveStorage::PreviewError.
        next unless video_stream?(input)

        draw_relevant_frame_from input do |output|
          yield io: output, filename: "#{blob.filename.base}.jpg", content_type: "image/jpeg", **options
        end
      end
    end

    private
      def draw_relevant_frame_from(file, &block)
        draw self.class.ffmpeg_path, "-i", file.path, *Shellwords.split(ActiveStorage.video_preview_arguments), "-", &block
      end

      # Uses ffprobe to inspect the container's streams, as
      # ActiveStorage::Analyzer::VideoAnalyzer does. Returns +true+ when a video
      # stream is present or when the streams can't be determined (e.g. ffprobe
      # is unavailable or the file is unreadable), so the previous behavior is
      # preserved for anything other than a recognized audio-only container.
      def video_stream?(file)
        codec_types = probe_stream_codec_types(file)
        codec_types.empty? || codec_types.include?("video")
      end

      def probe_stream_codec_types(file)
        IO.popen([ self.class.ffprobe_path, "-v", "error", "-show_entries", "stream=codec_type", "-of", "csv=p=0", file.path ], err: File::NULL) do |output|
          output.read.split("\n")
        end
      rescue Errno::ENOENT
        logger.info "Skipping audio-only detection because ffprobe isn't installed"
        []
      end
  end
end
