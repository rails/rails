require "#{File.dirname(__FILE__)}/../active_record_unit"

class ActiveRecordAssertionsController < ActionController::Base
  self.template_root = "#{File.dirname(__FILE__)}/../fixtures/"

  # fail with 1 bad column
  def nasty_columns_1
    @company = Company.new
    @company.name = "B"
    @company.rating = 2
    render :inline => "snicker...."
  end

  # fail with 2 bad columns
  def nasty_columns_2
    @company = Company.new
    @company.name = ""
    @company.rating = 2
    render :inline => "double snicker...."
  end

  # this will pass validation
  def good_company
    @company = Company.new
    @company.name = "A"
    @company.rating = 69
    render :inline => "Goodness Gracious!"
  end

  # this will fail validation
  def bad_company
    @company = Company.new 
    render :inline => "Who's Bad?"
  end

  # the safety dance......
  def rescue_action(e) raise; end
end

class ActiveRecordAssertionsControllerTest < ActiveRecordTestCase
  fixtures :companies

  def setup
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    @controller = ActiveRecordAssertionsController.new
    super
  end

  # test for 1 bad apple column
  def test_some_invalid_columns
    process :nasty_columns_1
    assert_response :success

    assert_deprecated_assertion { assert_invalid_record 'company' }
    assert_deprecated_assertion { assert_invalid_column_on_record 'company', 'rating' }
    assert_deprecated_assertion { assert_valid_column_on_record 'company', 'name' }
    assert_deprecated_assertion { assert_valid_column_on_record 'company', %w(name id) }
  end

  # test for 2 bad apples columns
  def test_all_invalid_columns
    process :nasty_columns_2
    assert_response :success

    assert_deprecated_assertion { assert_invalid_record 'company' }
    assert_deprecated_assertion { assert_invalid_column_on_record 'company', 'rating' }
    assert_deprecated_assertion { assert_invalid_column_on_record 'company', 'name' }
    assert_deprecated_assertion { assert_invalid_column_on_record 'company', %w(name rating) }
  end

  # ensure we have no problems with an ActiveRecord
  def test_valid_record
    process :good_company
    assert_response :success

    assert_deprecated_assertion { assert_valid_record 'company' }
  end

  # ensure we have problems with an ActiveRecord
  def test_invalid_record
    process :bad_company
    assert_response :success

    assert_deprecated_assertion { assert_invalid_record 'company' }
  end

  protected
    def assert_deprecated_assertion(message = nil, &block)
      assert_deprecated(/assert_.*from test_/, &block)
    end
end
