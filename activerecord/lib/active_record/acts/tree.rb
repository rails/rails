module ActiveRecord
  module Acts #:nodoc:
    module Tree #:nodoc:
      def self.append_features(base)
        super        
        base.extend(ClassMethods)              
      end  

      # Specify this act if you want to model a tree structure by providing a parent association and an children 
      # association. This act assumes that requires that you have a foreign key column, which by default is called parent_id.
      # 
      #   class Category < ActiveRecord::Base
      #     acts_as_tree :order => "name"
      #   end
      #   
      #   Example : 
      #   root
      #    \_ child1 
      #         \_ sub-child1
      #
      #   root      = Category.create("name" => "root")
      #   child1      = root.children.create("name" => "child1")
      #   subchild1   = child1.children.create("name" => "subchild1")
      #
      #   root.parent # => nil
      #   child1.parent # => root
      #   root.children # => [child1]
      #   root.children.first.children.first # => subchild1
      module ClassMethods
        # Configuration options are:
        #
        # * <tt>foreign_key</tt> - specifies the column name to use for track of the tree (default: parent_id)
        # * <tt>order</tt> - makes it possible to sort the children according to this SQL snippet.
        # * <tt>counter_cache</tt> - keeps a count in a children_count column if set to true (default: false).
        def acts_as_tree(options = {})
          configuration = { :foreign_key => "parent_id", :order => nil, :counter_cache => nil }
          configuration.update(options) if options.is_a?(Hash)

          belongs_to :parent, :class_name => name, :foreign_key => configuration[:foreign_key], :counter_cache => configuration[:counter_cache]
          has_many :children, :class_name => name, :foreign_key => configuration[:foreign_key], :order => configuration[:order], :dependent => true

          module_eval <<-END
            def self.roots
              self.find(:all, :conditions => "#{configuration[:foreign_key]} IS NULL", :order => "#{configuration[:order]}")
            end
            def self.root
              self.find(:first, :conditions => "#{configuration[:foreign_key]} IS NULL", :order => "#{configuration[:order]}")
            end
          END

          define_method(:siblings) do
            if parent
              self.class.find(:all, :conditions => [ "#{configuration[:foreign_key]} = ?", parent.id ], :order => configuration[:order])
            else
              self.class.roots
            end
          end
        end
      end
    end
  end
end