module ActiveSupport
  class TestCase < Test::Unit::TestCase
    include ActiveSupport::Testing::Default
  end
end