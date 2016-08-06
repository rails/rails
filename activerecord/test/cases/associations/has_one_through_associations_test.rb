require "cases/helper"
require "models/club"
require "models/member_type"
require "models/member"
require "models/membership"
require "models/sponsor"
require "models/organization"
require "models/member_detail"
require "models/minivan"
require "models/dashboard"
require "models/speedometer"
require "models/category"
require "models/author"
require "models/essay"
require "models/owner"
require "models/post"
require "models/comment"
require "models/categorization"
require "models/customer"
require "models/carrier"
require "models/shop_account"
require "models/customer_carrier"

class HasOneThroughAssociationsTest < ActiveRecord::TestCase
  fixtures :member_types, :members, :clubs, :memberships, :sponsors, :organizations, :minivans,
           :dashboards, :speedometers, :authors, :posts, :comments, :categories, :essays, :owners

  def setup
    @member = members(:groucho)
  end

  def test_has_one_through_with_has_one
    assert_equal clubs(:boring_club), @member.club
  end

  def test_creating_association_creates_through_record
    new_member = Member.create(:name => "Chris")
    new_member.club = Club.create(:name => "LRUG")
    assert_not_nil new_member.current_membership
    assert_not_nil new_member.club
  end

  def test_creating_association_builds_through_record_for_new
    new_member = Member.new(:name => "Jane")
    new_member.club = clubs(:moustache_club)
    assert new_member.current_membership
    assert_equal clubs(:moustache_club), new_member.current_membership.club
    assert_equal clubs(:moustache_club), new_member.club
    assert new_member.save
    assert_equal clubs(:moustache_club), new_member.club
  end

  def test_creating_association_sets_both_parent_ids_for_new
    member = Member.new(name: "Sean Griffin")
    club = Club.new(name: "Da Club")

    member.club = club

    member.save!

    assert member.id
    assert club.id
    assert_equal member.id, member.current_membership.member_id
    assert_equal club.id, member.current_membership.club_id
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

  def test_has_one_through_eager_loading
    members = assert_queries(3) do #base table, through table, clubs table
      Member.all.merge!(:includes => :club, :where => ["name = ?", "Groucho Marx"]).to_a
    end
    assert_equal 1, members.size
    assert_not_nil assert_no_queries {members[0].club}
  end

  def test_has_one_through_eager_loading_through_polymorphic
    members = assert_queries(3) do #base table, through table, clubs table
      Member.all.merge!(:includes => :sponsor_club, :where => ["name = ?", "Groucho Marx"]).to_a
    end
    assert_equal 1, members.size
    assert_not_nil assert_no_queries {members[0].sponsor_club}
  end

  def test_has_one_through_with_conditions_eager_loading
    # conditions on the through table
    assert_equal clubs(:moustache_club), Member.all.merge!(:includes => :favourite_club).find(@member.id).favourite_club
    memberships(:membership_of_favourite_club).update_columns(favourite: false)
    assert_equal nil,                    Member.all.merge!(:includes => :favourite_club).find(@member.id).reload.favourite_club

    # conditions on the source table
    assert_equal clubs(:moustache_club), Member.all.merge!(:includes => :hairy_club).find(@member.id).hairy_club
    clubs(:moustache_club).update_columns(name: "Association of Clean-Shaven Persons")
    assert_equal nil,                    Member.all.merge!(:includes => :hairy_club).find(@member.id).reload.hairy_club
  end

  def test_has_one_through_polymorphic_with_source_type
    assert_equal members(:groucho), clubs(:moustache_club).sponsored_member
  end

  def test_eager_has_one_through_polymorphic_with_source_type
    clubs = Club.all.merge!(:includes => :sponsored_member, :where => ["name = ?","Moustache and Eyebrow Fancier Club"]).to_a
    # Only the eyebrow fanciers club has a sponsored_member
    assert_not_nil assert_no_queries {clubs[0].sponsored_member}
  end

  def test_has_one_through_nonpreload_eagerloading
    members = assert_queries(1) do
      Member.all.merge!(:includes => :club, :where => ["members.name = ?", "Groucho Marx"], :order => "clubs.name").to_a #force fallback
    end
    assert_equal 1, members.size
    assert_not_nil assert_no_queries {members[0].club}
  end

  def test_has_one_through_nonpreload_eager_loading_through_polymorphic
    members = assert_queries(1) do
      Member.all.merge!(:includes => :sponsor_club, :where => ["members.name = ?", "Groucho Marx"], :order => "clubs.name").to_a #force fallback
    end
    assert_equal 1, members.size
    assert_not_nil assert_no_queries {members[0].sponsor_club}
  end

  def test_has_one_through_nonpreload_eager_loading_through_polymorphic_with_more_than_one_through_record
    Sponsor.new(:sponsor_club => clubs(:crazy_club), :sponsorable => members(:groucho)).save!
    members = assert_queries(1) do
      Member.all.merge!(:includes => :sponsor_club, :where => ["members.name = ?", "Groucho Marx"], :order => "clubs.name DESC").to_a #force fallback
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
    assert_equal new_club, new_member.association(:club).target
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
    assert_difference "MemberDetail.count", 1 do
      @member_detail = MemberDetail.new(:extra_data => "Extra")
      @member.member_detail = @member_detail
      @member.organization = @organization
    end
    assert_equal @organization, @member.organization
    assert @organization.members.include?(@member)
    assert_equal "Extra", @member.member_detail.extra_data
  end

  def test_reassigning_has_one_through
    @organization = organizations(:nsa)
    @new_organization = organizations(:discordians)

    assert_difference "MemberDetail.count", 1 do
      @member_detail = MemberDetail.new(:extra_data => "Extra")
      @member.member_detail = @member_detail
      @member.organization = @organization
    end
    assert_equal @organization, @member.organization
    assert_equal "Extra", @member.member_detail.extra_data
    assert @organization.members.include?(@member)
    assert !@new_organization.members.include?(@member)

    assert_no_difference "MemberDetail.count" do
      @member.organization = @new_organization
    end
    assert_equal @new_organization, @member.organization
    assert_equal "Extra", @member.member_detail.extra_data
    assert !@organization.members.include?(@member)
    assert @new_organization.members.include?(@member)
  end

  def test_preloading_has_one_through_on_belongs_to
    MemberDetail.delete_all
    assert_not_nil @member.member_type
    @organization = organizations(:nsa)
    @member_detail = MemberDetail.new
    @member.member_detail = @member_detail
    @member.organization = @organization
    @member_details = assert_queries(3) do
      MemberDetail.all.merge!(:includes => :member_type).to_a
    end
    @new_detail = @member_details[0]
    assert @new_detail.send(:association, :member_type).loaded?
    assert_no_queries { @new_detail.member_type }
  end

  def test_save_of_record_with_loaded_has_one_through
    @club = @member.club
    assert_not_nil @club.sponsored_member

    assert_nothing_raised do
      Club.find(@club.id).save!
      Club.all.merge!(:includes => :sponsored_member).find(@club.id).save!
    end

    @club.sponsor.destroy

    assert_nothing_raised do
      Club.find(@club.id).save!
      Club.all.merge!(:includes => :sponsored_member).find(@club.id).save!
    end
  end

  def test_through_belongs_to_after_destroy
    @member_detail = MemberDetail.new(:extra_data => "Extra")
    @member.member_detail = @member_detail
    @member.save!

    assert_not_nil @member_detail.member_type
    @member_detail.destroy
    assert_queries(1) do
      @member_detail.association(:member_type).reload
      assert_not_nil @member_detail.member_type
    end

    @member_detail.member.destroy
    assert_queries(1) do
      @member_detail.association(:member_type).reload
      assert_nil @member_detail.member_type
    end
  end

  def test_value_is_properly_quoted
    minivan = Minivan.find("m1")
    assert_nothing_raised do
      minivan.dashboard
    end
  end

  def test_has_one_through_polymorphic_with_primary_key_option
    assert_equal categories(:general), authors(:david).essay_category

    authors = Author.joins(:essay_category).where("categories.id" => categories(:general).id)
    assert_equal authors(:david), authors.first

    assert_equal owners(:blackbeard), authors(:david).essay_owner

    authors = Author.joins(:essay_owner).where("owners.name = 'blackbeard'")
    assert_equal authors(:david), authors.first
  end

  def test_has_one_through_with_primary_key_option
    assert_equal categories(:general), authors(:david).essay_category_2

    authors = Author.joins(:essay_category_2).where("categories.id" => categories(:general).id)
    assert_equal authors(:david), authors.first
  end

  def test_has_one_through_with_default_scope_on_join_model
    assert_equal posts(:welcome).comments.order("id").first, authors(:david).comment_on_first_post
  end

  def test_has_one_through_many_raises_exception
    assert_raise(ActiveRecord::HasOneThroughCantAssociateThroughCollection) do
      members(:groucho).club_through_many
    end
  end

  def test_has_one_through_polymorphic_association
    assert_raise(ActiveRecord::HasOneAssociationPolymorphicThroughError) do
      @member.premium_club
    end
  end

  def test_has_one_through_belongs_to_should_update_when_the_through_foreign_key_changes
    minivan = minivans(:cool_first)

    minivan.dashboard
    proxy = minivan.send(:association_instance_get, :dashboard)

    assert !proxy.stale_target?
    assert_equal dashboards(:cool_first), minivan.dashboard

    minivan.speedometer_id = speedometers(:second).id

    assert proxy.stale_target?
    assert_equal dashboards(:second), minivan.dashboard
  end

  def test_has_one_through_belongs_to_setting_belongs_to_foreign_key_after_nil_target_loaded
    minivan = Minivan.new

    minivan.dashboard
    proxy = minivan.send(:association_instance_get, :dashboard)

    minivan.speedometer_id = speedometers(:second).id

    assert proxy.stale_target?
    assert_equal dashboards(:second), minivan.dashboard
  end

  def test_assigning_has_one_through_belongs_to_with_new_record_owner
    minivan   = Minivan.new
    dashboard = dashboards(:cool_first)

    minivan.dashboard = dashboard

    assert_equal dashboard, minivan.dashboard
    assert_equal dashboard, minivan.speedometer.dashboard
  end

  def test_has_one_through_with_custom_select_on_join_model_default_scope
    assert_equal clubs(:boring_club), members(:groucho).selected_club
  end

  def test_has_one_through_relationship_cannot_have_a_counter_cache
    assert_raise(ArgumentError) do
      Class.new(ActiveRecord::Base) do
        has_one :thing, through: :other_thing, counter_cache: true
      end
    end
  end

  def test_has_one_through_do_not_cache_association_reader_if_the_though_method_has_default_scopes
    customer = Customer.create!
    carrier = Carrier.create!
    customer_carrier = CustomerCarrier.create!(
      customer: customer,
      carrier: carrier,
    )
    account = ShopAccount.create!(customer_carrier: customer_carrier)

    CustomerCarrier.current_customer = customer

    account_carrier = account.carrier
    assert_equal carrier, account_carrier

    CustomerCarrier.current_customer = nil

    other_carrier = Carrier.create!
    other_customer = Customer.create!
    other_customer_carrier = CustomerCarrier.create!(
      customer: other_customer,
      carrier: other_carrier,
    )
    other_account = ShopAccount.create!(customer_carrier: other_customer_carrier)

    account_carrier = other_account.carrier
    assert_equal other_carrier, account_carrier
  ensure
    CustomerCarrier.current_customer = nil
  end
end
