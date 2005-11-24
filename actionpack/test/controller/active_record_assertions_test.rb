require "#{File.dirname(__FILE__)}/../abstract_unit"

# Unfurl the safety net.
path_to_ar = File.dirname(__FILE__) + '/../../../activerecord'
if Object.const_defined?(:ActiveRecord) || File.exist?(path_to_ar)
  begin

# These tests require Active Record, so you're going to need AR in a
# sibling directory to AP and have SQLite installed.

unless Object.const_defined?(:ActiveRecord)
  require "#{path_to_ar}/lib/active_record"
end

begin
  ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :dbfile => ':memory:')
  ActiveRecord::Base.connection
rescue Object
  $stderr.puts 'SQLite 3 unavailable; falling to SQLite 2.'
  ActiveRecord::Base.establish_connection(:adapter => 'sqlite', :dbfile => ':memory:')
  ActiveRecord::Base.connection
end

# Set up company fixtures.
$LOAD_PATH << "#{path_to_ar}/test"
QUOTED_TYPE = ActiveRecord::Base.connection.quote_column_name('type') unless Object.const_defined?(:QUOTED_TYPE)
require 'fixtures/company'
File.read("#{path_to_ar}/test/fixtures/db_definitions/sqlite.sql").split(';').each do |sql|
  ActiveRecord::Base.connection.execute(sql) unless sql.blank?
end

# Add some validation rules to trip up the assertions.
class Company
  protected
    def validate
      errors.add_on_empty('name')
      errors.add('rating', 'rating should not be 2') if rating == 2
      errors.add_to_base('oh oh') if rating == 3
    end  
end

# A controller to host the assertions.
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
                    
class ActiveRecordAssertionsControllerTest < Test::Unit::TestCase
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
    assert_valid_column_on_record 'company', %w(name id)
  end

  # test for 2 bad apples columns
  def test_all_invalid_columns
    process :nasty_columns_2
    assert_success
    assert_invalid_record 'company'
    assert_invalid_column_on_record 'company', 'rating'
    assert_invalid_column_on_record 'company', 'name'
    assert_invalid_column_on_record 'company', %w(name rating)
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

# End of safety net.
  rescue Object => e
    $stderr.puts "Skipping Active Record assertion tests: #{e}"
    #$stderr.puts "  #{e.backtrace.join("\n  ")}"
  end
end
