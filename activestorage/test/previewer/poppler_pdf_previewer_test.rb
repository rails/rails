# frozen_string_literal: true

require 'test_helper'
require 'database/setup'

require 'active_storage/previewer/poppler_pdf_previewer'

class ActiveStorage::Previewer::PopplerPDFPreviewerTest < ActiveSupport::TestCase
  setup do
    @blob = create_file_blob(filename: 'report.pdf', content_type: 'application/pdf')
  end

  test 'previewing a PDF document' do
    ActiveStorage::Previewer::PopplerPDFPreviewer.new(@blob).preview do |attachable|
      assert_equal 'image/png', attachable[:content_type]
      assert_equal 'report.png', attachable[:filename]

      image = MiniMagick::Image.read(attachable[:io])
      assert_equal 612, image.width
      assert_equal 792, image.height
    end
  end
end
