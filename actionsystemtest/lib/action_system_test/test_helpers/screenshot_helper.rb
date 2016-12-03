module ActionSystemTest
  module TestHelpers
    # Screenshot helper for system testing
    module ScreenshotHelper
      # Takes a screenshot of the current page in the browser.
      #
      # +take_screenshot+ can be used within your tests at points
      # you want to take a screenshot if the driver supports screenshots. The
      # Rack Test driver does not support screenshots.
      #
      # You can check if the driver supports screenshots by running
      #
      #   ActionSystemTest.driver.supports_screenshots?
      #   => true
      def take_screenshot
        save_image
        puts "[Screenshot]: #{image_path}"
        puts display_image
      end

      # Takes a screenshot of the current page in the browser if the test
      # failed.
      #
      # +take_screenshot+ is included in <tt>system_test_helper.rb</tt> that is
      # generated with the application. To take screenshots when a test fails
      # add +take_failed_screenshot+ to the teardown block before clearing any
      # sessions.
      def take_failed_screenshot
        take_screenshot unless passed?
      end

      private
        def image_path
          "tmp/screenshots/failures_#{method_name}.png"
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
    end
  end
end
