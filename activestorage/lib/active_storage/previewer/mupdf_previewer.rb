# frozen_string_literal: true

module ActiveStorage
  class Previewer::MuPDFPreviewer < Previewer
    class << self
      def accept?(blob)
        blob.content_type == "application/pdf" && mutool_exists?
      end

      def mutool_path
        ActiveStorage.paths[:mutool] || "mutool"
      end

      def mutool_exists?
        return @mutool_exists if defined?(@mutool_exists) && !@mutool_exists.nil?

        system mutool_path, out: File::NULL, err: File::NULL

        @mutool_exists = $?.exitstatus == 1
      end
    end

    def preview(**options)
      download_blob_to_tempfile do |input|
        draw_first_page_from input do |output|
          yield io: output, filename: "#{blob.filename.base}.png", content_type: "image/png", **options
        end
      end
    end

    private
      def draw_first_page_from(file, &block)
        draw self.class.mutool_path, "draw", "-F", "png", "-o", "-", file.path, "1", &block
      end
  end
end
