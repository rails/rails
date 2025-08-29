# frozen_string_literal: true

require "shellwords"
module ActiveStorage
  class Previewer::AudioPreviewer < Previewer
    class << self
      def accept?(blob)
        blob.audio? && ffmpeg_exists?
      end

      def ffmpeg_exists?
        return @ffmpeg_exists if defined?(@ffmpeg_exists)

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
        draw_image_waveform_from input, options do |output|
          yield io: output, filename: "#{blob.filename.base}.jpg", content_type: "image/jpeg", **options
        end
      end
    end

    private
      def draw_image_waveform_from(file, options, &block)
        default_filter = "color=c=blue[color];aformat=channel_layouts=mono,showwavespic=s=1280x720:colors=white[wave];[color][wave]scale2ref[bg][fg];[bg][fg]overlay=format=auto"
        filter_options = options[:filter_options] || default_filter
        draw self.class.ffmpeg_path, "-i", file.path, *Shellwords.split("-filter_complex \"#{filter_options}\" -frames:v 1 -f image2"), "-", &block
      end
  end
end
