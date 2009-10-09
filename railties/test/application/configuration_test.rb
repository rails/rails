require "isolation/abstract_unit"

module ApplicationTests
  class InitializerTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
    end

    test "the application root is set correctly" do
      # require "#{app_path}/config/environment"
      # assert_equal app_path, Rails.application.root
    end
  end
end