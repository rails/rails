# frozen_string_literal: true

require "active_storage/downloading"

module ActiveStorage
  # This is an abstract base class for previewers, which generate images from blobs. See
  # ActiveStorage::Previewer::MuPDFPreviewer and ActiveStorage::Previewer::VideoPreviewer for
  # examples of concrete subclasses.
  class Previewer
    include Downloading

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
      # Executes a system command, capturing its binary output in a tempfile. Yields the tempfile.
      #
      # Use this method to shell out to a system library (e.g. mupdf or ffmpeg) for preview image
      # generation. The resulting tempfile can be used as the +:io+ value in an attachable Hash:
      #
      #   def preview
      #     download_blob_to_tempfile do |input|
      #       draw "my-drawing-command", input.path, "--format", "png", "-" do |output|
      #         yield io: output, filename: "#{blob.filename.base}.png", content_type: "image/png"
      #       end
      #     end
      #   end
      #
      # The output tempfile is opened in the directory returned by ActiveStorage::Downloading#tempdir.
      def draw(*argv) #:doc:
        ActiveSupport::Notifications.instrument("preview.active_storage") do
          open_tempfile_for_drawing do |file|
            capture(*argv, to: file)
            yield file
          end
        end
      end

      def open_tempfile_for_drawing
        tempfile = Tempfile.open("ActiveStorage", tempdir)

        begin
          yield tempfile
        ensure
          tempfile.close!
        end
      end

      def capture(*argv, to:)
        to.binmode
        IO.popen(argv, err: File::NULL) { |out| IO.copy_stream(out, to) }
        to.rewind
      end

      def logger #:doc:
        ActiveStorage.logger
      end
  end
end
