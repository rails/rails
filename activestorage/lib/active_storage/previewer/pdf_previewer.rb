# frozen_string_literal: true

module ActiveStorage
  class Previewer::PDFPreviewer < Previewer
    def self.accept?(blob)
      blob.content_type == "application/pdf" &&
        mutool_exists?
    end

    def self.mutool_path
      ActiveStorage.paths[:mutool] || "mutool"
    end

    # There's no version or way to get status code 0
    # without processing a PDF. This check ensures
    # the binary exists since command not found is
    # exit code 127.
    def self.mutool_exists?
      return @mutool_exists unless @mutool_exists.nil?

      system(mutool_path)

      @mutool_exists = $?.exitstatus == 1
    end

    def preview
      download_blob_to_tempfile do |input|
        draw_first_page_from input do |output|
          yield io: output, filename: "#{blob.filename.base}.png", content_type: "image/png"
        end
      end
    end

    private
      def draw_first_page_from(file, &block)
        draw self.class.mutool_path, "draw", "-F", "png", "-o", "-", file.path, "1", &block
      end
  end
end
