# frozen_string_literal: true

module ActiveStorage
  class Previewer::VideoPreviewer < Previewer
    def self.accept?(blob)
      blob.video?
    end

    def preview
      open do |input|
        draw "ffmpeg", "-i", input.path, "-y", "-vcodec", "png", "-vf", "thumbnail", "-vframes", "1", "-f", "image2", "-" do |output|
          yield io: output, filename: "#{blob.filename.base}.png", content_type: "image/png"
        end
      end
    end
  end
end
