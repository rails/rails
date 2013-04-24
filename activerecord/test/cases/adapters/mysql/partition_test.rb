require "cases/helper"
require 'models/guy'
require 'models/phone'

class MysqlConnectionTest < ActiveRecord::TestCase
  class Klass < ActiveRecord::Base
  end

  def setup
    super
    @connection = ActiveRecord::Base.connection
    @connection.exec_query('drop table if exists phones')
    @connection.exec_query(<<-eosql)
      CREATE TABLE `phones` (`id` int(11) DEFAULT NULL auto_increment PRIMARY KEY,
      `manufacturer` varchar(255), `manufacturing_date` date, guy_id int)
      PARTITION BY RANGE (id) (  
      PARTITION p0 VALUES LESS THAN (3),  
      PARTITION p1 VALUES LESS THAN (5),  
      PARTITION p2 VALUES LESS THAN (7),  
      PARTITION p3 VALUES LESS THAN MAXVALUE) 
    eosql

    @connection.exec_query('drop table if exists guys')
    @connection.exec_query(<<-eosql)
    CREATE TABLE `guys` (`id` int(11) DEFAULT NULL auto_increment PRIMARY KEY, `name` varchar(255))
    eosql
  end

  uses_transaction :test_create_partitioned_tables_with_has_one_and_belongs_to_relationships
  def test_create_partitioned_tables_with_has_one_and_belongs_to_relationships
    #example data
    g1 = Guy.create(:id => 1, :name => "Jacob1")
    g2 = Guy.create(:id => 2, :name => "Jacob2")
    g3 = Guy.create(:id => 3, :name => "Jacob3")
    g4 = Guy.create(:id => 4, :name => "Jacob4")
    g5 = Guy.create(:id => 5, :name => "Jacob5")
    g6 = Guy.create(:id => 6, :name => "Jacob6")

    p1 = Phone.create(:id => 1, :manufacturer => "Sumsang", :manufacturing_date => Date.new(2013, 2, 8), :guy_id => 2)
    p2 = Phone.create(:id => 2, :manufacturer => "Apple", :manufacturing_date => Date.new(2014, 12, 8), :guy_id => 4)
    p3 = Phone.create(:id => 3, :manufacturer => "LG", :manufacturing_date => Date.new(2014, 1, 8), :guy_id => 2)
    p3 = Phone.create(:id => 4, :manufacturer => "HTC", :manufacturing_date => Date.new(2012, 1, 8), :guy_id => 1)
    p5 = Phone.create(:id => 5, :manufacturer => "Sony", :manufacturing_date => Date.new(2013, 11, 8), :guy_id => 4)
    p6 = Phone.create(:id => 6, :manufacturer => "Firefox", :manufacturing_date => Date.new(2013, 2, 8), :guy_id => 2)
    p7 = Phone.create(:id => 7, :manufacturer => "Microsoft", :manufacturing_date => Date.new(2014, 12, 8), :guy_id => 4)
    
    @guy = Guy.find(4)
    assert_equal 3, @guy.phones.length
    assert_equal({'id' => 2, 'manufacturer' => 'Apple', 'manufacturing_date' => Date.new(2014, 12, 8), 'guy_id' => 4}, @guy.phones[0].attributes)
    assert_equal({'id' => 5, 'manufacturer' => 'Sony', 'manufacturing_date' => Date.new(2013, 11, 8), 'guy_id' => 4}, @guy.phones[1].attributes)
    assert_equal({'id' => 7, 'manufacturer' => 'Microsoft', 'manufacturing_date' => Date.new(2014, 12, 8), 'guy_id' => 4}, @guy.phones[2].attributes)

    g2.destroy   
    assert_raise(ActiveRecord::RecordNotFound) { Guy.find(2) } 
    assert_raise(ActiveRecord::RecordNotFound) { Phone.find(1) }
    assert_raise(ActiveRecord::RecordNotFound) { Phone.find(3) }
    assert_raise(ActiveRecord::RecordNotFound) { Phone.find(6) }

    g4.destroy
    assert_raise(ActiveRecord::RecordNotFound) { Guy.find(4) } 
    assert_raise(ActiveRecord::RecordNotFound) { Phone.find(2) }
    assert_raise(ActiveRecord::RecordNotFound) { Phone.find(5) }
    assert_raise(ActiveRecord::RecordNotFound) { Phone.find(7) }  
  end

end






