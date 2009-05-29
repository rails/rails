require "cases/helper"
require 'models/club'
require 'models/member_type'
require 'models/member'
require 'models/membership'
require 'models/sponsor'
require 'models/organization'
require 'models/member_detail'

class HasOneThroughAssociationsTest < ActiveRecord::TestCase
  fixtures :member_types, :members, :clubs, :memberships, :sponsors, :organizations
  
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

  def test_set_record_to_nil_should_delete_association
    @member.club = nil
    @member.reload
    assert_equal nil, @member.current_membership
    assert_nil @member.club
  end

  def test_has_one_through_polymorphic
    assert_equal clubs(:moustache_club), @member.sponsor_club
  end

  def has_one_through_to_has_many
    assert_equal 2, @member.fellow_members.size
  end

  def test_has_one_through_eager_loading
    members = assert_queries(3) do #base table, through table, clubs table
      Member.find(:all, :include => :club, :conditions => ["name = ?", "Groucho Marx"])
    end
    assert_equal 1, members.size
    assert_not_nil assert_no_queries {members[0].club}
  end

  def test_has_one_through_eager_loading_through_polymorphic
    members = assert_queries(3) do #base table, through table, clubs table
      Member.find(:all, :include => :sponsor_club, :conditions => ["name = ?", "Groucho Marx"])
    end
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

  def test_has_one_through_nonpreload_eagerloading
    members = assert_queries(1) do
      Member.find(:all, :include => :club, :conditions => ["members.name = ?", "Groucho Marx"], :order => 'clubs.name') #force fallback
    end
    assert_equal 1, members.size
    assert_not_nil assert_no_queries {members[0].club}
  end

  def test_has_one_through_nonpreload_eager_loading_through_polymorphic
    members = assert_queries(1) do
      Member.find(:all, :include => :sponsor_club, :conditions => ["members.name = ?", "Groucho Marx"], :order => 'clubs.name') #force fallback
    end
    assert_equal 1, members.size
    assert_not_nil assert_no_queries {members[0].sponsor_club}
  end

  def test_has_one_through_nonpreload_eager_loading_through_polymorphic_with_more_than_one_through_record
    Sponsor.new(:sponsor_club => clubs(:crazy_club), :sponsorable => members(:groucho)).save!
    members = assert_queries(1) do
      Member.find(:all, :include => :sponsor_club, :conditions => ["members.name = ?", "Groucho Marx"], :order => 'clubs.name DESC') #force fallback
    end
    assert_equal 1, members.size
    assert_not_nil assert_no_queries { members[0].sponsor_club }
    assert_equal clubs(:crazy_club), members[0].sponsor_club
  end

  def test_uninitialized_has_one_through_should_return_nil_for_unsaved_record
    assert_nil Member.new.club
  end

  def test_assigning_association_correctly_assigns_target
    new_member = Member.create(:name => "Chris")
    new_member.club = new_club = Club.create(:name => "LRUG")
    assert_equal new_club, new_member.club.target
  end

  def test_has_one_through_proxy_should_not_respond_to_private_methods
    assert_raise(NoMethodError) { clubs(:moustache_club).private_method }
    assert_raise(NoMethodError) { @member.club.private_method }
  end

  def test_has_one_through_proxy_should_respond_to_private_methods_via_send
    clubs(:moustache_club).send(:private_method)
    @member.club.send(:private_method)
  end

  def test_assigning_to_has_one_through_preserves_decorated_join_record
    @organization = organizations(:nsa)
    assert_difference 'MemberDetail.count', 1 do
      @member_detail = MemberDetail.new(:extra_data => 'Extra')
      @member.member_detail = @member_detail
      @member.organization = @organization
    end
    assert_equal @organization, @member.organization
    assert @organization.members.include?(@member)
    assert_equal 'Extra', @member.member_detail.extra_data
  end

  def test_reassigning_has_one_through
    @organization = organizations(:nsa)
    @new_organization = organizations(:discordians)

    assert_difference 'MemberDetail.count', 1 do
      @member_detail = MemberDetail.new(:extra_data => 'Extra')
      @member.member_detail = @member_detail
      @member.organization = @organization
    end
    assert_equal @organization, @member.organization
    assert_equal 'Extra', @member.member_detail.extra_data
    assert @organization.members.include?(@member)
    assert !@new_organization.members.include?(@member)

    assert_no_difference 'MemberDetail.count' do
      @member.organization = @new_organization
    end
    assert_equal @new_organization, @member.organization
    assert_equal 'Extra', @member.member_detail.extra_data
    assert !@organization.members.include?(@member)
    assert @new_organization.members.include?(@member)
  end

  def test_preloading_has_one_through_on_belongs_to
    assert_not_nil @member.member_type
    @organization = organizations(:nsa)
    @member_detail = MemberDetail.new
    @member.member_detail = @member_detail
    @member.organization = @organization
    @member_details = assert_queries(3) do
      MemberDetail.find(:all, :include => :member_type)
    end
    @new_detail = @member_details[0]
    assert @new_detail.loaded_member_type?
    assert_not_nil assert_no_queries { @new_detail.member_type }
  end

  def test_save_of_record_with_loaded_has_one_through
    @club = @member.club
    assert_not_nil @club.sponsored_member

    assert_nothing_raised do
      Club.find(@club.id).save!
      Club.find(@club.id, :include => :sponsored_member).save!
    end

    @club.sponsor.destroy

    assert_nothing_raised do
      Club.find(@club.id).save!
      Club.find(@club.id, :include => :sponsored_member).save!
    end
  end
end
