# frozen_string_literal: true

require "test_helper"
require "database/setup"

require "active_storage/previewer/text_previewer"

class ActiveStorage::Previewer::TextPreviewerTest < ActiveSupport::TestCase
  setup do
    @blob = create_file_blob(filename: "code.js", content_type: "text/javascript")
  end

  test "previewing a text file" do
    ActiveStorage::Previewer::TextPreviewer.new(@blob).preview do |attachable|
      assert_equal "image/png", attachable[:content_type]
      assert_equal "code.png", attachable[:filename]

      image = MiniMagick::Image.read(attachable[:io])
      assert_equal 300, image.width
      assert_equal 300, image.height
    end
  end
end
