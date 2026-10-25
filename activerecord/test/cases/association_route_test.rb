# frozen_string_literal: true

require "cases/helper"
require "active_support/core_ext/object/with"
require "active_support/testing/ractors_assertions"
require "models/company"
require "models/member"
require "models/sponsor"
require "models/author"
require "models/comment"
require "models/post"
require "models/ship"

class AssociationRouteTest < ActiveRecord::TestCase
  include ActiveSupport::Testing::RactorsAssertions

  fixtures :posts

  class AliasedRouteComment < ActiveRecord::Base
    self.table_name = "comments"
    self.inheritance_column = nil

    alias_attribute :route_fk, :post_id

    belongs_to :routed_post, class_name: "Post", foreign_key: :route_fk, optional: true
  end

  class ConstrainedRouteMember < ActiveRecord::Base
    self.table_name = "members"

    has_one :routed_sponsor,
      -> { order(:id) },
      as: :sponsorable,
      class_name: "Sponsor"
  end

  class ConstrainedRoutePost < ActiveRecord::Base
    self.table_name = "posts"
    self.inheritance_column = nil

    has_many :route_links,
      class_name: "AssociationRouteTest::ConstrainedRouteLink",
      foreign_key: :sponsorable_id
    has_many :route_ships, through: :route_links, source: :ship
  end

  class ConstrainedRouteLink < ActiveRecord::Base
    self.table_name = "sponsors"

    belongs_to :ship,
      class_name: "Ship",
      foreign_key: :club_id,
      primary_key: :pirate_id,
      optional: true
  end

  class ArrayRouteRecord < ActiveRecord::Base
    self.table_name = "bigint_array"

    belongs_to :same_array,
      class_name: "AssociationRouteTest::ArrayRouteRecord",
      foreign_key: [:big_int_data_points],
      primary_key: [:big_int_data_points],
      optional: true
  end

  class DecoupledRoutePost < ActiveRecord::Base
    self.table_name = "posts"
    self.inheritance_column = nil

    has_many :decoupled_comments,
      class_name: "AssociationRouteTest::DecoupledRouteComment",
      foreign_key: :post_id,
      query_constraints: :author_id
    has_many :body_matched_comments,
      class_name: "AssociationRouteTest::DecoupledRouteComment",
      foreign_key: :post_id,
      query_constraints: { title: :body }
  end

  class DecoupledRouteComment < ActiveRecord::Base
    self.table_name = "comments"
    self.inheritance_column = nil

    belongs_to :decoupled_post,
      class_name: "AssociationRouteTest::DecoupledRoutePost",
      foreign_key: :post_id,
      query_constraints: :author_id,
      optional: true
    belongs_to :title_matched_post,
      class_name: "AssociationRouteTest::DecoupledRoutePost",
      foreign_key: :post_id,
      query_constraints: { body: :title },
      optional: true
  end

  def test_declared_query_constraints_extend_routes_without_becoming_references
    belongs_to_route = DecoupledRouteComment.reflect_on_association(:decoupled_post).association_route
    has_many_route = DecoupledRoutePost.reflect_on_association(:decoupled_comments).association_route

    assert_equal [["author_id", "author_id"], ["post_id", "id"]], belongs_to_route.each_match.to_a
    assert_equal [["post_id", "id"]], belongs_to_route.each_reference.to_a
    assert_equal [["author_id", "author_id"]], belongs_to_route.each_constraint.to_a
    assert_equal [["author_id", "author_id"], ["id", "post_id"]], has_many_route.each_match.to_a
    assert_equal [["id", "post_id"]], has_many_route.each_reference.to_a
    assert_equal [["author_id", "author_id"]], has_many_route.each_constraint.to_a
  end

  def test_declared_query_constraints_filter_association_reads
    post = DecoupledRoutePost.create!(title: "Matched body", body: "Post body", author_id: 41)
    matching = DecoupledRouteComment.create!(post_id: post.id, author_id: post.author_id, body: post.title)
    wrong_author = DecoupledRouteComment.create!(post_id: post.id, author_id: 42, body: post.title)
    wrong_body = DecoupledRouteComment.create!(post_id: post.id, author_id: post.author_id, body: "Other body")

    assert_equal [matching, wrong_body], post.decoupled_comments.order(:id).to_a
    assert_equal post, matching.decoupled_post
    assert_nil wrong_author.decoupled_post
    assert_equal [matching, wrong_author], post.body_matched_comments.order(:id).to_a
    assert_equal post, matching.title_matched_post
    assert_nil wrong_body.title_matched_post
  end

  def test_declared_query_constraints_are_not_written_with_the_foreign_key
    post = DecoupledRoutePost.create!(title: "Write-only reference", body: "Post body", author_id: 41)
    comment = DecoupledRouteComment.new(author_id: 42)

    comment.decoupled_post = post
    assert_equal post.id, comment.post_id
    assert_equal 42, comment.author_id

    comment.decoupled_post = nil
    assert_nil comment.post_id
    assert_equal 42, comment.author_id
  end

  def test_constrained_routes_match_reference_and_query_constraint_columns_in_both_directions
    link = ActiveRecord::AssociationLink.new(
      reference: build_mapping(reference_key: :post_id, target_key: :id),
      constraints: build_mapping(reference_key: :body, target_key: :author_id)
    )
    comments = [Comment.new(post_id: 42, body: "7"), Comment.new(post_id: 42, body: "8"), Comment.new(post_id: 43, body: "7")]
    posts = [Post.new(id: 42, author_id: 7), Post.new(id: 42, author_id: 8), Post.new(id: 43, author_id: 7)]

    [ActiveRecord::AssociationRoute, ActiveRecord::AssociationRoute::Reverse].each do |route_class|
      route = route_class.new(link: link)
      expected_match = [["body", "author_id"], ["post_id", "id"]]
      expected_reference = [["post_id", "id"]]
      expected_constraint = [["body", "author_id"]]
      if route_class == ActiveRecord::AssociationRoute
        origins, destination = comments, posts.first
      else
        expected_match.map!(&:reverse)
        expected_reference.map!(&:reverse)
        expected_constraint.map!(&:reverse)
        origins, destination = posts, comments.first
      end

      assert_equal expected_match, route.each_match.to_a
      assert_equal expected_reference, route.each_reference.to_a
      assert_equal expected_constraint, route.each_constraint.to_a
      assert_equal [origins.first], route.each_matching_origin(origins, destination).to_a
      assert_equal [true, false, false], origins.map { |origin| route.key_values_match?(origin, destination) }
    end
  end

  def test_writing_a_reference_with_unselected_keys_and_fixed_values
    [ActiveRecord::AssociationLink, ActiveRecord::AssociationLink::DeprecatedIdWriter].each do |link_class|
      link = link_class.new(
        reference: build_mapping(reference_key: :route_fk, target_key: :id),
        reference_class: AliasedRouteComment,
        target_class: Post,
        fixed_values: { "body" => "Fixed body" }
      )
      comment = AliasedRouteComment.instantiate("id" => 1)

      link.write_reference(comment, Post.new(id: 42), force: false)

      assert_equal 42, comment.post_id
      assert_equal "Fixed body", comment.body
    end
  end

  def test_clearing_a_reference_with_unselected_fixed_values
    [ActiveRecord::AssociationLink, ActiveRecord::AssociationLink::DeprecatedIdWriter].each do |link_class|
      link = link_class.new(
        reference: build_mapping(reference_key: :post_id, target_key: :id),
        fixed_values: { "body" => "Fixed body" }
      )
      comment = Comment.instantiate("id" => 1, "post_id" => 42)

      link.clear_reference(comment, force: false)

      assert_nil comment.post_id
      assert_not comment.has_attribute?(:body)
    end
  end

  def test_matching_records_with_unselected_keys
    route = build_belongs_to_route(
      reference: { reference_key: :post_id, target_key: :author_id },
      constraints: { reference_key: nil, target_key: nil }
    )
    comment = Comment.instantiate("id" => 1, "post_id" => nil)
    post = Post.instantiate("id" => 2)

    assert route.key_values_match?(comment, post)
    assert_equal [comment], route.each_matching_origin([comment], post).to_a
    assert_not route.origin_reference_complete?(Comment.instantiate("id" => 3))
  end

  def test_inverse_routes_reverse_the_same_foreign_key_mapping
    belongs_to = Client.reflect_on_association(:firm).association_route
    has_many = Firm.reflect_on_association(:clients_of_firm).association_route

    assert_equal [["client_of", "id"]], belongs_to.link.reference.to_a
    assert_equal belongs_to.link.reference, has_many.link.reference
    assert_equal ["client_of", "id"], [belongs_to.origin_key.name, belongs_to.destination_key.name]
    assert_equal ["id", "client_of"], [has_many.origin_key.name, has_many.destination_key.name]
  end

  if RUBY_VERSION >= "4.0"
    def test_shared_reflections_resolve_and_clear_routes_in_another_ractor
      fresh_route_reflections.each do |reflection, destination_class|
        destination_class.initialize_find_by_cache
        pairs = reflection.association_route(destination_class: destination_class).each_match.to_a
        ActiveSupport::Ractors.make_shareable(reflection)
        assert_ractor_shareable reflection

        resolved, rebuilt = on_ractor(reflection, destination_class) do |reflection, destination_class|
          before_clearing = reflection.association_route(destination_class: destination_class).each_match.to_a
          reflection.clear_association_scope_cache(destination_class)
          [before_clearing, reflection.association_route(destination_class: destination_class).each_match.to_a]
        end

        assert_equal pairs, resolved
        assert_equal pairs, rebuilt
      end

      model = Class.new(ActiveRecord::Base) do
        self.table_name = "companies"
        def self.name = "RactorRouteModel"
      end
      ActiveSupport::Ractors.with(unshareable_proc_action: :raise) do
        model.load_schema
      end
      route = build_belongs_to_route(
        reference: { reference_key: :name, target_key: :id },
        constraints: { reference_key: nil, target_key: nil }
      )

      values = on_ractor(route, model) do |route, model|
        origin, destination = route.match_normalizers(origin_class: model, destination_class: model)
        [origin.first.call(123), destination.first.call(456), origin.first.call(nil)]
      end

      assert_equal ["123", "456", nil], values
    end
  end

  def test_association_predicates_use_the_match_mapping_in_reverse_routes
    post = posts(:welcome)
    matching = Comment.new(post_id: post.id, body: post.title)
    mismatching = Comment.new(post_id: post.id, body: "Not the post title")

    Post.reflect_on_association(:comments).stub(:association_route, post_comments_route_constrained_by_title) do
      assert_equal [post], Post.where(comments: matching).to_a
      assert_empty Post.where(comments: mismatching)
    end
  end

  def test_relation_predicates_apply_unspecified_destination_fixed_values
    reference = build_mapping(reference_key: :post_id, target_key: :id)
    route = ActiveRecord::AssociationRoute::Reverse.new(link: ActiveRecord::AssociationLink.new(
      reference: reference, fixed_values: { "body" => "Fixed body", "author_id" => 1 }
    ))

    Post.reflect_on_association(:comments).stub(:association_route, route) do
      expected = Post.where(id: Comment.where(body: "Fixed body", author_id: 1).select(:post_id))
      assert_equal expected.to_sql, Post.where(comments: Comment.all).to_sql

      expected = Post.where(id: Comment.where(body: "Other body", author_id: 1).select(:post_id))
      assert_equal expected.to_sql, Post.where(comments: Comment.where(body: "Other body")).to_sql
    end
  end

  def test_equivalent_inverse_polymorphic_routes_are_equal
    reflection = Member.reflect_on_association(:sponsor)
    origin_class = Class.new(Member) do
      def self.name = "EquivalentRouteMember"
    end
    variant = reflection.association_route(origin_class: origin_class)
    default = reflection.association_route

    assert_operator variant, :eql?, default
    assert_equal default.hash, variant.hash
  end

  def test_cached_association_reads_logical_inputs_from_each_owner
    first = posts(:welcome)
    second = Post.create!(title: "Second target", body: "Second target")
    reflection = AliasedRouteComment.reflect_on_association(:routed_post)
    routes = reflection.association_route_chain(origin_class: AliasedRouteComment, destination_class: Post)

    each_statement_mode do
      first_reference = AliasedRouteComment.new(route_fk: first.id)
      second_reference = AliasedRouteComment.new(route_fk: second.id)

      assert_equal first, first_reference.routed_post
      statement = reflection.association_scope_cache(Post, routes)
      assert_equal second, second_reference.routed_post
      assert_same statement, reflection.association_scope_cache(Post, routes)
    end
  end

  def test_query_constraints_are_not_part_of_the_reference
    link = ActiveRecord::AssociationLink.new(
      reference: build_mapping(reference_key: [:author_id, :post_id], target_key: [:author_id, :id]),
      constraints: build_mapping(reference_key: :body, target_key: :title)
    )
    forward = ActiveRecord::AssociationRoute.new(link: link)
    reverse = ActiveRecord::AssociationRoute::Reverse.new(link: link)
    reference = Comment.new(author_id: 7, post_id: 42, body: nil)
    target = Post.new(author_id: 7, id: 42, title: nil)

    assert forward.origin_reference_complete?(reference)
    assert reverse.origin_reference_complete?(target)

    target.title = "Target constraint"
    assert_not forward.reference_needs_update?(reference, target)
    assert_not reverse.reference_needs_update?(target, reference)
    forward.write(reference, target)
    reverse.write(target, reference)
    assert_nil reference.body

    reference.author_id = nil
    target.author_id = nil
    assert_not forward.origin_reference_complete?(reference)
    assert_not reverse.origin_reference_complete?(target)
  end

  def test_matching_origins_compare_each_class_by_its_own_types_and_preserve_order
    string_link_class = Class.new(ConstrainedRouteLink) do
      attribute :club_id, :string
    end
    route = ActiveRecord::AssociationRoute.new(link: ActiveRecord::AssociationLink.new(
      reference: build_mapping(reference_key: :club_id, target_key: :pirate_id)
    ))
    first = ConstrainedRouteLink.new(club_id: 42)
    second = string_link_class.new(club_id: "42")
    miss = ConstrainedRouteLink.new(club_id: 43)
    destination = Ship.new(pirate_id: 42)

    assert_equal [first, second, first], route.each_matching_origin([first, second, miss, first], destination).to_a
  end

  def test_normalized_single_column_match_preserves_array_valued_scalars
    skip unless current_adapter?(:PostgreSQLAdapter)

    record = ArrayRouteRecord.create!(big_int_data_points: [10, 20])
    route = ArrayRouteRecord.reflect_on_association(:same_array).association_route

    assert_not_predicate route.origin_key, :composite?
    assert_not_predicate route.destination_key, :composite?
    assert_equal [10, 20], route.origin_key.value_of(record)
    assert_equal [10, 20], route.destination_key.value_of(record)
    assert_equal record, record.same_array

    record.association(:same_array).reset
    ActiveRecord::Associations::Preloader.new(records: [record], associations: :same_array).call
    assert_predicate record.association(:same_array), :loaded?
    assert_equal record, record.same_array
  end

  def test_query_constraints_filter_association_loads
    member = ConstrainedRouteMember.create!(member_type_id: 42)
    Sponsor.create!(club_id: 41, sponsorable: member)
    matching = Sponsor.create!(club_id: 42, sponsorable: member)
    reflection = ConstrainedRouteMember.reflect_on_association(:routed_sponsor)

    with_constraints(reflection, reference_key: :club_id, target_key: :member_type_id) do
      assert_equal matching, member.routed_sponsor
    end
  end

  def test_cached_association_loads_bind_each_owners_constraint_values
    first = Member.create!(member_type_id: 41)
    second = Member.create!(member_type_id: 42)
    first_target = Sponsor.create!(club_id: 41, sponsorable: first)
    second_target = Sponsor.create!(club_id: 42, sponsorable: second)
    Sponsor.create!(club_id: 42, sponsorable: first)
    Sponsor.create!(club_id: 41, sponsorable_id: first.id, sponsorable_type: Post.polymorphic_name)
    reflection = Member.reflect_on_association(:sponsor)

    with_constraints(reflection, reference_key: :club_id, target_key: :member_type_id) do
      routes = reflection.association_route_chain(origin_class: Member, destination_class: Sponsor)

      each_statement_mode do
        assert_equal first_target, first.reload_sponsor
        statement = reflection.association_scope_cache(Sponsor, routes)
        assert_equal second_target, second.reload_sponsor
        assert_same statement, reflection.association_scope_cache(Sponsor, routes)
      end
    end
  end

  def test_query_constraints_filter_preloaded_records
    post = posts(:welcome)
    matching = Comment.create!(post_id: post.id, body: post.title)
    mismatching = Comment.create!(post_id: post.id, body: "Not the post title")

    Post.reflect_on_association(:comments).stub(:association_route, post_comments_route_constrained_by_title) do
      preloaded = Post.where(id: post.id).preload(:comments).first
      assert_includes preloaded.comments, matching
      assert_not_includes preloaded.comments, mismatching
    end
  end

  def test_query_constraints_apply_to_joins
    post = posts(:welcome)
    matching = Comment.create!(post_id: post.id, body: post.title)
    mismatching = Comment.create!(post_id: post.id, body: "Not the post title")

    Post.reflect_on_association(:comments).stub(:association_route, post_comments_route_constrained_by_title) do
      assert Post.joins(:comments).where(posts: { id: post.id }, comments: { id: matching.id }).exists?
      assert_not Post.joins(:comments).where(posts: { id: post.id }, comments: { id: mismatching.id }).exists?
    end
  end

  def test_query_constraints_filter_disable_joins_loads
    author = Author.create!(name: "Constrained author")
    constrained_post = Post.create!(author: author, title: "Constrained post", body: "Post body")
    Comment.create!(post: constrained_post, body: "Not the post title")
    comment = Comment.create!(post: constrained_post, body: constrained_post.title)
    Comment.create!(post: constrained_post, body: "Not the post title either")

    Post.reflect_on_association(:comments).stub(:association_route, post_comments_route_constrained_by_title) do
      assert_equal [comment], author.no_joins_comments.to_a
    end
  end

  def test_query_constraints_are_not_written_to_built_records
    post = posts(:welcome)

    Post.reflect_on_association(:comments).stub(:association_route, post_comments_route_constrained_by_title) do
      built = post.comments.build
      assert_equal post.id, built.post_id
      assert_nil built.body
    end
  end

  def test_association_predicates_match_records_completely_and_nil_by_reference
    reference_class = Class.new(ActiveRecord::Base) do
      self.table_name = "sponsors"

      def self.name = "ConstrainedPredicateReference"

      belongs_to :routed_ship,
        class_name: "Ship",
        foreign_key: :club_id,
        primary_key: :pirate_id,
        optional: true
    end
    unset = reference_class.create!(club_id: nil, sponsorable_type: "Present constraint")
    reference_class.create!(club_id: 9_000_861, sponsorable_type: "Other constraint")
    reference = reference_class.create!(club_id: 9_000_861, sponsorable_type: "Present constraint")
    reference_class.create!(club_id: 9_000_861, sponsorable_type: "Another constraint")
    route = build_belongs_to_route(
      reference: { reference_key: :club_id, target_key: :pirate_id },
      constraints: { reference_key: :sponsorable_type, target_key: :name }
    )

    reference_class.reflect_on_association(:routed_ship).stub(:association_route, route) do
      assert_includes reference_class.where(routed_ship: nil), unset
      assert_includes reference_class.where(routed_ship: [nil]), unset

      target = Ship.new(pirate_id: reference.club_id, name: reference.sponsorable_type)
      assert_equal [reference], reference_class.where(routed_ship: target).to_a
      assert_equal [reference], reference_class.where(routed_ship: [target]).to_a

      [[nil, target], [target, nil]].each do |values|
        matches = reference_class.where(routed_ship: values)
        assert_includes matches, unset
        assert_equal [reference], matches.where.not(club_id: nil).to_a
      end
    end
  end

  def test_association_predicates_reject_bare_ids_with_query_constraints
    reflection = Comment.reflect_on_association(:post)
    route = build_belongs_to_route(
      reference: { reference_key: :post_id, target_key: :id },
      constraints: { reference_key: :body, target_key: :title }
    )

    reflection.stub(:association_route, route) do
      assert_raises(ArgumentError) { Comment.where(post: 1) }
      assert_raises(ArgumentError) { Comment.where(post: [nil, 1]) }
    end
  end

  def test_polymorphic_relation_predicates_match_query_constraints
    polymorphic_class = Class.new(ActiveRecord::Base) do
      self.table_name = "sponsors"

      def self.name = "ConstrainedPolymorphicReference"

      belongs_to :subject,
        polymorphic: true,
        foreign_key: :club_id,
        foreign_type: :sponsorable_type,
        optional: true
    end
    post = Post.create!(title: "Polymorphic relation", body: "Polymorphic relation")
    polymorphic_class.create!(club_id: post.id, sponsor_type: "Not the post title", sponsorable_type: Post.polymorphic_name)
    polymorphic_reference = polymorphic_class.create!(club_id: post.id, sponsor_type: post.title, sponsorable_type: Post.polymorphic_name)
    polymorphic_class.create!(club_id: post.id, sponsor_type: "Not the post title either", sponsorable_type: Post.polymorphic_name)

    with_constraints(polymorphic_class.reflect_on_association(:subject), reference_key: :sponsor_type, target_key: :title) do
      assert_equal [polymorphic_reference], polymorphic_class.where(subject: post).to_a
      assert_equal [polymorphic_reference], polymorphic_class.where(subject: Post.where(id: post.id)).to_a
      assert_empty polymorphic_class.where(subject: Post.none)
    end
  end

  def test_query_constraints_identify_counter_cache_destinations
    reference_class = Class.new(ActiveRecord::Base) do
      self.table_name = "comments"
      self.inheritance_column = nil

      def self.name = "ConstrainedCounterReference"

      belongs_to :routed_post,
        class_name: "Post",
        foreign_key: :author_id,
        primary_key: :author_id,
        counter_cache: :legacy_comments_count,
        optional: true
    end
    reflection = reference_class.reflect_on_association(:routed_post)
    route = build_belongs_to_route(
      reference: { reference_key: :author_id, target_key: :author_id },
      constraints: { reference_key: :deleted_at, target_key: :deleted_at }
    )
    old_post = Post.create!(author_id: 9_000_101, title: "Old constrained post", body: "Old")
    decoy = Post.create!(author_id: old_post.author_id, title: "Decoy constrained post", body: "Decoy", deleted_at: Time.utc(2000))
    new_post = Post.create!(author_id: 9_000_102, title: "New constrained post", body: "New", deleted_at: Time.utc(2001))
    old_post.update_column(:legacy_comments_count, 1)
    decoy.update_column(:legacy_comments_count, 1)
    reference_class.create!(post_id: -1, body: "Constrained reference").update_columns(
      author_id: old_post.author_id,
      deleted_at: old_post.deleted_at
    )
    reference = reference_class.find_by!(author_id: old_post.author_id, deleted_at: nil)

    reflection.stub(:association_route, route) do
      reference.author_id = new_post.author_id
      reference.deleted_at = new_post.deleted_at
      reference.save!
    end

    assert_equal 0, old_post.reload.legacy_comments_count
    assert_equal 1, decoy.reload.legacy_comments_count
    assert_equal 1, new_post.reload.legacy_comments_count
  end

  def test_query_constraints_identify_touch_destinations
    reference_class = Class.new(ActiveRecord::Base) do
      self.table_name = "sponsors"

      def self.name = "ConstrainedTouchReference"

      belongs_to :routed_ship,
        class_name: "Ship",
        foreign_key: :club_id,
        primary_key: :pirate_id,
        touch: true,
        optional: true
    end
    reflection = reference_class.reflect_on_association(:routed_ship)
    route = build_belongs_to_route(
      reference: { reference_key: :club_id, target_key: :pirate_id },
      constraints: { reference_key: :sponsorable_type, target_key: :name }
    )
    original_time = Time.utc(2000)
    # An unconstrained lookup can return any matching row. Put decoys before
    # and after the target to catch either ascending or descending id scans.
    first_decoy = Ship.create!(name: "First decoy constrained ship", pirate_id: 9_000_111, updated_at: original_time)
    old_ship = Ship.create!(name: "Old constrained ship", pirate_id: first_decoy.pirate_id, updated_at: original_time)
    last_decoy = Ship.create!(name: "Last decoy constrained ship", pirate_id: first_decoy.pirate_id, updated_at: original_time)
    new_ship = Ship.create!(name: "New constrained ship", pirate_id: 9_000_112, updated_at: original_time)
    reference_class.create!(sponsorable_id: -1).update_columns(
      club_id: old_ship.pirate_id,
      sponsorable_type: old_ship.name
    )
    reference = reference_class.find_by!(sponsorable_type: old_ship.name)

    reflection.stub(:association_route, route) do
      reference.club_id = new_ship.pirate_id
      reference.sponsorable_type = new_ship.name
      reference.save!
    end

    assert_operator old_ship.reload.updated_at, :>, original_time
    assert_equal original_time, first_decoy.reload.updated_at
    assert_equal original_time, last_decoy.reload.updated_at
  end

  def test_async_destruction_identifies_an_assigned_target_by_its_persisted_match
    reference_class = Class.new(ActiveRecord::Base) do
      self.table_name = "comments"
      self.inheritance_column = nil

      def self.name = "ConstrainedAsyncReference"

      belongs_to :routed_post,
        class_name: "Post",
        foreign_key: :author_id,
        primary_key: :author_id,
        optional: true
    end
    reflection = reference_class.reflect_on_association(:routed_post)
    reflection.options[:dependent] = :destroy_async
    route = build_belongs_to_route(
      reference: { reference_key: :author_id, target_key: :author_id },
      constraints: { reference_key: :body, target_key: :title }
    )
    original = Post.create!(author_id: 9_000_121, title: "Original", body: "Original")
    replacement = Post.create!(author_id: original.author_id, title: "Replacement", body: "Replacement")
    reference = reference_class.create!(post_id: -1, author_id: original.author_id, body: original.title)
    association = reference.association(:routed_post)
    enqueued = nil

    reflection.stub(:association_route, route) do
      persisted_title = replacement.title
      persisted_author_id = replacement.author_id
      reference.routed_post = replacement
      replacement.title = "Unsaved title"
      replacement.author_id = 9_000_132
      association.stub(:enqueue_destroy_association, ->(**options) { enqueued = options }) do
        association.handle_dependency
      end

      assert_equal Post.to_s, enqueued[:association_class]
      assert_equal ["title", "author_id"], enqueued[:association_primary_key_column]
      assert_equal [[persisted_title, persisted_author_id]], enqueued[:association_ids]
    end
  end

  def test_through_deletion_uses_the_complete_match
    post = ConstrainedRoutePost.create!(title: "Constrained through", body: "Constrained through")
    first = Ship.create!(pirate_id: 9_000_301, name: "First constrained ship")
    second = Ship.create!(pirate_id: first.pirate_id, name: "Second constrained ship")
    first_link = ConstrainedRouteLink.create!(sponsorable_id: post.id, club_id: first.pirate_id, sponsor_type: first.name)
    second_link = ConstrainedRouteLink.create!(sponsorable_id: post.id, club_id: second.pirate_id, sponsor_type: second.name)
    reflection = ConstrainedRouteLink.reflect_on_association(:ship)

    with_constraints(reflection, reference_key: :sponsor_type, target_key: :name) do
      assert_equal [first, second], post.route_ships.order(:id).to_a
      post.route_links.load
      post.route_ships.delete(first)
    end

    assert_not ConstrainedRouteLink.exists?(first_link.id)
    assert ConstrainedRouteLink.exists?(second_link.id)
    assert_equal [second_link], post.route_links.to_a
  end

  private
    def fresh_route_reflections
      [
        [ActiveRecord::Reflection.create(:belongs_to, :firm, nil,
          { class_name: "Firm", foreign_key: :client_of, inverse_of: false }, Client), Firm],
        [ActiveRecord::Reflection.create(:has_one, :sponsor, nil,
          { class_name: "Sponsor", as: :sponsorable, inverse_of: false }, Member), Sponsor],
        [ActiveRecord::Reflection.create(:belongs_to, :sponsorable, nil,
          { polymorphic: true, inverse_of: false }, Sponsor), Member],
      ]
    end

    def each_statement_mode(&)
      yield
      ActiveRecord::Base.lease_connection.unprepared_statement(&)
    end

    def build_mapping(reference_key:, target_key:)
      ActiveRecord::Key::Mapping.new(
        reference_key: ActiveRecord::Key.for(reference_key),
        target_key: ActiveRecord::Key.for(target_key)
      )
    end

    def with_constraints(reflection, reference_key:, target_key:, &block)
      constraints = build_mapping(reference_key: reference_key, target_key: target_key)
      reflection.clear_association_scope_cache unless reflection.polymorphic?
      reflection.stub(:association_route_constraints, constraints, &block)
    ensure
      reflection.clear_association_scope_cache unless reflection.polymorphic?
    end

    def build_belongs_to_route(reference:, constraints:)
      reference = build_mapping(**reference)
      constraints = build_mapping(**constraints)

      ActiveRecord::AssociationRoute.new(link: ActiveRecord::AssociationLink.new(reference: reference, constraints: constraints))
    end

    def post_comments_route_constrained_by_title
      build_route(
        reference: { reference_key: :post_id, target_key: :id },
        constraints: { reference_key: :body, target_key: :title }
      )
    end

    def build_route(reference:, constraints:)
      reference = build_mapping(**reference)
      constraints = build_mapping(**constraints)

      ActiveRecord::AssociationRoute::Reverse.new(link: ActiveRecord::AssociationLink.new(reference: reference, constraints: constraints))
    end
end

# Creating a table commits MySQL's open transaction, so these tests run
# outside the one that normally wraps each test.
class AssociationRouteSchemaChangeTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  fixtures :posts

  def test_belongs_to_follows_a_target_primary_key_changed_before_a_schema_reload
    connection = main_ractor_connection(ActiveRecord::Base.lease_connection)
    connection.create_table(:route_key_targets, force: true) { |t| t.integer :alternate_id }
    connection.create_table(:route_key_references, force: true) { |t| t.integer :target_id }
    target_model = Class.new(ActiveRecord::Base) do
      self.table_name = "route_key_targets"
      def self.name = "RouteKeyTarget"
    end
    reference_model = Class.new(ActiveRecord::Base) do
      self.table_name = "route_key_references"
      def self.name = "RouteKeyReference"
      belongs_to :target, anonymous_class: target_model, inverse_of: false, optional: true
    end
    # The reference's key selects the first target by id and the second by
    # alternate_id.
    first = target_model.create!(alternate_id: -1)
    second = target_model.create!(alternate_id: first.id)
    reference = reference_model.create!(target_id: first.id)
    assert_targets = lambda do |expected|
      assert_equal expected.alternate_id, reference_model.find(reference.id).target.alternate_id
      preloaded = reference_model.find(reference.id)
      ActiveRecord::Associations::Preloader.new(records: [preloaded], associations: :target).call
      assert_equal expected.alternate_id, preloaded.target.alternate_id
      assert_equal [expected.alternate_id], reference_model.joins(:target).pluck("route_key_targets.alternate_id")
    end
    assert_targets.call(first)

    target_model.primary_key = "alternate_id"
    target_model.reset_column_information

    assert_targets.call(second)
  ensure
    connection&.drop_table(:route_key_targets, if_exists: true)
    connection&.drop_table(:route_key_references, if_exists: true)
  end

  def test_has_many_and_has_one_follow_an_owner_primary_key_changed_before_a_schema_reload
    connection = main_ractor_connection(ActiveRecord::Base.lease_connection)
    connection.create_table(:route_key_owners, force: true) { |t| t.integer :alternate_id }
    connection.create_table(:route_key_children, force: true) { |t| t.integer :owner_id }
    child_model = Class.new(ActiveRecord::Base) do
      self.table_name = "route_key_children"
      def self.name = "RouteKeyChild"
    end
    owner_model = Class.new(ActiveRecord::Base) do
      self.table_name = "route_key_owners"
      def self.name = "RouteKeyOwner"
      has_many :children, anonymous_class: child_model, foreign_key: :owner_id, inverse_of: false
      has_one :child, anonymous_class: child_model, foreign_key: :owner_id, inverse_of: false
    end
    # The child's key selects the first owner by id and the second by
    # alternate_id.
    first = owner_model.create!(alternate_id: -1)
    second = owner_model.create!(alternate_id: first.id)
    child = child_model.create!(owner_id: first.id)
    assert_children = lambda do |expected|
      owner = owner_model.find_by!(alternate_id: expected.alternate_id)
      assert_equal [child.id], owner.children.map(&:id)
      assert_equal child.id, owner_model.find_by!(alternate_id: expected.alternate_id).child.id
      preloaded = owner_model.where(id: [first.id, second.id]).to_a
      ActiveRecord::Associations::Preloader.new(records: preloaded, associations: [:children, :child]).call
      expected_children = { first.alternate_id => [], second.alternate_id => [] }.merge(expected.alternate_id => [child.id])
      assert_equal expected_children, preloaded.to_h { |record| [record.alternate_id, record.children.map(&:id)] }
      assert_equal expected_children.transform_values(&:first), preloaded.to_h { |record| [record.alternate_id, record.child&.id] }
      assert_equal [expected.alternate_id], owner_model.joins(:children).pluck(:alternate_id)
    end
    assert_children.call(first)

    owner_model.primary_key = "alternate_id"
    owner_model.reset_column_information

    assert_children.call(second)
  ensure
    connection&.drop_table(:route_key_owners, if_exists: true)
    connection&.drop_table(:route_key_children, if_exists: true)
  end

  def test_preloading_follows_key_types_across_schema_reloads
    connection = main_ractor_connection(ActiveRecord::Base.lease_connection)
    connection.create_table(:route_schema_references, force: true) { |t| t.integer :post_id }
    model = Class.new(ActiveRecord::Base) do
      self.table_name = "route_schema_references"
      def self.name = "RouteSchemaReference"
      belongs_to :post, inverse_of: false, optional: true
    end
    post = posts(:welcome)
    reference = model.create!(post_id: post.id)
    ActiveRecord::Associations::Preloader.new(records: [reference], associations: :post).call
    assert_equal post, reference.post

    connection.change_column(:route_schema_references, :post_id, :string)
    model.reset_column_information
    reference = model.find(reference.id)
    assert_equal post.id.to_s, reference.post_id

    ActiveRecord::Associations::Preloader.new(records: [reference], associations: :post).call
    assert_equal post, reference.post
  ensure
    connection&.drop_table(:route_schema_references, if_exists: true)
  end
end
