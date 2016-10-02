module SystemTesting
  module TestHelpers
    extend ActiveSupport::Autoload

    autoload :Assertions
    autoload :FormHelper
    autoload :ScreenshotHelper
  end
end
