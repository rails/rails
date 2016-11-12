module ActionSystemTest
  module TestHelpers
    # Screenshot helper for system testing
    module ScreenshotHelper
      # Takes a screenshot of the current page in the browser if the system
      # test driver supports screenshots and the test failed.
      #
      # Additionally +take_screenshot+ can be used within your tests at points
      # you want to take a screenshot if the driver supports screenshots. The
      # Rack Test driver does not support screenshots.
      #
      # You can check of the driver supports screenshots by running
      #
      #   ActionSystemTest.driver.supports_screenshots?
      #   => true
      def take_screenshot
        puts "[Screenshot]: #{image_path}"
        puts find_image
      end

      def take_failed_screenshot
        take_screenshot unless passed?
      end

      private
        def image_path
          path = "tmp/screenshots/failures_#{method_name}.png"
          page.save_screenshot(Rails.root.join(path))
          path
        end

        def find_image
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
    end
  end
end
