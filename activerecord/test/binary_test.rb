require 'abstract_unit'
require 'fixtures/binary'

class BinaryTest < Test::Unit::TestCase
  def setup
    @data = create_data_fixture
  end
  
  def test_load_save
    bin = Binary.new
    bin.data = @data

    assert bin.data == @data,
      "Assigned data differs from file data"
        
    bin.save

    assert bin.data == @data,
      "Assigned data differs from file data after save"

    db_bin = Binary.find(bin.id)

    assert db_bin.data == bin.data,
      "Loaded binary data differes from memory version"
    
    assert db_bin.data == File.new(File.dirname(__FILE__)+"/fixtures/associations.png","rb").read, 
      "Loaded binary data differes from file version"
  end
  
  private
  
  def create_data_fixture
    Binary.connection.execute("DELETE FROM binaries")
    File.new(File.dirname(__FILE__)+"/fixtures/associations.png","rb").read
  end
  
end