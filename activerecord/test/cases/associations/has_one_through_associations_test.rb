require "cases/helper"
require 'models/club'
require 'models/member'
require 'models/membership'
require 'models/sponsor'

class HasOneThroughAssociationsTest < ActiveRecord::TestCase
  fixtures :members, :clubs, :memberships, :sponsors
  
  def setup
    @member = members(:groucho)
  end

  def test_has_one_through_with_has_one
    assert_equal clubs(:boring_club), @member.club
  end

  def test_has_one_through_with_has_many
    assert_equal clubs(:moustache_club), @member.favourite_club
  end
  
  def test_creating_association_creates_through_record
    new_member = Member.create(:name => "Chris")
    new_member.club = Club.create(:name => "LRUG")
    assert_not_nil new_member.current_membership
    assert_not_nil new_member.club
  end
  
  def test_replace_target_record
    new_club = Club.create(:name => "Marx Bros")
    @member.club = new_club
    @member.reload
    assert_equal new_club, @member.club
  end
  
  def test_replacing_target_record_deletes_old_association
    assert_no_difference "Membership.count" do
      new_club = Club.create(:name => "Bananarama")
      @member.club = new_club
      @member.reload      
    end
  end
  
  def test_has_one_through_polymorphic
    assert_equal clubs(:moustache_club), @member.sponsor_club
  end
  
  def has_one_through_to_has_many
    assert_equal 2, @member.fellow_members.size
  end
  
  def test_has_one_through_eager_loading
    members = Member.find(:all, :include => :club, :conditions => ["name = ?", "Groucho Marx"])
    assert_equal 1, members.size
    assert_not_nil assert_no_queries {members[0].club}
  end
  
  def test_has_one_through_eager_loading_through_polymorphic
    members = Member.find(:all, :include => :sponsor_club, :conditions => ["name = ?", "Groucho Marx"])
    assert_equal 1, members.size
    assert_not_nil assert_no_queries {members[0].sponsor_club}    
  end

  def test_has_one_through_polymorphic_with_source_type
    assert_equal members(:groucho), clubs(:moustache_club).sponsored_member
  end

  def test_eager_has_one_through_polymorphic_with_source_type
    clubs = Club.find(:all, :include => :sponsored_member, :conditions => ["name = ?","Moustache and Eyebrow Fancier Club"])
    # Only the eyebrow fanciers club has a sponsored_member
    assert_not_nil assert_no_queries {clubs[0].sponsored_member}
  end

end
