require 'abstract_unit'
require 'fixtures/binary'

class BinaryTest < Test::Unit::TestCase
  def setup
    @data = create_data_fixture
  end
  
  def test_load_save
    # Without using prepared statements, it makes no sense to test
    # BLOB data with SQL Server, because the length of a statement is
    # limited to 8KB.
    if ActiveRecord::ConnectionAdapters.const_defined? :SQLServerAdapter
      return true if ActiveRecord::Base.connection.instance_of?(ActiveRecord::ConnectionAdapters::SQLServerAdapter)
    end

    # Without using prepared statements, it makes no sense to test
    # BLOB data with DB2, because the length of a statement is
    # limited to 32KB.
    if ActiveRecord::ConnectionAdapters.const_defined? :DB2Adapter
      return true if ActiveRecord::Base.connection.instance_of?(ActiveRecord::ConnectionAdapters::DB2Adapter)
    end

    if ActiveRecord::ConnectionAdapters.const_defined? :OracleAdapter
      return true if ActiveRecord::Base.connection.instance_of?(ActiveRecord::ConnectionAdapters::OracleAdapter)
    end
    bin = Binary.new
    bin.data = @data

    assert bin.data == @data,
      "Assigned data differs from file data"
        
    bin.save

    assert bin.data == @data,
      "Assigned data differs from file data after save"

    db_bin = Binary.find(bin.id)

    assert db_bin.data == bin.data,
      "Loaded binary data differs from memory version"
    
    assert db_bin.data == File.new(File.dirname(__FILE__)+"/fixtures/associations.png","rb").read, 
      "Loaded binary data differs from file version"
  end
  
  private
  
  def create_data_fixture
    Binary.connection.execute("DELETE FROM binaries")
    File.new(File.dirname(__FILE__)+"/fixtures/associations.png","rb").read
  end
  
end
