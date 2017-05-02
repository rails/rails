require "cases/helper"

class MysqlConnectionTest < ActiveRecord::TestCase
  class Klass < ActiveRecord::Base
  end

  def setup
    super
    @connection = ActiveRecord::Base.connection
  end

  def test_partitioned_tables
    # create a partitioned table
    @connection.exec_query('drop table if exists topic')
    @connection.exec_query(<<-eosql)
      CREATE TABLE `topic` (`id` int(11) DEFAULT NULL auto_increment PRIMARY KEY,
        `title` varchar(255), `content` varchar(255)) 
      PARTITION BY RANGE (id) (  
      PARTITION p0 VALUES LESS THAN (6),  
      PARTITION p1 VALUES LESS THAN (12),  
      PARTITION p2 VALUES LESS THAN (18),  
      PARTITION p3 VALUES LESS THAN MAXVALUE)
    eosql

    # ininsert into partitioned tables test data 
    for i in 1..20 do
      sql = "INSERT INTO topic (id, title, content) VALUES (#{i}, \"#{"title_" + i.to_s}\",\"#{"content_" + i.to_s}\")"
      @connection.exec_query(sql)
    end
  
    # test whether the data is put in the right partitioned table.
    for i in 1..20 do
      sql = "explain partitions select count(*) from topic where id = #{i}"
      result = @connection.exec_query(sql)
      assert_equal ("p" + (i/6).to_s), result.rows[0][3]
    end

  end

end
