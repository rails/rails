require 'abstract_unit'
require 'active_record/acts/tree'
require 'active_record/acts/list'
require 'active_record/acts/nested_set'
require 'fixtures/mixin'

# Let us control what Time.now returns for the TouchTest suite
class Time
  @@forced_now_time = nil
  cattr_accessor :forced_now_time
  
  class << self
    def now_with_forcing
      if @@forced_now_time
        @@forced_now_time
      else
        now_without_forcing
      end
    end
    alias_method_chain :now, :forcing
  end
end

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

  def test_move_to_bottom_with_next_to_last_item
    assert_equal [mixins(:list_1),
                  mixins(:list_2),
                  mixins(:list_3),
                  mixins(:list_4)],
                  ListMixin.find(:all, :conditions => 'parent_id = 5', :order => 'pos')

    mixins(:list_3).move_to_bottom

    assert_equal [mixins(:list_1),
                  mixins(:list_2),
                  mixins(:list_4),
                  mixins(:list_3)],
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

    new5 = ListMixin.create("parent_id" => 20)
    assert_equal 5, new5.pos

    new5.insert_at(1)
    assert_equal 1, new5.pos

    new4.reload
    assert_equal 5, new4.pos
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
    assert_deprecated 'has_children?' do
      assert_equal true, mixins(:tree_1).has_children?
      assert_equal true, mixins(:tree_2).has_children?
      assert_equal false, mixins(:tree_3).has_children?
      assert_equal false, mixins(:tree_4).has_children?
    end
  end

  def test_children
    assert_equal mixins(:tree_1).children, [mixins(:tree_2), mixins(:tree_4)]
    assert_equal mixins(:tree_2).children, [mixins(:tree_3)]
    assert_equal mixins(:tree_3).children, []
    assert_equal mixins(:tree_4).children, []
  end

  def test_has_parent
    assert_deprecated 'has_parent?' do
      assert_equal false, mixins(:tree_1).has_parent?
      assert_equal true, mixins(:tree_2).has_parent?
      assert_equal true, mixins(:tree_3).has_parent?
      assert_equal true, mixins(:tree_4).has_parent?
    end
  end

  def test_parent
    assert_equal mixins(:tree_2).parent, mixins(:tree_1)
    assert_equal mixins(:tree_2).parent, mixins(:tree_4).parent
    assert_nil mixins(:tree_1).parent
  end

  def test_delete
    assert_equal 6, TreeMixin.count
    mixins(:tree_1).destroy
    assert_equal 2, TreeMixin.count
    mixins(:tree2_1).destroy
    mixins(:tree3_1).destroy
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

  def test_ancestors
    assert_equal [], mixins(:tree_1).ancestors
    assert_equal [mixins(:tree_1)], mixins(:tree_2).ancestors
    assert_equal [mixins(:tree_2), mixins(:tree_1)], mixins(:tree_3).ancestors
    assert_equal [mixins(:tree_1)], mixins(:tree_4).ancestors
    assert_equal [], mixins(:tree2_1).ancestors
    assert_equal [], mixins(:tree3_1).ancestors
  end

  def test_root
    assert_equal mixins(:tree_1), TreeMixin.root
    assert_equal mixins(:tree_1), mixins(:tree_1).root
    assert_equal mixins(:tree_1), mixins(:tree_2).root
    assert_equal mixins(:tree_1), mixins(:tree_3).root
    assert_equal mixins(:tree_1), mixins(:tree_4).root
    assert_equal mixins(:tree2_1), mixins(:tree2_1).root
    assert_equal mixins(:tree3_1), mixins(:tree3_1).root
  end

  def test_roots
    assert_equal [mixins(:tree_1), mixins(:tree2_1), mixins(:tree3_1)], TreeMixin.roots
  end

  def test_siblings
    assert_equal [mixins(:tree2_1), mixins(:tree3_1)], mixins(:tree_1).siblings
    assert_equal [mixins(:tree_4)], mixins(:tree_2).siblings
    assert_equal [], mixins(:tree_3).siblings
    assert_equal [mixins(:tree_2)], mixins(:tree_4).siblings
    assert_equal [mixins(:tree_1), mixins(:tree3_1)], mixins(:tree2_1).siblings
    assert_equal [mixins(:tree_1), mixins(:tree2_1)], mixins(:tree3_1).siblings
  end

  def test_self_and_siblings
    assert_equal [mixins(:tree_1), mixins(:tree2_1), mixins(:tree3_1)], mixins(:tree_1).self_and_siblings
    assert_equal [mixins(:tree_2), mixins(:tree_4)], mixins(:tree_2).self_and_siblings
    assert_equal [mixins(:tree_3)], mixins(:tree_3).self_and_siblings
    assert_equal [mixins(:tree_2), mixins(:tree_4)], mixins(:tree_4).self_and_siblings
    assert_equal [mixins(:tree_1), mixins(:tree2_1), mixins(:tree3_1)], mixins(:tree2_1).self_and_siblings
    assert_equal [mixins(:tree_1), mixins(:tree2_1), mixins(:tree3_1)], mixins(:tree3_1).self_and_siblings
  end
end

class TreeTestWithoutOrder < Test::Unit::TestCase
  fixtures :mixins

  def test_root
    assert [mixins(:tree_without_order_1), mixins(:tree_without_order_2)].include?(TreeMixinWithoutOrder.root)
  end

  def test_roots
    assert_equal [], [mixins(:tree_without_order_1), mixins(:tree_without_order_2)] - TreeMixinWithoutOrder.roots
  end
end

class TouchTest < Test::Unit::TestCase
  fixtures :mixins
  
  def setup
    Time.forced_now_time = Time.now
  end
  
  def teardown
    Time.forced_now_time = nil
  end

  def test_time_mocking
    five_minutes_ago = 5.minutes.ago
    Time.forced_now_time = five_minutes_ago
    assert_equal five_minutes_ago, Time.now
    
    Time.forced_now_time = nil
    assert_not_equal five_minutes_ago, Time.now
  end

  def test_update
    stamped = Mixin.new

    assert_nil stamped.updated_at
    assert_nil stamped.created_at
    stamped.save
    assert_equal Time.now, stamped.updated_at
    assert_equal Time.now, stamped.created_at
  end

  def test_create
    obj = Mixin.create
    assert_equal Time.now, obj.updated_at
    assert_equal Time.now, obj.created_at
  end

  def test_many_updates
    stamped = Mixin.new

    assert_nil stamped.updated_at
    assert_nil stamped.created_at
    stamped.save
    assert_equal Time.now, stamped.created_at
    assert_equal Time.now, stamped.updated_at

    old_updated_at = stamped.updated_at

    Time.forced_now_time = 5.minutes.from_now
    stamped.save

    assert_equal Time.now, stamped.updated_at
    assert_equal old_updated_at, stamped.created_at
  end

  def test_create_turned_off
    Mixin.record_timestamps = false

    assert_nil mixins(:tree_1).updated_at
    mixins(:tree_1).save
    assert_nil mixins(:tree_1).updated_at

    Mixin.record_timestamps = true
  end

end


class ListSubTest < Test::Unit::TestCase
  fixtures :mixins

  def test_reordering
    assert_equal [mixins(:list_sub_1),
                  mixins(:list_sub_2),
                  mixins(:list_sub_3),
                  mixins(:list_sub_4)],
                  ListMixin.find(:all, :conditions => 'parent_id = 5000', :order => 'pos')

    mixins(:list_sub_2).move_lower

    assert_equal [mixins(:list_sub_1),
                  mixins(:list_sub_3),
                  mixins(:list_sub_2),
                  mixins(:list_sub_4)],
                  ListMixin.find(:all, :conditions => 'parent_id = 5000', :order => 'pos')

    mixins(:list_sub_2).move_higher

    assert_equal [mixins(:list_sub_1),
                  mixins(:list_sub_2),
                  mixins(:list_sub_3),
                  mixins(:list_sub_4)],
                  ListMixin.find(:all, :conditions => 'parent_id = 5000', :order => 'pos')

    mixins(:list_sub_1).move_to_bottom

    assert_equal [mixins(:list_sub_2),
                  mixins(:list_sub_3),
                  mixins(:list_sub_4),
                  mixins(:list_sub_1)],
                  ListMixin.find(:all, :conditions => 'parent_id = 5000', :order => 'pos')

    mixins(:list_sub_1).move_to_top

    assert_equal [mixins(:list_sub_1),
                  mixins(:list_sub_2),
                  mixins(:list_sub_3),
                  mixins(:list_sub_4)],
                  ListMixin.find(:all, :conditions => 'parent_id = 5000', :order => 'pos')


    mixins(:list_sub_2).move_to_bottom

    assert_equal [mixins(:list_sub_1),
                  mixins(:list_sub_3),
                  mixins(:list_sub_4),
                  mixins(:list_sub_2)],
                  ListMixin.find(:all, :conditions => 'parent_id = 5000', :order => 'pos')

    mixins(:list_sub_4).move_to_top

    assert_equal [mixins(:list_sub_4),
                  mixins(:list_sub_1),
                  mixins(:list_sub_3),
                  mixins(:list_sub_2)],
                  ListMixin.find(:all, :conditions => 'parent_id = 5000', :order => 'pos')

  end

  def test_move_to_bottom_with_next_to_last_item
    assert_equal [mixins(:list_sub_1),
                  mixins(:list_sub_2),
                  mixins(:list_sub_3),
                  mixins(:list_sub_4)],
                  ListMixin.find(:all, :conditions => 'parent_id = 5000', :order => 'pos')

    mixins(:list_sub_3).move_to_bottom

    assert_equal [mixins(:list_sub_1),
                  mixins(:list_sub_2),
                  mixins(:list_sub_4),
                  mixins(:list_sub_3)],
                  ListMixin.find(:all, :conditions => 'parent_id = 5000', :order => 'pos')
  end

  def test_next_prev
    assert_equal mixins(:list_sub_2), mixins(:list_sub_1).lower_item
    assert_nil mixins(:list_sub_1).higher_item
    assert_equal mixins(:list_sub_3), mixins(:list_sub_4).higher_item
    assert_nil mixins(:list_sub_4).lower_item
  end


  def test_injection
    item = ListMixin.new("parent_id"=>1)
    assert_equal "parent_id = 1", item.scope_condition
    assert_equal "pos", item.position_column
  end


  def test_insert_at
    new = ListMixin.create("parent_id" => 20)
    assert_equal 1, new.pos

    new = ListMixinSub1.create("parent_id" => 20)
    assert_equal 2, new.pos

    new = ListMixinSub2.create("parent_id" => 20)
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

    new5 = ListMixinSub1.create("parent_id" => 20)
    assert_equal 5, new5.pos

    new5.insert_at(1)
    assert_equal 1, new5.pos

    new4.reload
    assert_equal 5, new4.pos
  end

  def test_delete_middle
    assert_equal [mixins(:list_sub_1),
                  mixins(:list_sub_2),
                  mixins(:list_sub_3),
                  mixins(:list_sub_4)],
                  ListMixin.find(:all, :conditions => 'parent_id = 5000', :order => 'pos')

    mixins(:list_sub_2).destroy

    assert_equal [mixins(:list_sub_1, :reload),
                  mixins(:list_sub_3, :reload),
                  mixins(:list_sub_4, :reload)],
                  ListMixin.find(:all, :conditions => 'parent_id = 5000', :order => 'pos')

    assert_equal 1, mixins(:list_sub_1).pos
    assert_equal 2, mixins(:list_sub_3).pos
    assert_equal 3, mixins(:list_sub_4).pos

    mixins(:list_sub_1).destroy

    assert_equal [mixins(:list_sub_3, :reload),
                  mixins(:list_sub_4, :reload)],
                  ListMixin.find(:all, :conditions => 'parent_id = 5000', :order => 'pos')

    assert_equal 1, mixins(:list_sub_3).pos
    assert_equal 2, mixins(:list_sub_4).pos

  end

end

