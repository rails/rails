require 'test/unit'

# Must set before requiring generator libs.
if defined?(RAILS_ROOT)
  RAILS_ROOT.replace "#{File.dirname(__FILE__)}/fixtures"
else
  RAILS_ROOT = "#{File.dirname(__FILE__)}/fixtures"
end

$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"

require 'initializer'

# Mocks out the configuration
module Rails
  def self.configuration
    Rails::Configuration.new
  end
end

require 'rails_generator'
require 'rails_generator/secret_key_generator'
require 'rails_generator/generators/applications/app/app_generator'

class SecretKeyGenerationTest < Test::Unit::TestCase
  SECRET_KEY_MIN_LENGTH = 128
  APP_NAME = "foo"

  def setup
    @generator = Rails::SecretKeyGenerator.new(APP_NAME)
  end

  def test_secret_key_generation
    assert_deprecated /ActiveSupport::SecureRandom\.hex\(64\)/ do
      assert @generator.generate_secret.length >= SECRET_KEY_MIN_LENGTH
    end
  end
end
