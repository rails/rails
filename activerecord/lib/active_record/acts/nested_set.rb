module ActiveRecord
  module Acts #:nodoc:
    module NestedSet #:nodoc:
      def self.included(base)
        base.extend(ClassMethods)              
      end  

      # This acts provides Nested Set functionality.  Nested Set is similiar to Tree, but with
      # the added feature that you can select the children and all of their descendents with
      # a single query.  A good use case for this is a threaded post system, where you want
      # to display every reply to a comment without multiple selects.
      #
      # A google search for "Nested Set" should point you in the direction to explain the
      # database theory.  I figured out a bunch of this from
      # http://threebit.net/tutorials/nestedset/tutorial1.html
      #
      # Instead of picturing a leaf node structure with children pointing back to their parent,
      # the best way to imagine how this works is to think of the parent entity surrounding all
      # of its children, and its parent surrounding it, etc.  Assuming that they are lined up
      # horizontally, we store the left and right boundries in the database.
      #
      # Imagine:
      #   root
      #     |_ Child 1
      #       |_ Child 1.1
      #       |_ Child 1.2
      #     |_ Child 2
      #       |_ Child 2.1
      #       |_ Child 2.2
      #
      # If my cirlces in circles description didn't make sense, check out this sweet
      # ASCII art:
      #
      #     ___________________________________________________________________
      #    |  Root                                                             |
      #    |    ____________________________    ____________________________   |
      #    |   |  Child 1                  |   |  Child 2                  |   |
      #    |   |   __________   _________  |   |   __________   _________  |   |
      #    |   |  |  C 1.1  |  |  C 1.2 |  |   |  |  C 2.1  |  |  C 2.2 |  |   |
      #    1   2  3_________4  5________6  7   8  9_________10 11_______12 13  14
      #    |   |___________________________|   |___________________________|   |
      #    |___________________________________________________________________| 
      #
      # The numbers represent the left and right boundries.  The table then might
      # look like this:
      #    ID | PARENT | LEFT | RIGHT | DATA
      #     1 |      0 |    1 |    14 | root
      #     2 |      1 |    2 |     7 | Child 1
      #     3 |      2 |    3 |     4 | Child 1.1
      #     4 |      2 |    5 |     6 | Child 1.2
      #     5 |      1 |    8 |    13 | Child 2
      #     6 |      5 |    9 |    10 | Child 2.1
      #     7 |      5 |   11 |    12 | Child 2.2
      #
      # So, to get all children of an entry, you
      #     SELECT * WHERE CHILD.LEFT IS BETWEEN PARENT.LEFT AND PARENT.RIGHT
      #
      # To get the count, it's (LEFT - RIGHT + 1)/2, etc.
      #
      # To get the direct parent, it falls back to using the PARENT_ID field.   
      #
      # There are instance methods for all of these.
      #
      # The structure is good if you need to group things together; the downside is that
      # keeping data integrity is a pain, and both adding and removing an entry
      # require a full table write.        
      #
      # This sets up a before_destroy trigger to prune the tree correctly if one of its
      # elements gets deleted.
      #
      module ClassMethods                      
        # Configuration options are:
        #
        # * +parent_column+ - specifies the column name to use for keeping the position integer (default: parent_id)
        # * +left_column+ - column name for left boundry data, default "lft"
        # * +right_column+ - column name for right boundry data, default "rgt"
        # * +scope+ - restricts what is to be considered a list. Given a symbol, it'll attach "_id" 
        #   (if that hasn't been already) and use that as the foreign key restriction. It's also possible 
        #   to give it an entire string that is interpolated if you need a tighter scope than just a foreign key.
        #   Example: <tt>acts_as_list :scope => 'todo_list_id = #{todo_list_id} AND completed = 0'</tt>
        def acts_as_nested_set(options = {})
          configuration = { :parent_column => "parent_id", :left_column => "lft", :right_column => "rgt", :scope => "1 = 1" }
          
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
            include ActiveRecord::Acts::NestedSet::InstanceMethods

            #{scope_condition_method}
            
            def left_col_name() "#{configuration[:left_column]}" end

            def right_col_name() "#{configuration[:right_column]}" end
              
            def parent_column() "#{configuration[:parent_column]}" end

          EOV
        end
      end
      
      module InstanceMethods
        # Returns true is this is a root node.  
        def root?
          parent_id = self[parent_column]
          (parent_id == 0 || parent_id.nil?) && (self[left_col_name] == 1) && (self[right_col_name] > self[left_col_name])
        end                                                                                             
                                    
        # Returns true is this is a child node
        def child?                          
          parent_id = self[parent_column]
          !(parent_id == 0 || parent_id.nil?) && (self[left_col_name] > 1) && (self[right_col_name] > self[left_col_name])
        end     
        
        # Returns true if we have no idea what this is
        def unknown?
          !root? && !child?
        end

                     
        # Adds a child to this object in the tree.  If this object hasn't been initialized,
        # it gets set up as a root node.  Otherwise, this method will update all of the
        # other elements in the tree and shift them to the right, keeping everything
        # balanced. 
        def add_child( child )     
          self.reload
          child.reload

          if child.root?
            raise "Adding sub-tree isn\'t currently supported"
          else
            if ( (self[left_col_name] == nil) || (self[right_col_name] == nil) )
              # Looks like we're now the root node!  Woo
              self[left_col_name] = 1
              self[right_col_name] = 4
              
              # What do to do about validation?
              return nil unless self.save
              
              child[parent_column] = self.id
              child[left_col_name] = 2
              child[right_col_name]= 3
              return child.save
            else
              # OK, we need to add and shift everything else to the right
              child[parent_column] = self.id
              right_bound = self[right_col_name]
              child[left_col_name] = right_bound
              child[right_col_name] = right_bound + 1
              self[right_col_name] += 2
              self.class.base_class.transaction {
                self.class.base_class.update_all( "#{left_col_name} = (#{left_col_name} + 2)",  "#{scope_condition} AND #{left_col_name} >= #{right_bound}" )
                self.class.base_class.update_all( "#{right_col_name} = (#{right_col_name} + 2)",  "#{scope_condition} AND #{right_col_name} >= #{right_bound}" )
                self.save
                child.save
              }
            end
          end                                   
        end
                                   
        # Returns the number of nested children of this object.
        def children_count
          return (self[right_col_name] - self[left_col_name] - 1)/2
        end
                                                               
        # Returns a set of itself and all of its nested children
        def full_set
          self.class.base_class.find(:all, :conditions => "#{scope_condition} AND (#{left_col_name} BETWEEN #{self[left_col_name]} and #{self[right_col_name]})" )
        end
                  
        # Returns a set of all of its children and nested children
        def all_children
          self.class.base_class.find(:all, :conditions => "#{scope_condition} AND (#{left_col_name} > #{self[left_col_name]}) and (#{right_col_name} < #{self[right_col_name]})" )
        end
                                  
        # Returns a set of only this entry's immediate children
        def direct_children
          self.class.base_class.find(:all, :conditions => "#{scope_condition} and #{parent_column} = #{self.id}")
        end
                                      
        # Prunes a branch off of the tree, shifting all of the elements on the right
        # back to the left so the counts still work.
        def before_destroy
          return if self[right_col_name].nil? || self[left_col_name].nil?
          dif = self[right_col_name] - self[left_col_name] + 1

          self.class.base_class.transaction {
            self.class.base_class.delete_all( "#{scope_condition} and #{left_col_name} > #{self[left_col_name]} and #{right_col_name} < #{self[right_col_name]}" )
            self.class.base_class.update_all( "#{left_col_name} = (#{left_col_name} - #{dif})",  "#{scope_condition} AND #{left_col_name} >= #{self[right_col_name]}" )
            self.class.base_class.update_all( "#{right_col_name} = (#{right_col_name} - #{dif} )",  "#{scope_condition} AND #{right_col_name} >= #{self[right_col_name]}" )
          }
        end
      end
    end
  end
end
