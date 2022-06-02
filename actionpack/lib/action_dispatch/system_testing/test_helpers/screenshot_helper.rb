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
        # automating visual testing. You can take multiple screenshots per test
        # to investigate changes at different points during your test. These will be
        # named with a sequential prefix (or 'failed' for failing tests)
        #
        # The default screenshots directory is +tmp/screenshots+ but you can set a different
        # one with +Capybara.save_path+
        #
        # You can use the +html+ argument or set the +RAILS_SYSTEM_TESTING_SCREENSHOT_HTML+
        # environment variable to save the HTML from the page that is being screenshotted
        # so you can investigate the elements on the page at the time of the screenshot
        #
        # You can use the +screenshot+ argument or set the +RAILS_SYSTEM_TESTING_SCREENSHOT+
        # environment variable to control the output. Possible values are:
        # * [+simple+ (default)]    Only displays the screenshot path.
        #                           This is the default value.
        # * [+inline+]              Display the screenshot in the terminal using the
        #                           iTerm image protocol (https://iterm2.com/documentation-images.html).
        # * [+artifact+]            Display the screenshot in the terminal, using the terminal
        #                           artifact format (https://buildkite.github.io/terminal-to-html/inline-images/).
        def take_screenshot(html: false, screenshot: nil)
          showing_html = html || html_from_env?

          increment_unique
          save_html if showing_html
          save_image
          show display_image(html: showing_html, screenshot_output: screenshot)
        end

        # Takes a screenshot of the current page in the browser if the test
        # failed.
        #
        # +take_failed_screenshot+ is called during system test teardown.
        def take_failed_screenshot
          take_screenshot if failed? && supports_screenshot? && Capybara::Session.instance_created?
        end

        private
          attr_accessor :_screenshot_counter

          def html_from_env?
            ENV["RAILS_SYSTEM_TESTING_SCREENSHOT_HTML"] == "1"
          end

          def increment_unique
            @_screenshot_counter ||= 0
            @_screenshot_counter += 1
          end

          def unique
            failed? ? "failures" : (_screenshot_counter || 0).to_s
          end

          def image_name
            sanitized_method_name = method_name.tr("/\\", "--")
            name = "#{unique}_#{sanitized_method_name}"
            name[0...225]
          end

          def image_path
            absolute_image_path.to_s
          end

          def html_path
            absolute_html_path.to_s
          end

          def absolute_path
            Rails.root.join(screenshots_dir, image_name)
          end

          def screenshots_dir
            Capybara.save_path.presence || "tmp/screenshots"
          end

          def absolute_image_path
            "#{absolute_path}.png"
          end

          def absolute_html_path
            "#{absolute_path}.html"
          end

          def save_html
            page.save_page(absolute_html_path)
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

          def show(img)
            puts img
          end

          def display_image(html:, screenshot_output:)
            message = +"[Screenshot Image]: #{image_path}\n"
            message << +"[Screenshot HTML]: #{html_path}\n" if html

            case screenshot_output || output_type
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
            Base64.strict_encode64(path)
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
