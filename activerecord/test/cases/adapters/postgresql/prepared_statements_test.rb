require "cases/helper"
require "models/computer"
require "models/developer"

class PreparedStatementsTest < ActiveRecord::PostgreSQLTestCase
  fixtures :developers

  def setup
    @conn = ActiveRecord::Base.establish_connection :arunit_with_prepared_statements
  end

  def teardown
    @conn.release_connection
    ActiveRecord::Base.establish_connection :arunit
  end

  def test_nothing_raised_with_falsy_prepared_statements
    assert_nothing_raised do
      Developer.where(id: 1).to_a
    end
  end
end
