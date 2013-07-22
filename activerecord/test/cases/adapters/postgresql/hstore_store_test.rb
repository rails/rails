require "cases/helper"

class HstoreStoreTest < ActiveRecord::TestCase

  setup do
    @connection = ActiveRecord::Base.connection

    unless @connection.supports_extensions?
      return skip "do not test on PG without hstore"
    end
  end

  class Pinky < ActiveRecord::Base
    self.table_name = 'postgresql_hstores'
    store :hash_store, accessors: [:intelligence, :charisma]
  end

  test "can save to a hstore column using 'store'" do
    pinky = Pinky.new
    pinky.intelligence = 'notsomuch'
    pinky.charisma = 'plenty'
    pinky.save!
  end

  class Brain < ActiveRecord::Base
    self.table_name = 'postgresql_hstores'
    store_accessor :hash_store, [:intelligence, :charisma]
  end

  test "can save to a hstore column using 'store_accessor'" do
    brain = Brain.new
    brain.intelligence = 'overwhelming'
    brain.charisma = 'insufficient'
    brain.save!
  end
end