module ActiveRecord
  module Acts #:nodoc:
    module Tree #:nodoc:
      def self.included(base)
        base.extend(ClassMethods)
      end

      # Specify this act if you want to model a tree structure by providing a parent association and a children
      # association. This act requires that you have a foreign key column, which by default is called parent_id.
      #
      #   class Category < ActiveRecord::Base
      #     acts_as_tree :order => "name"
      #   end
      #
      #   Example:
      #   root
      #    \_ child1
      #         \_ subchild1
      #         \_ subchild2
      #
      #   root      = Category.create("name" => "root")
      #   child1    = root.children.create("name" => "child1")
      #   subchild1 = child1.children.create("name" => "subchild1")
      #
      #   root.parent   # => nil
      #   child1.parent # => root
      #   root.children # => [child1]
      #   root.children.first.children.first # => subchild1
      #
      # In addition to the parent and children associations, the following instance methods are added to the class
      # after specifying the act:
      # * siblings          : Returns all the children of the parent, excluding the current node ([ subchild2 ] when called from subchild1)
      # * self_and_siblings : Returns all the children of the parent, including the current node ([ subchild1, subchild2 ] when called from subchild1)
      # * ancestors         : Returns all the ancestors of the current node ([child1, root] when called from subchild2)
      # * root              : Returns the root of the current node (root when called from subchild2)
      module ClassMethods
        # Configuration options are:
        #
        # * <tt>foreign_key</tt> - specifies the column name to use for tracking of the tree (default: parent_id)
        # * <tt>order</tt> - makes it possible to sort the children according to this SQL snippet.
        # * <tt>counter_cache</tt> - keeps a count in a children_count column if set to true (default: false).
        def acts_as_tree(options = {})
          configuration = { :foreign_key => "parent_id", :order => nil, :counter_cache => nil }
          configuration.update(options) if options.is_a?(Hash)

          belongs_to :parent, :class_name => name, :foreign_key => configuration[:foreign_key], :counter_cache => configuration[:counter_cache]
          has_many :children, :class_name => name, :foreign_key => configuration[:foreign_key], :order => configuration[:order], :dependent => :destroy

          class_eval <<-EOV
            include ActiveRecord::Acts::Tree::InstanceMethods

            def self.roots
              find(:all, :conditions => "#{configuration[:foreign_key]} IS NULL", :order => #{configuration[:order].nil? ? "nil" : %Q{"#{configuration[:order]}"}})
            end

            def self.root
              find(:first, :conditions => "#{configuration[:foreign_key]} IS NULL", :order => #{configuration[:order].nil? ? "nil" : %Q{"#{configuration[:order]}"}})
            end
          EOV
        end
      end

      module InstanceMethods
        # Returns list of ancestors, starting from parent until root.
        #
        #   subchild1.ancestors # => [child1, root]
        def ancestors
          node, nodes = self, []
          nodes << node = node.parent while node.parent
          nodes
        end

        def root
          node = self
          node = node.parent while node.parent
          node
        end

        def siblings
          self_and_siblings - [self]
        end

        def self_and_siblings
          parent ? parent.children : self.class.roots
        end
      end
    end
  end
end
