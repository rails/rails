require "cases/helper"
require 'models/default'
require 'models/entrant'

class DefaultTest < ActiveRecord::TestCase
  def test_nil_defaults_for_not_null_columns
    column_defaults =
      if current_adapter?(:MysqlAdapter) && (Mysql.client_version < 50051 || (50100..50122).include?(Mysql.client_version))
        { 'id' => nil, 'name' => '',  'course_id' => nil }
      else
        { 'id' => nil, 'name' => nil, 'course_id' => nil }
      end

    column_defaults.each do |name, default|
      column = Entrant.columns_hash[name]
      assert !column.null, "#{name} column should be NOT NULL"
      assert_equal default, column.default, "#{name} column should be DEFAULT #{default.inspect}"
    end
  end

  if current_adapter?(:MysqlAdapter)

    #MySQL 5 and higher is quirky with not null text/blob columns.
    #With MySQL Text/blob columns cannot have defaults. If the column is not null MySQL will report that the column has a null default
    #but it behaves as though the column had a default of ''
    def test_mysql_text_not_null_defaults
      klass = Class.new(ActiveRecord::Base)
      klass.table_name = 'test_mysql_text_not_null_defaults'
      klass.connection.create_table klass.table_name do |t|
        t.column :non_null_text, :text, :null => false
        t.column :non_null_blob, :blob, :null => false
        t.column :null_text, :text, :null => true
        t.column :null_blob, :blob, :null => true
      end
      assert_equal '', klass.columns_hash['non_null_blob'].default
      assert_equal '', klass.columns_hash['non_null_text'].default

      assert_equal nil, klass.columns_hash['null_blob'].default
      assert_equal nil, klass.columns_hash['null_text'].default

      assert_nothing_raised do
        instance = klass.create!
        assert_equal '', instance.non_null_text
        assert_equal '', instance.non_null_blob
        assert_nil instance.null_text
        assert_nil instance.null_blob
      end
    ensure
      klass.connection.drop_table(klass.table_name) rescue nil
    end


    # MySQL uses an implicit default 0 rather than NULL unless in strict mode.
    # We use an implicit NULL so schema.rb is compatible with other databases.
    def test_mysql_integer_not_null_defaults
      klass = Class.new(ActiveRecord::Base)
      klass.table_name = 'test_integer_not_null_default_zero'
      klass.connection.create_table klass.table_name do |t|
        t.column :zero, :integer, :null => false, :default => 0
        t.column :omit, :integer, :null => false
      end

      assert_equal 0, klass.columns_hash['zero'].default
      assert !klass.columns_hash['zero'].null
      # 0 in MySQL 4, nil in 5.
      assert [0, nil].include?(klass.columns_hash['omit'].default)
      assert !klass.columns_hash['omit'].null

      assert_raise(ActiveRecord::StatementInvalid) { klass.create! }

      assert_nothing_raised do
        instance = klass.create!(:omit => 1)
        assert_equal 0, instance.zero
        assert_equal 1, instance.omit
      end
    ensure
      klass.connection.drop_table(klass.table_name) rescue nil
    end
  end

  if current_adapter?(:PostgreSQLAdapter, :FirebirdAdapter, :OpenBaseAdapter, :OracleAdapter)
    def test_default_integers
      default = Default.new
      assert_instance_of Fixnum, default.positive_integer
      assert_equal 1, default.positive_integer
      assert_instance_of Fixnum, default.negative_integer
      assert_equal -1, default.negative_integer
      assert_instance_of BigDecimal, default.decimal_number
      assert_equal BigDecimal.new("2.78"), default.decimal_number
    end
  end

  if current_adapter?(:PostgreSQLAdapter)
    def test_multiline_default_text
      # older postgres versions represent the default with escapes ("\\012" for a newline)
      assert ( "--- []\n\n" == Default.columns_hash['multiline_default'].default ||
               "--- []\\012\\012" == Default.columns_hash['multiline_default'].default)
    end
  end
end
