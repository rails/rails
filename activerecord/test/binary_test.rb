require 'abstract_unit'
require 'fixtures/binary'

class BinaryTest < Test::Unit::TestCase
  BINARY_FIXTURE_PATH = File.dirname(__FILE__) + '/fixtures/flowers.jpg'

  def setup
    Binary.connection.execute 'DELETE FROM binaries'
    @data = File.read(BINARY_FIXTURE_PATH).freeze
  end
  
  def test_truth
    assert true
  end

  # Without using prepared statements, it makes no sense to test
  # BLOB data with SQL Server, because the length of a statement is
  # limited to 8KB.
  #
  # Without using prepared statements, it makes no sense to test
  # BLOB data with DB2 or Firebird, because the length of a statement
  # is limited to 32KB.
  unless %w(SQLServer Sybase DB2 Oracle Firebird).include? ActiveRecord::Base.connection.adapter_name
    def test_load_save
      bin = Binary.new
      bin.data = @data

      assert @data == bin.data, 'Newly assigned data differs from original'
          
      bin.save
      assert @data == bin.data, 'Data differs from original after save'

      db_bin = Binary.find(bin.id)
      assert @data == db_bin.data, 'Reloaded data differs from original'
    end
  end
end
