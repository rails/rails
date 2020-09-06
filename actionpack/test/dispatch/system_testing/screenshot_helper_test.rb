# frozen_string_literal: true

require 'abstract_unit'
require 'action_dispatch/system_testing/test_helpers/screenshot_helper'
require 'capybara/dsl'
require 'selenium/webdriver'

class ScreenshotHelperTest < ActiveSupport::TestCase
  def setup
    @new_test = DrivenBySeleniumWithChrome.new('x')
    @new_test.send('_screenshot_counter=', nil)
  end

  test 'image path is saved in tmp directory' do
    Rails.stub :root, Pathname.getwd do
      assert_equal Rails.root.join('tmp/screenshots/0_x.png').to_s, @new_test.send(:image_path)
    end
  end

  test 'image path unique counter is changed when incremented' do
    @new_test.send(:increment_unique)

    Rails.stub :root, Pathname.getwd do
      assert_equal Rails.root.join('tmp/screenshots/1_x.png').to_s, @new_test.send(:image_path)
    end
  end

  # To allow multiple screenshots in same test
  test 'image path unique counter generates different path in same test' do
    Rails.stub :root, Pathname.getwd do
      @new_test.send(:increment_unique)
      assert_equal Rails.root.join('tmp/screenshots/1_x.png').to_s, @new_test.send(:image_path)

      @new_test.send(:increment_unique)
      assert_equal Rails.root.join('tmp/screenshots/2_x.png').to_s, @new_test.send(:image_path)
    end
  end

  test 'image path includes failures text if test did not pass' do
    Rails.stub :root, Pathname.getwd do
      @new_test.stub :passed?, false do
        assert_equal Rails.root.join('tmp/screenshots/failures_x.png').to_s, @new_test.send(:image_path)
        assert_equal Rails.root.join('tmp/screenshots/failures_x.html').to_s, @new_test.send(:html_path)
      end
    end
  end

  test 'image path does not include failures text if test skipped' do
    Rails.stub :root, Pathname.getwd do
      @new_test.stub :passed?, false do
        @new_test.stub :skipped?, true do
          assert_equal Rails.root.join('tmp/screenshots/0_x.png').to_s, @new_test.send(:image_path)
          assert_equal Rails.root.join('tmp/screenshots/0_x.html').to_s, @new_test.send(:html_path)
        end
      end
    end
  end

  test 'image name truncates names over 225 characters including counter' do
    long_test = DrivenBySeleniumWithChrome.new('x' * 400)

    Rails.stub :root, Pathname.getwd do
      assert_equal Rails.root.join("tmp/screenshots/0_#{"x" * 223}.png").to_s, long_test.send(:image_path)
      assert_equal Rails.root.join("tmp/screenshots/0_#{"x" * 223}.html").to_s, long_test.send(:html_path)
    end
  end

  test 'defaults to simple output for the screenshot' do
    assert_equal 'simple', @new_test.send(:output_type)
  end

  test 'display_image return html path when RAILS_SYSTEM_TESTING_SCREENSHOT_HTML environment' do
    original_html_setting = ENV['RAILS_SYSTEM_TESTING_SCREENSHOT_HTML']
    ENV['RAILS_SYSTEM_TESTING_SCREENSHOT_HTML'] = '1'

    assert @new_test.send(:save_html?)

    Rails.stub :root, Pathname.getwd do
      @new_test.stub :passed?, false do
        assert_match %r|\[Screenshot HTML\].+?tmp/screenshots/failures_x\.html|, @new_test.send(:display_image)
      end
    end
  ensure
    ENV['RAILS_SYSTEM_TESTING_SCREENSHOT_HTML'] = original_html_setting
  end

  test 'display_image return artifact format when specify RAILS_SYSTEM_TESTING_SCREENSHOT environment' do
    original_output_type = ENV['RAILS_SYSTEM_TESTING_SCREENSHOT']
    ENV['RAILS_SYSTEM_TESTING_SCREENSHOT'] = 'artifact'

    assert_equal 'artifact', @new_test.send(:output_type)

    Rails.stub :root, Pathname.getwd do
      @new_test.stub :passed?, false do
        assert_match %r|url=artifact://.+?tmp/screenshots/failures_x\.png|, @new_test.send(:display_image)
      end
    end
  ensure
    ENV['RAILS_SYSTEM_TESTING_SCREENSHOT'] = original_output_type
  end

  test 'image path returns the absolute path from root' do
    Rails.stub :root, Pathname.getwd.join('..') do
      assert_equal Rails.root.join('tmp/screenshots/0_x.png').to_s, @new_test.send(:image_path)
    end
  end

  test 'slashes and backslashes are replaced with dashes in paths' do
    slash_test = DrivenBySeleniumWithChrome.new('x/y\\z')

    Rails.stub :root, Pathname.getwd do
      assert_equal Rails.root.join('tmp/screenshots/0_x-y-z.png').to_s, slash_test.send(:image_path)
      assert_equal Rails.root.join('tmp/screenshots/0_x-y-z.html').to_s, slash_test.send(:html_path)
    end
  end
end

class RackTestScreenshotsTest < DrivenByRackTest
  test 'rack_test driver does not support screenshot' do
    assert_not self.send(:supports_screenshot?)
  end
end

class SeleniumScreenshotsTest < DrivenBySeleniumWithChrome
  test 'selenium driver supports screenshot' do
    assert self.send(:supports_screenshot?)
  end
end
