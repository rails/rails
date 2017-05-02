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

        #execute these plpgsqls
        @connection.exec_query(partition_plpgsql)
        @connection.exec_query(insert_trigger_plpgsql)
        @connection.exec_query(before_insert_plpgsql)

        #Test whether the tables created existed
        assert_equal true, @connection.table_exists?('phones_date_2012')
        assert_equal true, @connection.table_exists?('phones_date_2013')
        assert_equal true, @connection.table_exists?('phones_date_2014')
      end

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
        
        # Test whether it can get the three records stored in different tables by find()    
        @guy = Guy.find(4)
        assert_equal 3, @guy.phones.length
        assert_equal({'id' => 5, 'manufacturer' => 'Sony', 'manufacturing_date' => Date.new(2013, 11, 8), 'guy_id' => 4}, @guy.phones[0].attributes)
        assert_equal({'id' => 2, 'manufacturer' => 'Apple', 'manufacturing_date' => Date.new(2014, 12, 8), 'guy_id' => 4}, @guy.phones[1].attributes)
        assert_equal({'id' => 7, 'manufacturer' => 'Microsoft', 'manufacturing_date' => Date.new(2014, 12, 8), 'guy_id' => 4}, @guy.phones[2].attributes)
       
        #Test whether related data in different partitioned tables is deleted due to the action 'destroy'
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
  end
end










