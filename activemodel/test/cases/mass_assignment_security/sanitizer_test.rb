require "cases/helper"
require 'logger'
require 'active_support/core_ext/object/inclusion'

class SanitizerTest < ActiveModel::TestCase


  class Authorizer < ActiveModel::MassAssignmentSecurity::PermissionSet
    def deny?(key)
      key.in?(['admin'])
    end
  end

  def setup
    @sanitizer = ActiveModel::MassAssignmentSecurity::DefaultSanitizer.new
    @authorizer = Authorizer.new
  end

  test "sanitize attributes" do
    original_attributes = { 'first_name' => 'allowed', 'admin' => 'denied' }
    attributes = @sanitizer.sanitize(original_attributes, @authorizer)

    assert attributes.key?('first_name'), "Allowed key shouldn't be rejected"
    assert !attributes.key?('admin'),     "Denied key should be rejected"
  end

  test "debug mass assignment removal" do
    original_attributes = { 'first_name' => 'allowed', 'admin' => 'denied' }
    log = StringIO.new
    @sanitizer.logger = Logger.new(log)
    @sanitizer.sanitize(original_attributes, @authorizer)
    assert_match(/admin/, log.string, "Should log removed attributes: #{log.string}")
  end

end
