# frozen_string_literal: true

module ActiveStorage
  # = Active Storage Audio \Analyzer
  #
  # Extracts duration (seconds), bit_rate (bits/s), sample_rate (hertz) and tags (internal metadata) from an audio blob.
  #
  # Example:
  #
  #   ActiveStorage::Analyzer::AudioAnalyzer.new(blob).metadata
  #   # => { duration: 5.0, bit_rate: 320340, sample_rate: 44100, tags: { encoder: "Lavc57.64", ... } }
  #
  # This analyzer requires the {FFmpeg}[https://www.ffmpeg.org] system library, which is not provided by \Rails.
  class Analyzer::AudioAnalyzer < Analyzer
    def self.accept?(blob)
      blob.audio?
    end

    def metadata
      { duration: duration, bit_rate: bit_rate, sample_rate: sample_rate, tags: tags }.compact
    end

    private
      def duration
        duration = audio_stream["duration"]
        Float(duration) if duration
      end

      def bit_rate
        bit_rate = audio_stream["bit_rate"]
        Integer(bit_rate) if bit_rate
      end

      def sample_rate
        sample_rate = audio_stream["sample_rate"]
        Integer(sample_rate) if sample_rate
      end

      def tags
        tags = audio_stream["tags"]
        Hash(tags) if tags
      end

      def audio_stream
        @audio_stream ||= streams.detect { |stream| stream["codec_type"] == "audio" } || {}
      end

      def streams
        probe["streams"] || []
      end

      def probe
        @probe ||= download_blob_to_tempfile { |file| probe_from(file) }
      end

      def probe_from(file)
        instrument(File.basename(ffprobe_path)) do
          IO.popen([ ffprobe_path,
            "-print_format", "json",
            "-show_streams",
            "-show_format",
            "-v", "error",
            file.path
          ]) do |output|
            JSON.parse(output.read)
          end
        end
      rescue Errno::ENOENT
        logger.info "Skipping audio analysis because ffprobe isn't installed"
        {}
      end

      def ffprobe_path
        ActiveStorage.paths[:ffprobe] || "ffprobe"
      end
  end
end
