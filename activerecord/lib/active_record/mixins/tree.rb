module ActiveRecord
  module Mixins
    # Including this mixin if you want to model a tree structure by providing a parent association and an children 
    # association. This mixin assumes that you have a column called parent_id
    # 
    #   class Category < ActiveRecord::Base
    #     include ActiveRecord::Mixins::Tree
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
    module Tree
      def self.append_features(base)
        super        
        base.extend(ClassMethods)              
      end  
    end
    
    module ClassMethods
      def acts_as_tree(options = {})
        configuration = { :foreign_key => "parent_id", :order => nil }
        configuration.update(options) if options.is_a?(Hash)
        
        belongs_to :parent, :class_name => name, :foreign_key => configuration[:foreign_key]
        has_many :children, :class_name => name, :foreign_key => configuration[:foreign_key], :order => configuration[:order], :dependent => true
      end
    end
  end
end