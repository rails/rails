# frozen_string_literal: true

require "isolation/abstract_unit"
require "application/action_text_integration_test_helper"

module ApplicationTests
  class ActionTextRichTextEditorTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      @old = ENV["PARALLEL_WORKERS"]
      ENV["PARALLEL_WORKERS"] = "0"
    end

    def teardown
      ENV["PARALLEL_WORKERS"] = @old
    end

    test "attaches and uploads image file" do
      app_file "test/integration/rich_text_editor_test.rb", <<~RUBY
        require "application_system_test_case"

        class ActionText::RichTextEditorTest < ApplicationSystemTestCase
          test "attaches and uploads image file" do
            image_file = file_fixture("racecar.jpg")

            visit new_message_url

            attach_file image_file do
              click_button "Attach Files"
            end

            within :rich_text_area do
              assert_selector :element, "img", src: %r{/rails/active_storage/blobs/redirect/.*/\#{image_file.basename}\\Z}
            end
            click_button "Create Message"

            within class: "trix-content" do
              assert_selector :element, "img", src: %r{/rails/active_storage/representations/redirect/.*/\#{image_file.basename}\\Z}
            end
          end
        end
      RUBY

      assert_successful_test_run "integration/rich_text_editor_test.rb"
    end
  end
end
