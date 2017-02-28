module ActionDispatch
  module SystemTesting
    module TestHelpers
      # Screenshot helper for system testing
      module ScreenshotHelper
        # Takes a screenshot of the current page in the browser.
        #
        # +take_screenshot+ can be used at any point in your system tests to take
        # a screenshot of the current state. This can be useful for debugging or
        # automating visual testing.
        def take_screenshot
          save_image
          puts "[Screenshot]: #{image_path}"
          puts display_image
        end

        # Takes a screenshot of the current page in the browser if the test
        # failed.
        #
        # +take_failed_screenshot+ is included in <tt>application_system_test_case.rb</tt>
        # that is generated with the application. To take screenshots when a test
        # fails add +take_failed_screenshot+ to the teardown block before clearing
        # sessions.
        def take_failed_screenshot
          take_screenshot if failed? && supports_screenshot?
        end

        private
          def image_name
            failed? ? "failures_#{method_name}" : method_name
          end

          def image_path
            "tmp/screenshots/#{image_name}.png"
          end

          def save_image
            page.save_screenshot(Rails.root.join(image_path))
          end

          def display_image
            if ENV["CAPYBARA_INLINE_SCREENSHOT"] == "artifact"
              "\e]1338;url=artifact://#{image_path}\a"
            else
              name = inline_base64(File.basename(image_path))
              image = inline_base64(File.read(image_path))
              "\e]1337;File=name=#{name};height=400px;inline=1:#{image}\a"
            end
          end

          def inline_base64(path)
            Base64.encode64(path).gsub("\n", "")
          end

          def failed?
            !passed? && !skipped?
          end

          def supports_screenshot?
            page.driver.public_methods(false).include?(:save_screenshot)
          end
      end
    end
  end
end
