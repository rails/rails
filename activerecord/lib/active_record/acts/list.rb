module ActiveRecord
  module Acts #:nodoc:
    module List #:nodoc:
      def self.append_features(base)
        super
        base.extend(ClassMethods)
      end
      
      # This act provides the capabilities for sorting and reordering a number of objects in list.
      # The class that has this specified needs to have a "position" column defined as an integer on
      # the mapped database table.
      #
      # Todo list example:
      #
      #   class TodoList < ActiveRecord::Base
      #     has_many :todo_items, :order => "position"
      #   end
      #
      #   class TodoItem < ActiveRecord::Base
      #     belongs_to :todo_list
      #     acts_as_list :scope => :todo_list
      #   end
      #
      #   todo_list.first.move_to_bottom
      #   todo_list.last.move_higher
      module ClassMethods
        # Configuration options are:
        #
        # * +column+ - specifies the column name to use for keeping the position integer (default: position)
        # * +scope+ - restricts what is to be considered a list. Given a symbol, it'll attach "_id" (if that hasn't been already) and use that
        #   as the foreign key restriction. It's also possible to give it an entire string that is interpolated if you need a tighter scope than
        #   just a foreign key. Example: <tt>acts_as_list :scope => 'todo_list_id = #{todo_list_id} AND completed = 0'</tt>
        def acts_as_list(options = {})
          configuration = { :column => "position", :scope => "1" }
          configuration.update(options) if options.is_a?(Hash)

          configuration[:scope] = "#{configuration[:scope]}_id".intern if configuration[:scope].is_a?(Symbol) && configuration[:scope].to_s !~ /_id$/
          
          if configuration[:scope].is_a?(Symbol)
            scope_condition_method = %(
              def scope_condition
                if #{configuration[:scope].to_s}.nil?
                  "#{configuration[:scope].to_s} IS NULL"
                else
                  "#{configuration[:scope].to_s} = \#{#{configuration[:scope].to_s}}"
                end
              end
            )
          else
            scope_condition_method = "def scope_condition() \"#{configuration[:scope]}\" end"
          end
          
          class_eval <<-EOV
            include ActiveRecord::Acts::List::InstanceMethods

            def position_column
              '#{configuration[:column]}'
            end
            
            #{scope_condition_method}
            
            before_destroy :remove_from_list
            before_create  :add_to_list_bottom
          EOV
        end
      end
        
      # All the methods available to a record that has had <tt>acts_as_list</tt> specified.
      module InstanceMethods
        def move_lower
          return unless lower_item

          self.class.transaction do
            lower_item.decrement_position
            increment_position
          end
        end

        def move_higher
          return unless higher_item

          self.class.transaction do
            higher_item.increment_position
            decrement_position
          end
        end
  
        def move_to_bottom
          self.class.transaction do
            decrement_positions_on_lower_items
            assume_bottom_position
          end
        end

        def move_to_top
          self.class.transaction do
            increment_positions_on_higher_items
            assume_top_position
          end
        end
  

        def remove_from_list
          decrement_positions_on_lower_items
        end


        def increment_position
          update_attribute position_column, self.send(position_column).to_i + 1
        end
  
        def decrement_position
          update_attribute position_column, self.send(position_column).to_i - 1
        end
  
  
        def first?
          self.send(position_column) == 1
        end
  
        def last?
          self.send(position_column) == bottom_position_in_list
        end
        
        def higher_item
          self.class.find_first(
            "#{scope_condition} AND #{position_column} = #{(send(position_column).to_i - 1).to_s}"
          )
        end

        def lower_item
          self.class.find_first(
            "#{scope_condition} AND #{position_column} = #{(send(position_column).to_i + 1).to_s}"
          )
        end

        private
          def add_to_list_top
            increment_positions_on_all_items
          end

          def add_to_list_bottom
            write_attribute(position_column, bottom_position_in_list.to_i + 1)
          end
      
          # Overwrite this method to define the scope of the list changes
          def scope_condition() "1" end

          def bottom_position_in_list
            item = bottom_item
            item ? item.send(position_column) : 0
          end

          def bottom_item
            self.class.find_first(
              "#{scope_condition} ",
              "#{position_column} DESC"
            )
          end

          def assume_bottom_position
            update_attribute position_column, bottom_position_in_list.to_i + 1
          end
  
          def assume_top_position
            update_attribute position_column, 1
          end
  
          def decrement_positions_on_lower_items
            self.class.update_all(
              "#{position_column} = (#{position_column} - 1)",  "#{scope_condition} AND #{position_column} > #{send(position_column).to_i}"
            )
          end
  
          def increment_positions_on_higher_items
            self.class.update_all(
              "#{position_column} = (#{position_column} + 1)",  "#{scope_condition} AND #{position_column} < #{send(position_column).to_i}"
            )
          end

          def increment_positions_on_all_items
            self.class.update_all(
              "#{position_column} = (#{position_column} + 1)",  "#{scope_condition}"
            )
          end
      end     
    end
  end
end