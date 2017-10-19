require 'qunit/selenium/test_runner'
require 'chromedriver/helper'

driver_options = Selenium::WebDriver::Chrome::Options.new
driver_options.add_argument('--headless')
driver_options.add_argument('--disable-gpu')

driver = ::Selenium::WebDriver.for(:chrome, options: driver_options)
result = QUnit::Selenium::TestRunner.new(driver).open(ARGV[0], timeout: 60)
driver.quit

puts "Time: #{result.duration} seconds, Total: #{result.tests[:total]}, Passed: #{result.tests[:passed]}, Failed: #{result.tests[:failed]}"
exit(result.tests[:failed] > 0 ? 1 : 0)
