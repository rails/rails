path_to_ar = File.dirname(__FILE__) + '/../../../activerecord'

if Object.const_defined?("ActiveRecord") || File.exist?(path_to_ar)
# This test is very different than the others.  It requires ActiveRecord to 
# run.  There's a bunch of stuff we are assuming here:
#
# 1.  activerecord exists as a sibling directory to actionpack
#     (i.e., actionpack/../activerecord)
# 2.  you've created the appropriate database to run the active_record unit tests
# 3.  you set the appropriate database connection below

driver_to_use = 'native_sqlite'

$: << path_to_ar + '/lib/'
$: << path_to_ar + '/test/'
require 'active_record' unless Object.const_defined?("ActiveRecord")
require "connections/#{driver_to_use}/connection"
require 'fixtures/company'

# -----------------------------------------------------------------------------

# add some validation rules to trip up the assertions
class Company
  protected
    def validate
      errors.add_on_empty('name')
      errors.add('rating', 'rating should not be 2') if rating == 2
      errors.add_to_base('oh oh') if rating == 3
    end  
end

# -----------------------------------------------------------------------------

require File.dirname(__FILE__) + '/../abstract_unit'

# a controller class to handle the AR assertions
class ActiveRecordAssertionsController < ActionController::Base
  # fail with 1 bad column
  def nasty_columns_1
    @company = Company.new
    @company.name = "B"
    @company.rating = 2
    render_text "snicker...."
  end
  
  # fail with 2 bad column
  def nasty_columns_2
    @company = Company.new
    @company.name = ""
    @company.rating = 2
    render_text "double snicker...."
  end
  
  # this will pass validation
  def good_company
    @company = Company.new
    @company.name = "A"
    @company.rating = 69
    render_text "Goodness Gracious!"
  end
  
  # this will fail validation
  def bad_company
    @company = Company.new 
    render_text "Who's Bad?"
  end
  
  # the safety dance......
  def rescue_action(e) raise; end
end

# -----------------------------------------------------------------------------

ActiveRecordAssertionsController.template_root = File.dirname(__FILE__) + "/../fixtures/"

# The test case to try the AR assertions
class ActiveRecordAssertionsControllerTest < Test::Unit::TestCase
  # set it up
  def setup
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    @controller = ActiveRecordAssertionsController.new
  end

  # test for 1 bad apple column
  def test_some_invalid_columns
    process :nasty_columns_1
    assert_success
    assert_invalid_record 'company'
    assert_invalid_column_on_record 'company', 'rating'
    assert_valid_column_on_record 'company', 'name'
    assert_valid_column_on_record 'company', ['name','id']
  end

  # test for 2 bad apples columns
  def test_all_invalid_columns
    process :nasty_columns_2
    assert_success
    assert_invalid_record 'company'
    assert_invalid_column_on_record 'company', 'rating'
    assert_invalid_column_on_record 'company', 'name'
    assert_invalid_column_on_record 'company', ['name','rating']
  end

  # ensure we have no problems with an ActiveRecord
  def test_valid_record
    process :good_company
    assert_success
    assert_valid_record 'company'
  end
 
  # ensure we have problems with an ActiveRecord
  def test_invalid_record
    process :bad_company
    assert_success
    assert_invalid_record 'company'
  end
end 

end