require 'abstract_unit'
require 'active_record/acts/tree'
require 'active_record/acts/list'
require 'fixtures/mixin'

class ListTest < Test::Unit::TestCase
  fixtures :mixins
  
  def test_reordering
    
    assert_equal [@mixins['list_1'].find, 
                  @mixins['list_2'].find, 
                  @mixins['list_3'].find, 
                  @mixins['list_4'].find], 
                  ListMixin.find_all("parent_id=5", "pos")
                  
    @mixins['list_2'].find.move_lower
                  
    assert_equal [@mixins['list_1'].find, 
                  @mixins['list_3'].find, 
                  @mixins['list_2'].find, 
                  @mixins['list_4'].find], 
                  ListMixin.find_all("parent_id=5", "pos")                      
                  
    @mixins['list_2'].find.move_higher

    assert_equal [@mixins['list_1'].find, 
                  @mixins['list_2'].find, 
                  @mixins['list_3'].find, 
                  @mixins['list_4'].find], 
                  ListMixin.find_all("parent_id=5", "pos")
    
    @mixins['list_1'].find.move_to_bottom

    assert_equal [@mixins['list_2'].find, 
                  @mixins['list_3'].find, 
                  @mixins['list_4'].find, 
                  @mixins['list_1'].find], 
                  ListMixin.find_all("parent_id=5", "pos")

    @mixins['list_1'].find.move_to_top

    assert_equal [@mixins['list_1'].find, 
                  @mixins['list_2'].find, 
                  @mixins['list_3'].find, 
                  @mixins['list_4'].find],
                  ListMixin.find_all("parent_id=5", "pos")
                  
                  
    @mixins['list_2'].find.move_to_bottom
  
    assert_equal [@mixins['list_1'].find, 
                  @mixins['list_3'].find, 
                  @mixins['list_4'].find, 
                  @mixins['list_2'].find],
                  ListMixin.find_all("parent_id=5", "pos")                  

    @mixins['list_4'].find.move_to_top

    assert_equal [@mixins['list_4'].find, 
                  @mixins['list_1'].find, 
                  @mixins['list_3'].find, 
                  @mixins['list_2'].find],
                  ListMixin.find_all("parent_id=5", "pos")                  
        
  end
  
  def test_next_prev
    assert_equal @list_2, @list_1.lower_item
    assert_nil @list_1.higher_item
    assert_equal @list_3, @list_4.higher_item
    assert_nil @list_4.lower_item
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
  
  def test_delete_middle
    
    assert_equal [@mixins['list_1'].find, 
                  @mixins['list_2'].find, 
                  @mixins['list_3'].find, 
                  @mixins['list_4'].find], 
                  ListMixin.find_all("parent_id=5", "pos")
              
    @mixins['list_2'].find.destroy
    
    assert_equal [@mixins['list_1'].find, 
                  @mixins['list_3'].find, 
                  @mixins['list_4'].find], 
                  ListMixin.find_all("parent_id=5", "pos")
                  
    assert_equal 1, @mixins['list_1'].find.pos
    assert_equal 2, @mixins['list_3'].find.pos
    assert_equal 3, @mixins['list_4'].find.pos

    @mixins['list_1'].find.destroy

    assert_equal [@mixins['list_3'].find, 
                  @mixins['list_4'].find], 
                  ListMixin.find_all("parent_id=5", "pos")
                  
    assert_equal 1, @mixins['list_3'].find.pos
    assert_equal 2, @mixins['list_4'].find.pos
    
  end  

  def test_with_string_based_scope
    new = ListWithStringScopeMixin.create("parent_id"=>500)
    assert_equal 1, new.pos
    assert new.first?
    assert new.last?
  end 
end

class TreeTest < Test::Unit::TestCase
  fixtures :mixins
  
  def test_has_child
    assert_equal true, @tree_1.has_children?
    assert_equal true, @tree_2.has_children?
    assert_equal false, @tree_3.has_children?
    assert_equal false, @tree_4.has_children?
  end

  def test_children
    assert_equal @tree_1.children, [@tree_2, @tree_4]
    assert_equal @tree_2.children, [@tree_3]
    assert_equal @tree_3.children, []
    assert_equal @tree_4.children, []
  end

  def test_parent
    assert_equal @tree_2.parent, @tree_1
    assert_equal @tree_2.parent, @tree_4.parent
    assert_nil @tree_1.parent
  end
  
  def test_delete
    assert_equal 4, TreeMixin.count
    @tree_1.destroy
    assert_equal 0, TreeMixin.count
  end
  
  def test_insert
    @extra = @tree_1.children.create
    
    assert @extra
    
    assert_equal @extra.parent, @tree_1
    assert_equal [@tree_2, @tree_4, @extra], @tree_1.children
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

    assert_nil @tree_1.updated_at
    @tree_1.save
    assert_nil @tree_1.updated_at

    Mixin.record_timestamps = true
  end
end
