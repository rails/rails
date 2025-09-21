# frozen_string_literal: true

require "test_helper"
require "rail_inspector/configuring"

class NewFrameworkDefaultsFileTest < ActiveSupport::TestCase
  def test_identifies_self_when_file_uses_config
    defaults = ["self.log_file_size"]

    check(defaults, <<~FILE).check
    ###
    # You must apply this in config/application.rb
    # config.log_file_size = 100 * 1024 * 1024
    FILE

    assert_empty checker.errors
  end

  def test_identifies_self_when_file_uses_configuration
    defaults = ["self.log_file_size"]

    check(defaults, <<~FILE).check
    ###
    # You must apply this in config/application.rb
    # Rails.configuration.log_file_size = 100 * 1024 * 1024
    FILE

    assert_empty checker.errors
  end

  private
    def check(defaults, file_content)
      @check ||= RailInspector::Configuring::Check::NewFrameworkDefaultsFile.new(checker, defaults, file_content)
    end

    def checker
      @checker ||= RailInspector::Configuring.new("../..")
    end
end
