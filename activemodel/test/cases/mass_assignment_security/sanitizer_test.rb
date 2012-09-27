require "cases/helper"
require 'active_support/logger'

class SanitizerTest < ActiveModel::TestCase
  attr_accessor :logger

  class Authorizer < ActiveModel::MassAssignmentSecurity::PermissionSet
    def deny?(key)
      ['admin', 'id'].include?(key)
    end
  end

  def setup
    @logger_sanitizer = ActiveModel::MassAssignmentSecurity::LoggerSanitizer.new(self)
    @strict_sanitizer = ActiveModel::MassAssignmentSecurity::StrictSanitizer.new(self)
    @authorizer = Authorizer.new
  end

  test "sanitize attributes" do
    original_attributes = { 'first_name' => 'allowed', 'admin' => 'denied' }
    attributes = @logger_sanitizer.sanitize(self.class, original_attributes, @authorizer)

    assert attributes.key?('first_name'), "Allowed key shouldn't be rejected"
    assert !attributes.key?('admin'),     "Denied key should be rejected"
  end

  test "debug mass assignment removal with LoggerSanitizer" do
    original_attributes = { 'first_name' => 'allowed', 'admin' => 'denied' }
    log = StringIO.new
    self.logger = ActiveSupport::Logger.new(log)
    @logger_sanitizer.sanitize(self.class, original_attributes, @authorizer)
    assert_match(/admin/, log.string, "Should log removed attributes: #{log.string}")
  end

  test "debug mass assignment removal with StrictSanitizer" do
    original_attributes = { 'first_name' => 'allowed', 'admin' => 'denied' }
    assert_raise ActiveModel::MassAssignmentSecurity::Error do
      @strict_sanitizer.sanitize(self.class, original_attributes, @authorizer)
    end
  end

  test "mass assignment insensitive attributes" do
    original_attributes = {'id' => 1, 'first_name' => 'allowed'}

    assert_nothing_raised do
      @strict_sanitizer.sanitize(self.class, original_attributes, @authorizer)
    end
  end

end
