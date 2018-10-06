# frozen_string_literal: true

require "qunit/selenium/test_runner"
require "chromedriver-helper"

driver_options = Selenium::WebDriver::Chrome::Options.new
driver_options.add_argument("--headless")
driver_options.add_argument("--disable-gpu")
driver_options.add_argument("--no-sandbox")

driver = ::Selenium::WebDriver.for(:chrome, options: driver_options)
result = QUnit::Selenium::TestRunner.new(driver).open(ARGV[0], timeout: 60)
driver.quit

puts "Time: #{result.duration} seconds, Total: #{result.assertions[:total]}, Passed: #{result.assertions[:passed]}, Failed: #{result.assertions[:failed]}"
exit(result.tests[:failed] > 0 ? 1 : 0)
