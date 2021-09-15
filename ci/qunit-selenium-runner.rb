# frozen_string_literal: true

require "webdrivers"
require_relative "test_run"

driver = if ARGV[1]
  ::Selenium::WebDriver.for(:remote, url: ARGV[1], desired_capabilities: :chrome)
else
  driver_options = Selenium::WebDriver::Chrome::Options.new
  driver_options.add_argument("--headless")
  driver_options.add_argument("--disable-gpu")
  driver_options.add_argument("--no-sandbox")

  ::Selenium::WebDriver.for(:chrome, options: driver_options)
end

driver.get(ARGV[0])

result = TestRun.new(driver).tap do |run|
  ::Selenium::WebDriver::Wait.new(timeout: 60).until do
    run.completed?
  end
end.result

driver.quit

puts "Time: #{result.duration} seconds, Total: #{result.assertions[:total]}, Passed: #{result.assertions[:passed]}, Failed: #{result.assertions[:failed]}"
if result.tests[:failed] > 0
  puts "Qunit output follows. Look for lines that have failures, e.g. (1, n, n) - those are your failing lines\r\n\r\n#{result.raw_output}"
end
exit(result.tests[:failed] > 0 ? 1 : 0)
