# frozen_string_literal: true

module ActiveStorage
  class Previewer::PopplerPDFPreviewer < Previewer
    class << self
      def accept?(blob)
        blob.content_type == "application/pdf" && pdftoppm_exists?
      end

      def pdftoppm_path
        ActiveStorage.paths[:pdftoppm] || "pdftoppm"
      end

      def pdftoppm_exists?
        return @pdftoppm_exists unless @pdftoppm_exists.nil?

        @pdftoppm_exists = system(pdftoppm_path, "-v", out: File::NULL, err: File::NULL)
      end
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
        # use 72 dpi to match thumbnail dimensions of the PDF
        draw self.class.pdftoppm_path, "-singlefile", "-cropbox", "-r", "72", "-png", file.path, &block
      end
  end
end
