# frozen_string_literal: true

module ActiveStorage
  # Extracts the following from a video blob:
  #
  # * Width (pixels)
  # * Height (pixels)
  # * Duration (seconds)
  # * Angle (degrees)
  # * Display aspect ratio
  #
  # Example:
  #
  #   ActiveStorage::VideoAnalyzer.new(blob).metadata
  #   # => { width: 640.0, height: 480.0, duration: 5.0, angle: 0, display_aspect_ratio: [4, 3] }
  #
  # When a video's angle is 90 or 270 degrees, its width and height are automatically swapped for convenience.
  #
  # This analyzer requires the {ffmpeg}[https://www.ffmpeg.org] system library, which is not provided by Rails.
  class Analyzer::VideoAnalyzer < Analyzer
    def self.accept?(blob)
      blob.video?
    end

    def metadata
      { width: width, height: height, duration: duration, angle: angle, display_aspect_ratio: display_aspect_ratio }.compact
    end

    private
      def width
        if rotated?
          computed_height || encoded_height
        else
          encoded_width
        end
      end

      def height
        if rotated?
          encoded_width
        else
          computed_height || encoded_height
        end
      end

      def duration
        Float(video_stream["duration"]) if video_stream["duration"]
      end

      def angle
        Integer(tags["rotate"]) if tags["rotate"]
      end

      def display_aspect_ratio
        if descriptor = video_stream["display_aspect_ratio"]
          if terms = descriptor.split(":", 2)
            numerator   = Integer(terms[0])
            denominator = Integer(terms[1])

            [numerator, denominator] unless numerator == 0
          end
        end
      end


      def rotated?
        angle == 90 || angle == 270
      end

      def computed_height
        if encoded_width && display_height_scale
          encoded_width * display_height_scale
        end
      end

      def encoded_width
        @encoded_width ||= Float(video_stream["width"]) if video_stream["width"]
      end

      def encoded_height
        @encoded_height ||= Float(video_stream["height"]) if video_stream["height"]
      end

      def display_height_scale
        @display_height_scale ||= Float(display_aspect_ratio.last) / display_aspect_ratio.first if display_aspect_ratio
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

      def ffprobe_path
        ActiveStorage.paths[:ffprobe] || "ffprobe"
      end
  end
end
