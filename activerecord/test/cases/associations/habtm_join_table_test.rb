require 'cases/helper'

class MyReader < ActiveRecord::Base
  has_and_belongs_to_many :my_books
end

class MyBook < ActiveRecord::Base
  has_and_belongs_to_many :my_readers
end

class HabtmJoinTableTest < ActiveRecord::TestCase
  def setup
    ActiveRecord::Base.connection.create_table :my_books, :force => true do |t|
      t.string :name
    end
    assert ActiveRecord::Base.connection.table_exists?(:my_books)

    ActiveRecord::Base.connection.create_table :my_readers, :force => true do |t|
      t.string :name
    end
    assert ActiveRecord::Base.connection.table_exists?(:my_readers)

    ActiveRecord::Base.connection.create_table :my_books_my_readers, :force => true do |t|
      t.integer :my_book_id
      t.integer :my_reader_id
    end
    assert ActiveRecord::Base.connection.table_exists?(:my_books_my_readers)
  end

  def teardown
    ActiveRecord::Base.connection.drop_table :my_books
    ActiveRecord::Base.connection.drop_table :my_readers
    ActiveRecord::Base.connection.drop_table :my_books_my_readers
  end

  uses_transaction :test_should_raise_exception_when_join_table_has_a_primary_key
  def test_should_raise_exception_when_join_table_has_a_primary_key
    if ActiveRecord::Base.connection.supports_primary_key?
      assert_raise ActiveRecord::ConfigurationError do
        jaime = MyReader.create(:name=>"Jaime")
        jaime.my_books << MyBook.create(:name=>'Great Expectations')
      end
    end
  end

  uses_transaction :test_should_cache_result_of_primary_key_check
  def test_should_cache_result_of_primary_key_check
    if ActiveRecord::Base.connection.supports_primary_key?
      ActiveRecord::Base.connection.stubs(:primary_key).with('my_books_my_readers').returns(false).once
      weaz = MyReader.create(:name=>'Weaz')

      weaz.my_books << MyBook.create(:name=>'Great Expectations')
      weaz.my_books << MyBook.create(:name=>'Greater Expectations')
    end
  end
end
