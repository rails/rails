require 'abstract_unit'

module StringInquirerTest
  class LooseStringInquirer < ActiveSupport::TestCase
    def setup
      @string_inquirer = ActiveSupport::StringInquirer.new('production')
    end

    def test_match
      assert @string_inquirer.production?
    end

    def test_miss
      assert_not @string_inquirer.development?
    end

    def test_missing_question_mark
      assert_raise(NoMethodError) { @string_inquirer.production }
    end

    def test_respond_to
      assert_respond_to @string_inquirer, :development?
    end
  end

  class RestrictStringInquirer < ActiveSupport::TestCase
    def setup
      valid_environments = ['production', 'staging', 'development']
      @string_inquirer = ActiveSupport::StringInquirer.new('production', restricted_to: valid_environments)
    end

    def test_match
      assert @string_inquirer.production?
    end

    def test_miss
      assert_not @string_inquirer.development?
    end

    def test_invalid_environment
      assert_raise(NoMethodError) { @string_inquirer.qa? }
    end
  end
end
