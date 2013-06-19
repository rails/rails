require "cases/helper"
require "models/bird"

class TestAdapterWithInvalidConnection < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    @spec = ActiveRecord::Base.connection_config
    non_existing_spec = {adapter: @spec[:adapter], database: "i_do_not_exist"}
    ActiveRecord::Base.establish_connection(non_existing_spec)
  end

  def teardown
    ActiveRecord::Base.establish_connection(@spec)
  end

  test "inspect on Model class does not raise" do
    assert_equal "Bird(no database connection)", Bird.inspect
  end
end
