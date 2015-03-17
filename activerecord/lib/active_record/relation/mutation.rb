module ActiveRecord
  class Relation
    module Mutation
      # Updates all records in the current relation with details given. This method constructs a single SQL UPDATE
      # statement and sends it straight to the database. It does not instantiate the involved models and it does not
      # trigger Active Record callbacks or validations. Values passed to `update_all` will not go through
      # ActiveRecord's type-casting behavior. It should receive only values that can be passed as-is to the SQL
      # database.
      #
      # ==== Parameters
      #
      # * +updates+ - A string, array, or hash representing the SET part of an SQL statement.
      #
      # ==== Examples
      #
      #   # Update all customers with the given attributes
      #   Customer.update_all wants_email: true
      #
      #   # Update all books with 'Rails' in their title
      #   Book.where('title LIKE ?', '%Rails%').update_all(author: 'David')
      #
      #   # Update all books that match conditions, but limit it to 5 ordered by date
      #   Book.where('title LIKE ?', '%Rails%').order(:created_at).limit(5).update_all(author: 'David')
      def update_all(updates)
        raise ArgumentError, "Empty list of attributes to change" if updates.blank?

        stmt = Arel::UpdateManager.new

        stmt.set Arel.sql(@klass.send(:sanitize_sql_for_assignment, updates))
        stmt.table(table)
        stmt.key = table[primary_key]

        if joins_values.any?
          @klass.connection.join_to_update(stmt, arel)
        else
          stmt.take(arel.limit)
          stmt.order(*arel.orders)
          stmt.wheres = arel.constraints
        end

        @klass.connection.update stmt, 'SQL', bound_attributes
      end

      # Updates an object (or multiple objects) and saves it to the database, if validations pass.
      # The resulting object is returned whether the object was saved successfully to the database or not.
      #
      # ==== Parameters
      #
      # * +id+ - This should be the id or an array of ids to be updated.
      # * +attributes+ - This should be a hash of attributes or an array of hashes.
      #
      # ==== Examples
      #
      #   # Updates one record
      #   Person.update(15, user_name: 'Samuel', group: 'expert')
      #
      #   # Updates multiple records
      #   people = { 1 => { "first_name" => "David" }, 2 => { "first_name" => "Jeremy" } }
      #   Person.update(people.keys, people.values)
      #
      #   # Updates multiple records from the result of a relation
      #   people = Person.where(group: 'expert')
      #   people.update(group: 'masters')
      #
      #   Note: Updating a large number of records will run a
      #   UPDATE query for each record, which may cause a performance
      #   issue. So if it is not needed to run callbacks for each update, it is
      #   preferred to use <tt>update_all</tt> for updating all records using
      #   a single query.
      def update(id = :all, attributes)
        if id.is_a?(Array)
          id.map.with_index { |one_id, idx| update(one_id, attributes[idx]) }
        elsif id == :all
          to_a.each { |record| record.update(attributes) }
        else
          object = find(id)
          object.update(attributes)
          object
        end
      end

      # Deletes the records matching +conditions+ without instantiating the records
      # first, and hence not calling the +destroy+ method nor invoking callbacks. This
      # is a single SQL DELETE statement that goes straight to the database, much more
      # efficient than +destroy_all+. Be careful with relations though, in particular
      # <tt>:dependent</tt> rules defined on associations are not honored. Returns the
      # number of rows affected.
      #
      #   Post.delete_all("person_id = 5 AND (category = 'Something' OR category = 'Else')")
      #   Post.delete_all(["person_id = ? AND (category = ? OR category = ?)", 5, 'Something', 'Else'])
      #   Post.where(person_id: 5).where(category: ['Something', 'Else']).delete_all
      #
      # Both calls delete the affected posts all at once with a single DELETE statement.
      # If you need to destroy dependent associations or call your <tt>before_*</tt> or
      # +after_destroy+ callbacks, use the +destroy_all+ method instead.
      #
      # If an invalid method is supplied, +delete_all+ raises an ActiveRecord error:
      #
      #   Post.limit(100).delete_all
      #   # => ActiveRecord::ActiveRecordError: delete_all doesn't support limit
      def delete_all(conditions = nil)
        invalid_methods = INVALID_METHODS_FOR_DELETE_ALL.select { |method|
          if MULTI_VALUE_METHODS.include?(method)
            send("#{method}_values").any?
          elsif SINGLE_VALUE_METHODS.include?(method)
            send("#{method}_value")
          elsif CLAUSE_METHODS.include?(method)
            send("#{method}_clause").any?
          end
        }
        if invalid_methods.any?
          raise ActiveRecordError.new("delete_all doesn't support #{invalid_methods.join(', ')}")
        end

        if conditions
          where(conditions).delete_all
        else
          stmt = Arel::DeleteManager.new
          stmt.from(table)

          if joins_values.any?
            @klass.connection.join_to_delete(stmt, arel, table[primary_key])
          else
            stmt.wheres = arel.constraints
          end

          affected = @klass.connection.delete(stmt, 'SQL', bound_attributes)

          reset
          affected
        end
      end

      # Deletes the row with a primary key matching the +id+ argument, using a
      # SQL +DELETE+ statement, and returns the number of rows deleted. Active
      # Record objects are not instantiated, so the object's callbacks are not
      # executed, including any <tt>:dependent</tt> association options.
      #
      # You can delete multiple rows at once by passing an Array of <tt>id</tt>s.
      #
      # Note: Although it is often much faster than the alternative,
      # <tt>#destroy</tt>, skipping callbacks might bypass business logic in
      # your application that ensures referential integrity or performs other
      # essential jobs.
      #
      # ==== Examples
      #
      #   # Delete a single row
      #   Todo.delete(1)
      #
      #   # Delete multiple rows
      #   Todo.delete([2,3,4])
      def delete(id_or_array)
        where(primary_key => id_or_array).delete_all
      end

      # Destroys the records matching +conditions+ by instantiating each
      # record and calling its +destroy+ method. Each object's callbacks are
      # executed (including <tt>:dependent</tt> association options). Returns the
      # collection of objects that were destroyed; each will be frozen, to
      # reflect that no changes should be made (since they can't be persisted).
      #
      # Note: Instantiation, callback execution, and deletion of each
      # record can be time consuming when you're removing many records at
      # once. It generates at least one SQL +DELETE+ query per record (or
      # possibly more, to enforce your callbacks). If you want to delete many
      # rows quickly, without concern for their associations or callbacks, use
      # +delete_all+ instead.
      #
      # ==== Parameters
      #
      # * +conditions+ - A string, array, or hash that specifies which records
      #   to destroy. If omitted, all records are destroyed. See the
      #   Conditions section in the introduction to ActiveRecord::Base for
      #   more information.
      #
      # ==== Examples
      #
      #   Person.destroy_all("last_login < '2004-04-04'")
      #   Person.destroy_all(status: "inactive")
      #   Person.where(age: 0..18).destroy_all
      def destroy_all(conditions = nil)
        if conditions
          where(conditions).destroy_all
        else
          to_a.each(&:destroy).tap { reset }
        end
      end

      # Destroy an object (or multiple objects) that has the given id. The object is instantiated first,
      # therefore all callbacks and filters are fired off before the object is deleted. This method is
      # less efficient than ActiveRecord#delete but allows cleanup methods and other actions to be run.
      #
      # This essentially finds the object (or multiple objects) with the given id, creates a new object
      # from the attributes, and then calls destroy on it.
      #
      # ==== Parameters
      #
      # * +id+ - Can be either an Integer or an Array of Integers.
      #
      # ==== Examples
      #
      #   # Destroy a single object
      #   Todo.destroy(1)
      #
      #   # Destroy multiple objects
      #   todos = [1,2,3]
      #   Todo.destroy(todos)
      def destroy(id)
        if id.is_a?(Array)
          id.map { |one_id| destroy(one_id) }
        else
          find(id).destroy
        end
      end

      def insert(values) # :nodoc:
        primary_key_value = nil

        if primary_key && Hash === values
          primary_key_value = values[values.keys.find { |k|
            k.name == primary_key
          }]

          if !primary_key_value && connection.prefetch_primary_key?(klass.table_name)
            primary_key_value = connection.next_sequence_value(klass.sequence_name)
            values[klass.arel_table[klass.primary_key]] = primary_key_value
          end
        end

        im = arel.create_insert
        im.into @table

        substitutes, binds = substitute_values values

        if values.empty? # empty insert
          im.values = Arel.sql(connection.empty_insert_statement_value)
        else
          im.insert substitutes
        end

        @klass.connection.insert(
          im,
          'SQL',
          primary_key,
          primary_key_value,
          nil,
          binds)
      end

      def _update_record(values, id, id_was) # :nodoc:
        substitutes, binds = substitute_values values

        scope = @klass.unscoped

        if @klass.finder_needs_type_condition?
          scope.unscope!(where: @klass.inheritance_column)
        end

        relation = scope.where(@klass.primary_key => (id_was || id))
        bvs = binds + relation.bound_attributes
        um = relation
          .arel
          .compile_update(substitutes, @klass.primary_key)

        @klass.connection.update(
          um,
          'SQL',
          bvs,
        )
      end

      def substitute_values(values) # :nodoc:
        binds = values.map do |arel_attr, value|
          QueryAttribute.new(arel_attr.name, value, klass.type_for_attribute(arel_attr.name))
        end

        substitutes = values.map do |(arel_attr, _)|
          [arel_attr, connection.substitute_at(klass.columns_hash[arel_attr.name])]
        end

        [substitutes, binds]
      end
    end
  end
end
