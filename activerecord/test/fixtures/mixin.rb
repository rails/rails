class Mixin < ActiveRecord::Base

end

class TreeMixin < Mixin 
    acts_as_tree :foreign_key => "parent_id", :order => "id"
end

class TreeMixinWithoutOrder < Mixin
    acts_as_tree :foreign_key => "parent_id"
end

class RecursivelyCascadedTreeMixin < Mixin
  acts_as_tree :foreign_key => "parent_id"
  has_one :first_child, :class_name => 'RecursivelyCascadedTreeMixin', :foreign_key => :parent_id
end

class ListMixin < Mixin
  acts_as_list :column => "pos", :scope => :parent

  def self.table_name() "mixins" end
end

class ListMixinSub1 < ListMixin
end

class ListMixinSub2 < ListMixin
end


class ListWithStringScopeMixin < ActiveRecord::Base
  acts_as_list :column => "pos", :scope => 'parent_id = #{parent_id}'

  def self.table_name() "mixins" end
end

class NestedSet < Mixin
  acts_as_nested_set :scope => "root_id IS NULL"
  
  def self.table_name() "mixins" end
end

class NestedSetWithStringScope < Mixin
  acts_as_nested_set :scope => 'root_id = #{root_id}'
  
  def self.table_name() "mixins" end
end

class NestedSetWithSymbolScope < Mixin
  acts_as_nested_set :scope => :root
  
  def self.table_name() "mixins" end
end

class NestedSetSuperclass < Mixin
  acts_as_nested_set :scope => :root
  
  def self.table_name() "mixins" end
end

class NestedSetSubclass < NestedSetSuperclass
  
end
