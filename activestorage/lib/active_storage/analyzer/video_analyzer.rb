# frozen_string_literal: true

require "active_support/core_ext/hash/compact"

module ActiveStorage
  # Extracts the following from a video blob:
  #
  # * Width (pixels)
  # * Height (pixels)
  # * Duration (seconds)
  # * Angle (degrees)
  # * Aspect ratio
  #
  # Example:
  #
  #   ActiveStorage::VideoAnalyzer.new(blob).metadata
  #   # => { width: 640, height: 480, duration: 5.0, angle: 0, aspect_ratio: [4, 3] }
  #
  # This analyzer requires the {ffmpeg}[https://www.ffmpeg.org] system library, which is not provided by Rails. You must
  # install ffmpeg yourself to use this analyzer.
  class Analyzer::VideoAnalyzer < Analyzer
    class_attribute :ffprobe_path, default: "ffprobe"

    def self.accept?(blob)
      blob.video?
    end

    def metadata
      { width: width, height: height, duration: duration, angle: angle, aspect_ratio: aspect_ratio }.compact
    end

    private
      def width
        Integer(video_stream["width"]) if video_stream["width"]
      end

      def height
        Integer(video_stream["height"]) if video_stream["height"]
      end

      def duration
        Float(video_stream["duration"]) if video_stream["duration"]
      end

      def angle
        Integer(tags["rotate"]) if tags["rotate"]
      end

      def aspect_ratio
        if descriptor = video_stream["display_aspect_ratio"]
          descriptor.split(":", 2).collect(&:to_i)
        end
      end


      def tags
        @tags ||= video_stream["tags"] || {}
      end

      def video_stream
        @video_stream ||= streams.detect { |stream| stream["codec_type"] == "video" } || {}
      end

      def streams
        probe["streams"] || []
      end

      def probe
        download_blob_to_tempfile { |file| probe_from(file) }
      end

      def probe_from(file)
        IO.popen([ ffprobe_path, "-print_format", "json", "-show_streams", "-v", "error", file.path ]) do |output|
          JSON.parse(output.read)
        end
      rescue Errno::ENOENT
        logger.info "Skipping video analysis because ffmpeg isn't installed"
        {}
      end
  end
end
