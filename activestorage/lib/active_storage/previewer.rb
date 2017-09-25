# frozen_string_literal: true

module ActiveStorage
  class Previewer
    attr_reader :blob

    def self.accept?(blob)
      false
    end

    def initialize(blob)
      @blob = blob
    end

    def preview
      raise NotImplementedError
    end

    private
      def open
        Tempfile.open("input") do |file|
          download_to file
          yield file
        end
      end

      def download_to(file)
        file.binmode
        blob.download { |chunk| file.write(chunk) }
        file.rewind
      end


      def draw(*argv)
        Tempfile.open("output") do |file|
          capture *argv, to: file
          yield file
        end
      end

      def capture(*argv, to:)
        to.binmode

        IO.popen(argv) do |out|
          IO.copy_stream(out, to)
        end

        to.rewind
      end
  end
end

require "active_storage/previewer/pdf_previewer"
require "active_storage/previewer/video_previewer"
