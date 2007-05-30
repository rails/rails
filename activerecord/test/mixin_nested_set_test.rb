require 'abstract_unit'
require 'active_record/acts/nested_set'
require 'fixtures/mixin'
require 'pp'

class MixinNestedSetTest < Test::Unit::TestCase
	fixtures :mixins
                             
	def test_mixing_in_methods
	  ns = NestedSet.new
		assert( ns.respond_to?( :all_children ) )
		assert_equal( ns.scope_condition, "root_id IS NULL" )
		
		check_method_mixins ns
	end
	
	def test_string_scope
	  ns = NestedSetWithStringScope.new
	  
	  ns.root_id = 1
	  assert_equal( ns.scope_condition, "root_id = 1" )
	  ns.root_id = 42
	  assert_equal( ns.scope_condition, "root_id = 42" )
	  check_method_mixins ns
  end
  
  def test_symbol_scope
    ns = NestedSetWithSymbolScope.new
    ns.root_id = 1
    assert_equal( ns.scope_condition, "root_id = 1" )
    ns.root_id = 42
    assert_equal( ns.scope_condition, "root_id = 42" )
    check_method_mixins ns
  end
  
  def check_method_mixins( obj )
    [:scope_condition, :left_col_name, :right_col_name, :parent_column, :root?, :add_child,
    :children_count, :full_set, :all_children, :direct_children].each { |symbol| assert( obj.respond_to?(symbol)) }
  end

  def set( id )
    NestedSet.find( 3000 + id )
  end
  
  def test_adding_children
    assert( set(1).unknown? )
    assert( set(2).unknown? )
    set(1).add_child set(2)
    
    # Did we maintain adding the parent_ids?
    assert( set(1).root? )
    assert( set(2).child? )
    assert( set(2).parent_id == set(1).id )
    
    # Check boundies
    assert_equal( set(1).lft, 1 )
    assert_equal( set(2).lft, 2 )
    assert_equal( set(2).rgt, 3 )
    assert_equal( set(1).rgt, 4 )
    
    # Check children cound
    assert_equal( set(1).children_count, 1 )
    
    set(1).add_child set(3)
    
    #check boundries
    assert_equal( set(1).lft, 1 )
    assert_equal( set(2).lft, 2 )
    assert_equal( set(2).rgt, 3 )
    assert_equal( set(3).lft, 4 )
    assert_equal( set(3).rgt, 5 )
    assert_equal( set(1).rgt, 6 )
    
    # How is the count looking?
    assert_equal( set(1).children_count, 2 )

    set(2).add_child set(4)

    # boundries
    assert_equal( set(1).lft, 1 )
    assert_equal( set(2).lft, 2 )
    assert_equal( set(4).lft, 3 )
    assert_equal( set(4).rgt, 4 )
    assert_equal( set(2).rgt, 5 )
    assert_equal( set(3).lft, 6 )
    assert_equal( set(3).rgt, 7 )
    assert_equal( set(1).rgt, 8 )
    
    # Children count
    assert_equal( set(1).children_count, 3 )
    assert_equal( set(2).children_count, 1 )
    assert_equal( set(3).children_count, 0 )
    assert_equal( set(4).children_count, 0 )
    
    set(2).add_child set(5)
    set(4).add_child set(6)
    
    assert_equal( set(2).children_count, 3 )


    # Children accessors
    assert_equal( set(1).full_set.length, 6 )
    assert_equal( set(2).full_set.length, 4 )
    assert_equal( set(4).full_set.length, 2 )
    
    assert_equal( set(1).all_children.length, 5 )
    assert_equal( set(6).all_children.length, 0 )
    
    assert_equal( set(1).direct_children.length, 2 )
    
  end

  def test_snipping_tree
    big_tree = NestedSetWithStringScope.find( 4001 )
    
    # Make sure we have the right one
    assert_equal( 3, big_tree.direct_children.length )
    assert_equal( 10, big_tree.full_set.length )
    assert_equal [4002, 4008, 4005], big_tree.direct_children.map(&:id)
    
    NestedSetWithStringScope.find( 4005 ).destroy

    big_tree = NestedSetWithStringScope.find( 4001 )
    
    assert_equal( 9, big_tree.full_set.length )
    assert_equal( 2, big_tree.direct_children.length )
    
    assert_equal( 1, NestedSetWithStringScope.find(4001).lft )
    assert_equal( 2, NestedSetWithStringScope.find(4002).lft )
    assert_equal( 3, NestedSetWithStringScope.find(4003).lft )
    assert_equal( 4, NestedSetWithStringScope.find(4003).rgt )
    assert_equal( 5, NestedSetWithStringScope.find(4004).lft )
    assert_equal( 6, NestedSetWithStringScope.find(4004).rgt )
    assert_equal( 7, NestedSetWithStringScope.find(4002).rgt )
    assert_equal( 8, NestedSetWithStringScope.find(4008).lft )
    assert_equal(15, NestedSetWithStringScope.find(4009).lft )
    assert_equal(16, NestedSetWithStringScope.find(4009).rgt )
    assert_equal(17, NestedSetWithStringScope.find(4010).lft )
    assert_equal(18, NestedSetWithStringScope.find(4010).rgt )
    assert_equal(19, NestedSetWithStringScope.find(4008).rgt )
    assert_equal(20, NestedSetWithStringScope.find(4001).rgt )
  end
  
  def test_deleting_root
    NestedSetWithStringScope.find(4001).destroy
    
    assert( NestedSetWithStringScope.count == 0 )
  end            
                               
  def test_common_usage
    mixins(:set_1).add_child( mixins(:set_2) )
    assert_equal( 1, mixins(:set_1).direct_children.length )

    mixins(:set_2).add_child( mixins(:set_3) )                      
    assert_equal( 1, mixins(:set_1).direct_children.length )     
    
    # Local cache is now out of date!
    # Problem: the update_alls update all objects up the tree
    mixins(:set_1).reload
    assert_equal( 2, mixins(:set_1).all_children.length )              
    
    assert_equal( 1, mixins(:set_1).lft )
    assert_equal( 2, mixins(:set_2).lft )
    assert_equal( 3, mixins(:set_3).lft )
    assert_equal( 4, mixins(:set_3).rgt )
    assert_equal( 5, mixins(:set_2).rgt )
    assert_equal( 6, mixins(:set_1).rgt )
          
    assert( mixins(:set_1).root? )
                  
    begin
      mixins(:set_4).add_child( mixins(:set_1) )
      fail
    rescue
    end
    
    assert_equal( 2, mixins(:set_1).all_children.length )
    
    mixins(:set_1).add_child mixins(:set_4)

    assert_equal( 3, mixins(:set_1).all_children.length )
  end
  
  def test_inheritance
    parent = mixins(:sti_set_3100)
    child = mixins(:sti_set_3101)
    grandchild = mixins(:sti_set_3102)
    assert_equal 5, parent.full_set.size
    assert_equal 2, child.full_set.size
    assert_equal 4, parent.all_children.size
    assert_equal 1, child.all_children.size
    assert_equal 2, parent.direct_children.size
    assert_equal 1, child.direct_children.size
    child.destroy
    assert_equal 3, parent.full_set.size
  end
end
