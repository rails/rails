module Rails
  class SystemTestCase < ActiveSupport::TestCase
    include Rails.application.routes.url_helpers
  end
end
