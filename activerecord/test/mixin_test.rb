require 'abstract_unit'
require 'active_record/acts/tree'
require 'active_record/acts/list'
require 'active_record/acts/nested_set'
require 'fixtures/mixin'

class ListTest < Test::Unit::TestCase
  fixtures :mixins
 
  def test_reordering
    
    assert_equal [mixins(:list_1), 
                  mixins(:list_2), 
                  mixins(:list_3), 
                  mixins(:list_4)], 
                  ListMixin.find(:all, :conditions => 'parent_id = 5', :order => 'pos')
                  
    mixins(:list_2).move_lower
                  
    assert_equal [mixins(:list_1), 
                  mixins(:list_3), 
                  mixins(:list_2), 
                  mixins(:list_4)], 
                  ListMixin.find(:all, :conditions => 'parent_id = 5', :order => 'pos')
                  
    mixins(:list_2).move_higher

    assert_equal [mixins(:list_1), 
                  mixins(:list_2), 
                  mixins(:list_3), 
                  mixins(:list_4)], 
                  ListMixin.find(:all, :conditions => 'parent_id = 5', :order => 'pos')
    
    mixins(:list_1).move_to_bottom

    assert_equal [mixins(:list_2), 
                  mixins(:list_3), 
                  mixins(:list_4), 
                  mixins(:list_1)], 
                  ListMixin.find(:all, :conditions => 'parent_id = 5', :order => 'pos')

    mixins(:list_1).move_to_top

    assert_equal [mixins(:list_1), 
                  mixins(:list_2), 
                  mixins(:list_3), 
                  mixins(:list_4)],
                  ListMixin.find(:all, :conditions => 'parent_id = 5', :order => 'pos')
                  
                  
    mixins(:list_2).move_to_bottom
  
    assert_equal [mixins(:list_1), 
                  mixins(:list_3), 
                  mixins(:list_4), 
                  mixins(:list_2)],
                  ListMixin.find(:all, :conditions => 'parent_id = 5', :order => 'pos')

    mixins(:list_4).move_to_top

    assert_equal [mixins(:list_4), 
                  mixins(:list_1), 
                  mixins(:list_3), 
                  mixins(:list_2)],
                  ListMixin.find(:all, :conditions => 'parent_id = 5', :order => 'pos')
        
  end
  
  def test_next_prev
    assert_equal mixins(:list_2), mixins(:list_1).lower_item
    assert_nil mixins(:list_1).higher_item
    assert_equal mixins(:list_3), mixins(:list_4).higher_item
    assert_nil mixins(:list_4).lower_item
  end
  
  
  def test_injection
    item = ListMixin.new("parent_id"=>1)
    assert_equal "parent_id = 1", item.scope_condition
    assert_equal "pos", item.position_column
  end  
  
  def test_insert
    new = ListMixin.create("parent_id"=>20)
    assert_equal 1, new.pos
    assert new.first?
    assert new.last?

    new = ListMixin.create("parent_id"=>20)
    assert_equal 2, new.pos
    assert !new.first?
    assert new.last?
    
    new = ListMixin.create("parent_id"=>20)
    assert_equal 3, new.pos    
    assert !new.first?
    assert new.last?
    
    new = ListMixin.create("parent_id"=>0)
    assert_equal 1, new.pos
    assert new.first?
    assert new.last?
  end    

  def test_insert_at
    new = ListMixin.create("parent_id" => 20)
    assert_equal 1, new.pos

	 new = ListMixin.create("parent_id" => 20)
	 assert_equal 2, new.pos
	
	 new = ListMixin.create("parent_id" => 20)
	 assert_equal 3, new.pos

	 new4 = ListMixin.create("parent_id" => 20)
	 assert_equal 4, new4.pos

	 new4.insert_at(3)
	 assert_equal 3, new4.pos

	 new.reload
	 assert_equal 4, new.pos
    
    new.insert_at(2)
    assert_equal 2, new.pos

    new4.reload
    assert_equal 4, new4.pos
  end
  
  def test_delete_middle
    
    assert_equal [mixins(:list_1), 
                  mixins(:list_2), 
                  mixins(:list_3), 
                  mixins(:list_4)], 
                  ListMixin.find(:all, :conditions => 'parent_id = 5', :order => 'pos')
              
    mixins(:list_2).destroy
    
    assert_equal [mixins(:list_1, :reload), 
                  mixins(:list_3, :reload), 
                  mixins(:list_4, :reload)], 
                  ListMixin.find(:all, :conditions => 'parent_id = 5', :order => 'pos')
                  
    assert_equal 1, mixins(:list_1).pos
    assert_equal 2, mixins(:list_3).pos
    assert_equal 3, mixins(:list_4).pos

    mixins(:list_1).destroy

    assert_equal [mixins(:list_3, :reload), 
                  mixins(:list_4, :reload)], 
                  ListMixin.find(:all, :conditions => 'parent_id = 5', :order => 'pos')
                  
    assert_equal 1, mixins(:list_3).pos
    assert_equal 2, mixins(:list_4).pos
    
  end  

  def test_with_string_based_scope
    new = ListWithStringScopeMixin.create("parent_id"=>500)
    assert_equal 1, new.pos
    assert new.first?
    assert new.last?
  end 

  def test_nil_scope
    new1, new2, new3 = ListMixin.create, ListMixin.create, ListMixin.create
    new2.move_higher
    assert_equal [new2, new1, new3], ListMixin.find(:all, :conditions => 'parent_id IS NULL', :order => 'pos')
  end
end

class TreeTest < Test::Unit::TestCase
  fixtures :mixins
  
  def test_has_child
    assert_equal true, mixins(:tree_1).has_children?
    assert_equal true, mixins(:tree_2).has_children?
    assert_equal false, mixins(:tree_3).has_children?
    assert_equal false, mixins(:tree_4).has_children?
  end

  def test_children
    assert_equal mixins(:tree_1).children, [mixins(:tree_2), mixins(:tree_4)]
    assert_equal mixins(:tree_2).children, [mixins(:tree_3)]
    assert_equal mixins(:tree_3).children, []
    assert_equal mixins(:tree_4).children, []
  end

  def test_parent
    assert_equal mixins(:tree_2).parent, mixins(:tree_1)
    assert_equal mixins(:tree_2).parent, mixins(:tree_4).parent
    assert_nil mixins(:tree_1).parent
  end
  
  def test_delete
    assert_equal 4, TreeMixin.count
    mixins(:tree_1).destroy
    assert_equal 0, TreeMixin.count
  end
  
  def test_insert
    @extra = mixins(:tree_1).children.create
    
    assert @extra
    
    assert_equal @extra.parent, mixins(:tree_1)

    assert_equal 3, mixins(:tree_1).children.size
    assert mixins(:tree_1).children.include?(@extra)
    assert mixins(:tree_1).children.include?(mixins(:tree_2))
    assert mixins(:tree_1).children.include?(mixins(:tree_4))
  end

end

class TouchTest < Test::Unit::TestCase
  fixtures :mixins
  
  def test_update
    
    stamped = Mixin.new 
      
    assert_nil stamped.updated_at
    assert_nil stamped.created_at
    stamped.save
    assert_not_nil stamped.updated_at
    assert_not_nil stamped.created_at
  end  

  def test_create
    @obj = Mixin.create
    assert_not_nil @obj.updated_at
    assert_not_nil @obj.created_at
  end  

  def test_many_updates

    stamped = Mixin.new 

    assert_nil stamped.updated_at
    assert_nil stamped.created_at
    stamped.save
    assert_not_nil stamped.created_at
    assert_not_nil stamped.updated_at
    
    old_updated_at = stamped.updated_at

    sleep 1
    stamped.save    
    assert_not_equal stamped.created_at, stamped.updated_at
    assert_not_equal old_updated_at, stamped.updated_at

  end

  def test_create_turned_off
    Mixin.record_timestamps = false

    assert_nil mixins(:tree_1).updated_at
    mixins(:tree_1).save
    assert_nil mixins(:tree_1).updated_at

    Mixin.record_timestamps = true
  end
end
