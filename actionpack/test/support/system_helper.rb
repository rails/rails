# frozen_string_literal: true

class DrivenByRackTest < ActionDispatch::SystemTestCase
  driven_by :rack_test
end

class DrivenBySeleniumWithChrome < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :chrome
end

class DrivenBySeleniumWithHeadlessChrome < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome
end

class DrivenBySeleniumWithHeadlessFirefox < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_firefox
end
