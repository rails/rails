require "cases/helper"
require 'logger'

class SanitizerTest < ActiveModel::TestCase

  class SanitizingAuthorizer
    include ActiveModel::MassAssignmentSecurity::Sanitizer

    attr_accessor :logger

    def deny?(key)
       [ 'admin' ].include?(key)
    end

  end

  def setup
    @sanitizer = SanitizingAuthorizer.new
  end

  test "sanitize attributes" do
    original_attributes = { 'first_name' => 'allowed', 'admin' => 'denied' }
    attributes = @sanitizer.sanitize(original_attributes)

    assert attributes.key?('first_name'), "Allowed key shouldn't be rejected"
    assert !attributes.key?('admin'),     "Denied key should be rejected"
  end

  test "debug mass assignment removal" do
    original_attributes = { 'first_name' => 'allowed', 'admin' => 'denied' }
    log = StringIO.new
    @sanitizer.logger = Logger.new(log)
    @sanitizer.sanitize(original_attributes)
    assert_match(/admin/, log.string, "Should log removed attributes: #{log.string}")
  end

end
