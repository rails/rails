require 'active_support/core_ext/module/delegation'

module ActiveRecord
  module Querying
    delegate :find, :first, :first!, :last, :last!, :all, :exists?, :any?, :many?, :to => :scoped
    delegate :first_or_create, :first_or_create!, :first_or_initialize, :to => :scoped
    delegate :destroy, :destroy_all, :delete, :delete_all, :update, :update_all, :to => :scoped
    delegate :find_each, :find_in_batches, :to => :scoped
    delegate :select, :group, :order, :except, :reorder, :limit, :offset, :joins,
             :where, :preload, :eager_load, :includes, :from, :lock, :readonly,
             :having, :create_with, :uniq, :to => :scoped
    delegate :count, :average, :minimum, :maximum, :sum, :calculate, :to => :scoped

    # Executes a custom SQL query against your database and returns all the results. The results will
    # be returned as an array with columns requested encapsulated as attributes of the model you call
    # this method from. If you call <tt>Product.find_by_sql</tt> then the results will be returned in
    # a Product object with the attributes you specified in the SQL query.
    #
    # If you call a complicated SQL query which spans multiple tables the columns specified by the
    # SELECT will be attributes of the model, whether or not they are columns of the corresponding
    # table.
    #
    # The +sql+ parameter is a full SQL query as a string. It will be called as is, there will be
    # no database agnostic conversions performed. This should be a last resort because using, for example,
    # MySQL specific terms will lock you to using that particular database engine or require you to
    # change your call if you switch engines.
    #
    # ==== Examples
    #   # A simple SQL query spanning multiple tables
    #   Post.find_by_sql "SELECT p.title, c.author FROM posts p, comments c WHERE p.id = c.post_id"
    #   > [#<Post:0x36bff9c @attributes={"title"=>"Ruby Meetup", "first_name"=>"Quentin"}>, ...]
    #
    #   # You can use the same string replacement techniques as you can with ActiveRecord#find
    #   Post.find_by_sql ["SELECT title FROM posts WHERE author = ? AND created > ?", author_id, start_date]
    #   > [#<Post:0x36bff9c @attributes={"title"=>"The Cheap Man Buys Twice"}>, ...]
    def find_by_sql(sql, binds = [])
      logging_query_plan do
        connection.select_all(sanitize_sql(sql), "#{name} Load", binds).collect! { |record| instantiate(record) }
      end
    end

    # Returns the result of an SQL statement that should only include a COUNT(*) in the SELECT part.
    # The use of this method should be restricted to complicated SQL queries that can't be executed
    # using the ActiveRecord::Calculations class methods. Look into those before using this.
    #
    # ==== Parameters
    #
    # * +sql+ - An SQL statement which should return a count query from the database, see the example below.
    #
    # ==== Examples
    #
    #   Product.count_by_sql "SELECT COUNT(*) FROM sales s, customers c WHERE s.customer_id = c.id"
    def count_by_sql(sql)
      sql = sanitize_conditions(sql)
      connection.select_value(sql, "#{name} Count").to_i
    end
    
    # Returns an <tt>Array</tt> containing the type-cast values of a single
    # attribute of all records of this class. This is identical to the
    # idiom:
    #
    #   Person.select(:id).map(&:id)
    #
    # but without the overhead of instantiating each ActiveRecord::Base
    # object.
    #
    # Examples:
    #
    #   Person.select_column(:id) # SELECT people.id FROM people
    def select_column(attr_name)
      attr_name = attr_name.to_s
      attr_name = primary_key if attr_name == 'id'

      column = columns_hash[attr_name]
      coder  = serialized_attributes[attr_name]

      connection.select_rows(
        except(:select).select(arel_table[attr_name]).to_sql
      ).map! do |values|
        type_cast_for_select_column(values[0], column, coder)
      end
    end

    # Returns an <tt>Array</tt> which contains an <tt>Array</tt> for each
    # record of this class. Each internal array contains the type-cast
    # values of the attributes given as parameters. Like <tt>select_column</tt>,
    # this avoids the overhead of instantiating each ActiveRecord::Base
    # object, but it also allows for the following syntax:
    #
    #   Person.select_columns(:name, :email) do |name, email|
    #     puts "#{name}'s e-mail address is #{email}"
    #   end
    def select_columns(*attr_names)
      attr_names.map! do |attr_name|
        attr_name = attr_name.to_s
        attr_name == 'id' ? primary_key : attr_name
      end

      columns = attr_names.map {|n| columns_hash[n]}
      coders  = attr_names.map {|n| serialized_attributes[n]}

      connection.select_rows(
        except(:select).select(attr_names.map {|n| arel_table[n]}).to_sql
      ).map! do |values|
        values.each_with_index do |value, index|
          values[index] = type_cast_for_select_column(value, columns[index], coders[index])
        end
      end
    end

    # Given a value, a column definition, and a coder, type-cast or
    # decode the value.
    def type_cast_for_select_column(value, column, coder)
      if value.nil? || !column
        value
      elsif coder
        coder.load(value)
      else
        column.type_cast(value)
      end
    end
    
  end
end
