require "abstract_unit"
require "action_dispatch/http/rack_cache"

class RackCacheMetaStoreTest < ActiveSupport::TestCase
  class ReadWriteHash < ::Hash
    alias :read  :[]
    alias :write :[]=
  end

  setup do
    @store = ActionDispatch::RailsMetaStore.new(ReadWriteHash.new)
  end

  test "stuff is deep duped" do
    @store.write(:foo, bar: :original)
    hash = @store.read(:foo)
    hash[:bar] = :changed
    hash = @store.read(:foo)
    assert_equal :original, hash[:bar]
  end
end
