module ActiveRecord
  # Mixins are a way of decorating existing Active Record models with additional behavior. If you for example
  # want to keep a number of Documents in order, you can include Mixins::List, and all of the sudden be able to
  # call <tt>document.move_to_bottom</tt>.
  module Mixins
    # This mixin provides the capabilities for sorting and reordering a number of objects in list.
    # The class that has this mixin included needs to have a "position" column defined as an integer on
    # the mapped database table. Further more, you need to implement the <tt>scope_condition</tt> if you want
    # to separate one list from another.
    #
    # Todo list example:
    #
    #   class TodoList < ActiveRecord::Base
    #     has_many :todo_items, :order => "position"
    #   end
    #
    #   class TodoItem < ActiveRecord::Base
    #     include ActiveRecord::Mixins::List
    #     belongs_to :todo_list
    #  
    #     private
    #       def scope_condition
    #         "todo_list_id = #{todo_list_id}"
    #       end
    #   end
    #
    #   todo_list.first.move_to_bottom
    #   todo_list.last.move_higher
    module List
      def self.append_features(base)
        super
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        def acts_as_list(options = {})
          configuration = { :column => "position", :scope => "1" }
          configuration.update(options) if options.is_a?(Hash)
          
          class_eval <<-EOV
            include InstanceMethods

            def position_column
              '#{configuration[:column]}'
            end

            def scope_condition
              if configuration[:scope].is_a?(Symbol)
                "#{configuration[:scope]} = \#{#{configuration[:scope]}}"
              else
                configuration[:scope]
              end
            end
            
            before_destroy :remove_from_list
            after_create   :add_to_list_bottom
          EOV
        end
        
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
    

          # Entering or existing the list
    
          def add_to_list_top
            increment_positions_on_all_items
          end

          def add_to_list_bottom
            assume_bottom_position
          end

          def remove_from_list
            decrement_positions_on_lower_items
          end


          # Changing the position

          def increment_position
            update_attribute position_column, self.send(position_column).to_i + 1
          end
    
          def decrement_position
            update_attribute position_column, self.send(position_column).to_i - 1
          end
    
    
          # Querying the position
    
          def first?
            self.send(position_column) == 1
          end
    
          def last?
            self.send(position_column) == bottom_position_in_list
          end

          private
            # Overwrite this method to define the scope of the list changes
            def scope_condition() "1" end
    
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
                "#{position_column} = (#{position_column} + 1)",  "#{scope_condition} AND #{position_column} < #{send(position_column)}"
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
end