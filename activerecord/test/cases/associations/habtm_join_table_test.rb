require 'cases/helper'

class MyReader < ActiveRecord::Base
  has_and_belongs_to_many :my_books
end

class MyBook < ActiveRecord::Base
  has_and_belongs_to_many :my_readers
end

class HabtmJoinTableTest < ActiveRecord::TestCase
  def test_habtm_join_table
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
end
