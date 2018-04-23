# frozen_string_literal: true

module ActionDispatch
  module SystemTesting
    module TestHelpers
      # Screenshot helper for system testing.
      module ScreenshotHelper
        # Takes a screenshot of the current page in the browser.
        #
        # +take_screenshot+ can be used at any point in your system tests to take
        # a screenshot of the current state. This can be useful for debugging or
        # automating visual testing.
        #
        # The screenshot will be displayed in your console, if supported.
        #
        # You can set the +RAILS_SYSTEM_TESTING_SCREENSHOT+ environment variable to
        # control the output. Possible values are:
        # * [+simple+ (default)]    Only displays the screenshot path.
        #                           This is the default value.
        # * [+inline+]              Display the screenshot in the terminal using the
        #                           iTerm image protocol (https://iterm2.com/documentation-images.html).
        # * [+artifact+]            Display the screenshot in the terminal, using the terminal
        #                           artifact format (https://buildkite.github.io/terminal/inline-images/).
        def take_screenshot
          save_image
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
            @image_path ||= absolute_image_path.to_s
          end

          def absolute_image_path
            Rails.root.join("tmp/screenshots/#{image_name}.png")
          end

          def save_image
            page.save_screenshot(absolute_image_path)
          end

          def output_type
            # Environment variables have priority
            output_type = ENV["RAILS_SYSTEM_TESTING_SCREENSHOT"] || ENV["CAPYBARA_INLINE_SCREENSHOT"]

            # Default to outputting a path to the screenshot
            output_type ||= "simple"

            output_type
          end

          def display_image
            message = "[Screenshot]: #{image_path}\n".dup

            case output_type
            when "artifact"
              message << "\e]1338;url=artifact://#{absolute_image_path}\a\n"
            when "inline"
              name = inline_base64(File.basename(absolute_image_path))
              image = inline_base64(File.read(absolute_image_path))
              message << "\e]1337;File=name=#{name};height=400px;inline=1:#{image}\a\n"
            end

            message
          end

          def inline_base64(path)
            Base64.encode64(path).delete("\n")
          end

          def failed?
            !passed? && !skipped?
          end

          def supports_screenshot?
            Capybara.current_driver != :rack_test
          end
      end
    end
  end
end
