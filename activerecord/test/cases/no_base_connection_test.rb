require "cases/helper"

class IslandModels < ActiveRecord::Base
  @abstract_class = true
  establish_connection(:adapter  => "sqlite3",
                       :database => ":memory:")
end

IslandModels.connection.create_table "oceans", :force => true do |t|
  t.string     "name"
end
IslandModels.connection.create_table "swells", :force => true do |t|
  t.references :ocean
  t.string     "size", "direction"
end

class Ocean < IslandModels
  has_many :swells, :dependent => :destroy
end
class Swell < IslandModels
  belongs_to :ocean
end

class NoBaseConnectionTest < ActiveRecord::TestCase

  def setup
    @old_val = ActiveRecord::Base.connection_handler.connection_pools["ActiveRecord::Base"]
    ActiveRecord::Base.connection_handler.connection_pools.delete("ActiveRecord::Base")
  end
  def teardown
    ActiveRecord::Base.connection_handler.connection_pools["ActiveRecord::Base"] = @old_val
  end

  def test_creation_doesnt_neeed_base_connection
    pool_keys_before = ActiveRecord::Base.connection_handler.connection_pools.keys
    ocean = Ocean.create(:name => "Pacific")
    ocean.swells.create(:size => "big", :direction => "south")
    pool_keys_after = ActiveRecord::Base.connection_handler.connection_pools.keys
    assert_equal pool_keys_before, pool_keys_after
  end

end
