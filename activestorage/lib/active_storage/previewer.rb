# frozen_string_literal: true

module ActiveStorage
  # This is an abstract base class for previewers, which generate images from blobs. See
  # ActiveStorage::Previewer::PDFPreviewer and ActiveStorage::Previewer::VideoPreviewer for examples of
  # concrete subclasses.
  class Previewer
    attr_reader :blob

    # Implement this method in a concrete subclass. Have it return true when given a blob from which
    # the previewer can generate an image.
    def self.accept?(blob)
      false
    end

    def initialize(blob)
      @blob = blob
    end

    # Override this method in a concrete subclass. Have it yield an attachable preview image (i.e.
    # anything accepted by ActiveStorage::Attached::One#attach).
    def preview
      raise NotImplementedError
    end

    private
      # Downloads the blob to a new tempfile. Yields the tempfile.
      #
      # Use this method to get a tempfile that you can provide to a drawing command.
      def open # :doc:
        Tempfile.open("input") do |file|
          download_blob_to file
          yield file
        end
      end

      def download_blob_to(file)
        file.binmode
        blob.download { |chunk| file.write(chunk) }
        file.rewind
      end


      # Executes a system command, capturing its binary output in a tempfile. Yields the tempfile.
      #
      # Use this method to shell out to system libraries (e.g. mupdf or ffmpeg) for preview image
      # generation. The resulting tempfile can be used as the +:io+ value in an attachable Hash:
      #
      #   def preview
      #     open do |input|
      #       draw "my-drawing-command", input.path, "--format", "png", "-" do |output|
      #         yield io: output, filename: "#{blob.filename.base}.png", content_type: "image/png"
      #       end
      #     end
      #   end
      def draw(*argv) # :doc:
        Tempfile.open("output") do |file|
          capture(*argv, to: file)
          yield file
        end
      end

      def capture(*argv, to:)
        to.binmode
        IO.popen(argv) { |out| IO.copy_stream(out, to) }
        to.rewind
      end
  end
end
