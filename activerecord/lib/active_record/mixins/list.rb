module ActiveRecord
  # Mixins are a way of decorating existing Active Record models with additional behavior. If you for example
  # want to keep a number of Documents in order, you can include Mixins::List, and all of the sudden be able to
  # call <tt>document.move_to_bottom</tt>.
  module Mixins
    # This mixin provides the capabilities for sorting and reordering a number of objects in list.
    # The class that has this mixin included needs to have a "position" column defined as an integer on
    # the mapped database table. Further more, you need to implement the <tt>scope_condition</tt> that
    # defines how to separate one list from another.
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
        base.before_destroy :remove_from_list
        base.after_create   :add_to_list_bottom
      end

      # Moving around on the list

      def move_lower
        return unless lower_item
        lower_item.decrement_position
        increment_position
      end

      def move_higher
        return unless higher_item
        higher_item.increment_position
        decrement_position
      end
    
      def move_to_bottom
        decrement_positions_on_lower_items
        assume_bottom_position
      end

      def move_to_top
        increment_positions_on_higher_items
        assume_top_position
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
        self.position = position.to_i + 1
        save
      end
    
      def decrement_position
        self.position = position.to_i - 1
        save
      end
    
    
      # Querying the position
    
      def first?
        self.position == 1
      end
    
      def last?
        self.position == bottom_position_in_list
      end

      private
        # Overwrite this method to define the scope of the list changes
        def scope_condition; end
    
        def higher_item
          self.class.find_first(
            "#{scope_condition} AND position = #{(position.to_i - 1).to_s}"
          )
        end
    
        def lower_item
          self.class.find_first(
            "#{scope_condition} AND position = #{(position.to_i + 1).to_s}"
          )
        end
    
        def bottom_position_in_list
          item = bottom_item
          item ? item.position : 0
        end
    
        def bottom_item
          self.class.find_first(
            "#{scope_condition} ",
            "position DESC"
          )
        end

        def assume_bottom_position
          self.position = bottom_position_in_list.to_i + 1
          save
        end
      
        def assume_top_position
          self.position = 1
          save
        end
      
        def decrement_positions_on_lower_items
          self.class.update_all(
            "position = (position - 1)",  "#{scope_condition} AND position > #{position.to_i}"
          )
        end
      
        def increment_positions_on_higher_items
          self.class.update_all(
            "position = (position + 1)",  "#{scope_condition} AND position < #{position.to_i}"
          )
        end

        def increment_positions_on_all_items
          self.class.update_all(
            "position = (position + 1)",  "#{scope_condition}"
          )
        end
    end
  end
end