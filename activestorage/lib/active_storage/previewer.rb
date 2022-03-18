# frozen_string_literal: true

module ActiveStorage
  # This is an abstract base class for previewers, which generate images from blobs. See
  # ActiveStorage::Previewer::MuPDFPreviewer and ActiveStorage::Previewer::VideoPreviewer for
  # examples of concrete subclasses.
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
    # anything accepted by ActiveStorage::Attached::One#attach). Pass the additional options to
    # the underlying blob that is created.
    def preview(**options)
      raise NotImplementedError
    end

    private
      # Downloads the blob to a tempfile on disk. Yields the tempfile.
      def download_blob_to_tempfile(&block) # :doc:
        blob.open tmpdir: tmpdir, &block
      end

      # Executes a system command, capturing its binary output in a tempfile. Yields the tempfile.
      #
      # Use this method to shell out to a system library (e.g. muPDF or FFmpeg) for preview image
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
      # The output tempfile is opened in the directory returned by #tmpdir.
      def draw(*argv) # :doc:
        open_tempfile do |file|
          instrument :preview, key: blob.key do
            capture(*argv, to: file)
          end

          yield file
        end
      end

      def open_tempfile
        tempfile = Tempfile.open("ActiveStorage-", tmpdir)

        begin
          yield tempfile
        ensure
          tempfile.close!
        end
      end

      def instrument(operation, payload = {}, &block)
        ActiveSupport::Notifications.instrument "#{operation}.active_storage", payload, &block
      end

      def capture(*argv, to:)
        to.binmode

        open_tempfile do |err|
          IO.popen(argv, err: err) { |out| IO.copy_stream(out, to) }
          err.rewind

          unless $?.success?
            raise PreviewError, "#{argv.first} failed (status #{$?.exitstatus}): #{err.read.to_s.chomp}"
          end
        end

        to.rewind
      end

      def logger # :doc:
        ActiveStorage.logger
      end

      def tmpdir # :doc:
        Dir.tmpdir
      end
  end
end
