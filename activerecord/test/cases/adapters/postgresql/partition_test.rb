# encoding: utf-8
require "cases/helper"
require 'models/guy'
require 'models/phone'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapterTest < ActiveRecord::TestCase

      def setup
        @connection = ActiveRecord::Base.connection

        @connection.exec_query('drop table if exists guys')
        @connection.exec_query('create table guys(id integer primary key, name varchar(255))')

        @connection.exec_query('drop table if exists phones')
        @connection.exec_query('create table phones(id integer primary key, manufacturer varchar(255), manufacturing_date date, guy_id integer)')
      end

      def test_create_partitioned_tables_with_has_one_and_belongs_to_relationships
        #plpgsql of creating partitioned tables in PG
        partition_plpgsql = '
        CREATE TABLE phones_date_2012 (  
             CHECK ( manufacturing_date >= DATE \'2012-01-01\' AND manufacturing_date < DATE \'2013-01-01\' )  
        ) INHERITS (phones);  
  
        CREATE TABLE phones_date_2013 (  
             CHECK ( manufacturing_date >= DATE \'2013-01-01\' AND manufacturing_date < DATE \'2014-01-01\' )  
        ) INHERITS (phones);  
  
        CREATE TABLE phones_date_2014 (  
             CHECK ( manufacturing_date >= DATE \'2014-01-01\' AND manufacturing_date < DATE \'2015-01-01\' )  
        ) INHERITS (phones);'

        #plpgsql of the trigger for partitioned tables in PG
        insert_trigger_plpgsql = '
        CREATE OR REPLACE FUNCTION phones_insert_trigger()  
        RETURNS TRIGGER AS $$   
        BEGIN   
            IF ( NEW.manufacturing_date >= DATE \'2012-01-01\' AND   
                NEW.manufacturing_date < DATE \'2013-01-01\' ) THEN   
                INSERT INTO phones_date_2012 VALUES (NEW.*);   
            ELSIF ( NEW.manufacturing_date >= DATE \'2013-01-01\' AND    
                    NEW.manufacturing_date < DATE \'2014-01-01\' ) THEN   
                INSERT INTO phones_date_2013 VALUES (NEW.*);    
            ELSIF ( NEW.manufacturing_date >= DATE \'2014-01-01\' AND    
                    NEW.manufacturing_date < DATE \'2015-01-01\' ) THEN    
                INSERT INTO phones_date_2014 VALUES (NEW.*);    
            ELSE   
                RAISE EXCEPTION \'Date out of range.  Fix the phone_insert_trigger() function!\';   
            END IF;   
            RETURN NULL;   
        END;   
        $$    
        LANGUAGE plpgsql;'

        #this plpgsql tells PG to use the trigger above instead of the orignal one created by PG
        before_insert_plpgsql = '
        CREATE TRIGGER insert_phones_trigger   
        BEFORE INSERT ON phones    
        FOR EACH ROW EXECUTE PROCEDURE phones_insert_trigger();' 

        @connection.exec_query(partition_plpgsql)
        @connection.exec_query(insert_trigger_plpgsql)
        @connection.exec_query(before_insert_plpgsql)

        #Test whether the tables created existed
        assert_equal true, @connection.table_exists?('phones_date_2012')
        assert_equal true, @connection.table_exists?('phones_date_2013')
        assert_equal true, @connection.table_exists?('phones_date_2014')
        
        #example data
        g0 = Guy.create(:id => 0, :name => "Jacob0")
        g1 = Guy.create(:id => 1, :name => "Jacob1")
        g2 = Guy.create(:id => 2, :name => "Jacob2")
        g3 = Guy.create(:id => 3, :name => "Jacob3")
        g4 = Guy.create(:id => 4, :name => "Jacob4") 
  
        p0 = Phone.create(:id => 0, :manufacturer => "Nokia", :manufacturing_date => Date.new(2012, 12, 8), :guy_id => 2)
        p1 = Phone.create(:id => 1, :manufacturer => "Sumsang", :manufacturing_date => Date.new(2013, 2, 8), :guy_id => 2)
        p2 = Phone.create(:id => 2, :manufacturer => "Apple", :manufacturing_date => Date.new(2014, 12, 8), :guy_id => 4)
        p3 = Phone.create(:id => 3, :manufacturer => "LG", :manufacturing_date => Date.new(2014, 1, 8), :guy_id => 4)
        p3 = Phone.create(:id => 4, :manufacturer => "HTC", :manufacturing_date => Date.new(2012, 1, 8), :guy_id => 1)
        p5 = Phone.create(:id => 5, :manufacturer => "Sony", :manufacturing_date => Date.new(2013, 11, 8), :guy_id => 4)

        #test whether the data is put into the right partitioned table & whether the data is correct
        result = @connection.exec_query('select * from phones_date_2014')
        assert_equal result.rows[0], (["2", "Apple", "2014-12-08", "4"])
        assert_equal result.rows[1], (["3", "LG", "2014-01-08", "4"])
        result = @connection.exec_query('select * from phones_date_2013')
        assert_equal result.rows[0], (["1", "Sumsang", "2013-02-08", "2"])
        assert_equal result.rows[1], (["5", "Sony", "2013-11-08", "4"])
        result = @connection.exec_query('select * from phones_date_2012')
        assert_equal result.rows[0], (["0", "Nokia", "2012-12-08", "2"])
        assert_equal result.rows[1], (["4", "HTC", "2012-01-08", "1"])

        #Test whether related data in different partitioned tables is deleted due to the action 'destroy'
        g2.destroy
    
        assert_raise(ActiveRecord::RecordNotFound) { Guy.find(2) } 
        assert_raise(ActiveRecord::RecordNotFound) { Phone.find(0) }
        assert_raise(ActiveRecord::RecordNotFound) { Phone.find(1) }
        #or
        assert_equal nil, @connection.exec_query('select * from phones_date_2012 where id = 0').rows[0]
        assert_equal nil, @connection.exec_query('select * from phones_date_2013 where id = 1').rows[0]

        g4.destroy
        assert_raise(ActiveRecord::RecordNotFound) { Guy.find(4) } 
        assert_raise(ActiveRecord::RecordNotFound) { Phone.find(2) }
        assert_raise(ActiveRecord::RecordNotFound) { Phone.find(3) }
        assert_raise(ActiveRecord::RecordNotFound) { Phone.find(5) }
        #or
        assert_equal nil, @connection.exec_query('select * from phones_date_2014 where id = 2').rows[0]
        assert_equal nil, @connection.exec_query('select * from phones_date_2014 where id = 3').rows[0] 
        assert_equal nil, @connection.exec_query('select * from phones_date_2013 where id = 5').rows[0]        
        
        #assert_nothing_raised do
        #Phone.find(2)
        #end
      end

    end
  end
end






