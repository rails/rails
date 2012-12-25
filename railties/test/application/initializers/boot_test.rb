require "isolation/abstract_unit"

module ApplicationTests
  class BootTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      # build_app
      # boot_rails
    end

    def teardown
      # teardown_app
    end

    test "booting rails sets the load paths correctly" do
      # This test is pending reworking the boot process
    end
  end
end
