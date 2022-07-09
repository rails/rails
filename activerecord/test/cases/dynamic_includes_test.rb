# frozen_string_literal: true

require "cases/helper"
require "models/developer"
require "models/contract"
require "models/company"
require "models/computer"
require "models/mentor"
require "models/project"
require "models/ship"
require "models/ship_part"
require "models/strict_zine"
require "models/interest"
require "models/human"
require "models/topic"
require "models/treasure"
require "models/pirate"
require "models/book"
require "models/post"
require "models/author"
require "models/author_encrypted"
require "models/comment"
require "models/member"
require "models/member_type"

require "active_support/log_subscriber/test_helper"

class ShipPart
  def expensive_method
    trinkets.map do |t|
      ActiveRecord.dynamic_includes_enabled?
    end
  end
end

class DynamicIncludesNoLoadTree < ActiveRecord::TestCase
  test "throws error when load tree is not enabled" do
    assert_raises ActiveRecord::DynamicIncludes::LoadTreeNotEnabledError do
      ActiveRecord.with_dynamic_includes(enabled: true) do
        1 + 1
      end
    end
  end
end

class DynamicIncludesTest < ActiveRecord::TestCase
  fixtures :developers, :developers_projects, :projects, :posts,
           :ships, :interests, :humans, :topics, :books, :authors, :members

  def setup
    ActiveRecord.load_tree_enabled = true
  end

  def teardown
    ActiveRecord.load_tree_enabled = false
  end

  test "dynamic loading prevents all n+1 queries" do
    developer = Developer.first
    developer2 = Developer.last
    developer3 = Developer.create!(name: "Developer 3")
    ship = Ship.first
    stern1 = ShipPart.create!(name: "Stern", ship: ship)
    bow1 = ShipPart.create!(name: "bow", ship: ship)
    ship2 = Ship.create!(developer_id: developer.id, name: "Ship2")
    ShipPart.create!(name: "Stern2", ship: ship2)
    ShipPart.create!(name: "bow2", ship: ship2)
    bow1.trinkets.create!(name: "Bow Trinket")
    stern1.trinkets.create!(name: "Stern Trinket")
    stern1.trinkets.create!(name: "Stern Trinket 2")

    firm = Firm.create!(name: "NASA")
    project = Project.create!(name: "Apollo", firm: firm)
    project2 = Project.create!(name: "Apollo2", firm: firm)
    project3 = Project.create!(name: "Apollo3", firm: firm)

    ship.update_column(:developer_id, developer.id)
    developer.projects << project
    developer.projects << project2
    developer2.projects << project3
    developer = Developer.find(developer.id)
    developers = Developer.where(id: [developer.id, developer2.id, developer3.id])


    # Preloaded has many throughs need to run 2 queries to get the data.
    ActiveRecord.with_dynamic_includes(enabled: true) do
      assert_queries(3) do
        developers.each do |dev|
          dev.projects.to_a
        end
      end

      assert_queries(1) { developer.projects.to_a }
      assert_queries(1) do
        developer.projects.each do |project|
          project.firm
        end
      end

      assert_queries(1) { developer.ship }
      assert_queries(1) { developer.ship.parts.to_a }

      assert_queries(1) do
        developer.ship.parts.each do |part|
          part.trinkets.to_a
        end
      end
    end
  end

  test "dynamic loading disabled does n+1" do
    developer = Developer.first
    ship = Ship.first
    ShipPart.create!(name: "Stern", ship: ship)
    ShipPart.create!(name: "bow", ship: ship)
    ship2 = Ship.create!(developer_id: developer.id, name: "Ship2")
    ShipPart.create!(name: "Stern2", ship: ship2)
    ShipPart.create!(name: "bow2", ship: ship2)

    firm = Firm.create!(name: "NASA")
    project = Project.create!(name: "Apollo", firm: firm)
    project2 = Project.create!(name: "Apollo2", firm: firm)

    ship.update_column(:developer_id, developer.id)
    developer.projects << project
    developer.projects << project2
    developer = Developer.find(developer.id)

    assert_not ActiveRecord.dynamic_includes_enabled?

    assert_queries(1) { developer.projects.to_a }
    assert_queries(2) do
      developer.projects.each do |project|
        project.firm
      end
    end

    assert_queries(2) { developer.ship.parts.to_a }

    assert_queries(2) do
      developer.ship.parts.each do |part|
       part.trinkets.to_a
       part.trinkets.each do |trinket|
         trinket
       end
     end
    end
  end

  test "dynamic loading can be disabled for a method that maybe expensive" do
    developer = Developer.first
    ship = Ship.first
    stern1 = ShipPart.create!(name: "Stern", ship: ship)
    bow1 = ShipPart.create!(name: "bow", ship: ship)
    ship2 = Ship.create!(developer_id: developer.id, name: "Ship2")
    ShipPart.create!(name: "Stern2", ship: ship2)
    ShipPart.create!(name: "bow2", ship: ship2)
    bow1.trinkets.create!(name: "Bow Trinket")
    stern1.trinkets.create!(name: "Stern Trinket")
    stern1.trinkets.create!(name: "Stern Trinket 2")

    ActiveRecord.with_dynamic_includes(enabled: true) do
      developer = Developer.find(developer.id)
      assert_queries(3) do
        developer.ship.parts.each do |part|
          part.expensive_method # This should not n+1
        end
      end
    end

    ActiveRecord.with_dynamic_includes(enabled: true) do
      developer = Developer.find(developer.id)

      assert_queries(4) do
        developer.ship.parts.each do |part|
          ActiveRecord.with_dynamic_includes(enabled: false) do
            part.expensive_method # This should n+1
            assert_not ActiveRecord.dynamic_includes_enabled?
          end
          assert ActiveRecord.dynamic_includes_enabled?
        end
      end
    end
  end

  test "when disabling dynamic loading it can be turned back on to avoid n+1 queries" do
    developer = Developer.first
    ship = Ship.first
    ship.update_column(:developer_id, developer.id)
    stern1 = ShipPart.create!(name: "Stern", ship: ship)
    bow1 = ShipPart.create!(name: "bow", ship: ship)
    Ship.create!(developer_id: developer.id, name: "Ship2")
    bow1.trinkets.create!(name: "Bow Trinket")
    stern1.trinkets.create!(name: "Stern Trinket")
    stern1.trinkets.create!(name: "Stern Trinket 2")

    developer2 = Developer.last
    ship2 = Ship.create!(developer_id: developer2.id, name: "Ship2")
    ship2_stern = ShipPart.create!(name: "Stern2", ship: ship2)
    ship2_bow = ShipPart.create!(name: "bow2", ship: ship2)
    ship2_stern.trinkets.create!(name: "Stern Trinket")
    ship2_bow.trinkets.create!(name: "Bow Trinket")

    # Standard rails n+1 behavior
    developers = Developer.where(id: [developer.id, developer2.id])
    assert_queries(9) do
      developers.each do |d|
        d.ship.parts.each do |part|
          part.trinkets.each do |t|
            t
          end
        end
      end
    end

    # Always Dynamically Include
    developers = Developer.where(id: [developer.id, developer2.id])
    ActiveRecord.with_dynamic_includes(enabled: true) do
      assert_queries(4) do
        developers.each do |d|
          d.ship.parts.each do |part|
            part.trinkets.each do |t|
              t
            end
          end
        end
      end
    end

    # Toggle Dynamic Includes on and off
    ActiveRecord.with_dynamic_includes(enabled: true) do
      developers = Developer.where(id: [developer.id, developer2.id])
      assert_queries(7) do
        developers.each do |d|
          assert ActiveRecord.dynamic_includes_enabled?
          ActiveRecord.with_dynamic_includes(enabled: false) do
            d.ship.parts.each do |part| # This should n+1
              assert_not ActiveRecord.dynamic_includes_enabled?
              ActiveRecord.with_dynamic_includes(enabled: true) do
                part.trinkets.each do |t|
                  assert ActiveRecord.dynamic_includes_enabled?
                end
              end
              assert_not ActiveRecord.dynamic_includes_enabled?
            end
          end
          assert ActiveRecord.dynamic_includes_enabled?
        end
      end
    end
  end

  test "it logs when an n+1 query is avoided" do
    old_logger = ActiveRecord::Base.logger
    logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new

    ActiveRecord::Base.logger = logger


    developer = Developer.first
    ship = Ship.first
    stern1 = ShipPart.create!(name: "Stern", ship: ship)
    bow1 = ShipPart.create!(name: "bow", ship: ship)
    bow1.trinkets.create!(name: "Bow Trinket")
    stern1.trinkets.create!(name: "Stern Trinket")
    stern1.trinkets.create!(name: "Stern Trinket 2")

    firm = Firm.create!(name: "NASA")
    project = Project.create!(name: "Apollo", firm: firm)
    project2 = Project.create!(name: "Apollo2", firm: firm)
    project3 = Project.create!(name: "Apollo3", firm: firm)

    ship.update_column(:developer_id, developer.id)
    developer.projects.delete_all
    developer.projects << project
    developer.projects << project2
    developer.projects << project3
    developer = Developer.find(developer.id)


    # Preloaded has many throughs need to run 2 queries to get the data.
    ActiveRecord.with_dynamic_includes(enabled: true) do
      expected_message = "Dynamically preloaded: 1 Firm for 3 Project"
      assert_queries(2) do
        developer.projects.each do |project|
          project.firm
        end
      end
      assert_includes(logger.logged(:debug), expected_message)

      assert_queries(3) do
        developer.ship.parts.each do |part|
          part.trinkets.each do |t|
            t
          end
        end
      end
    end

    assert_includes(logger.logged(:debug), "Dynamically preloaded: 3 Treasure for 2 ShipPart")
  ensure
    ActiveRecord::Base.logger = old_logger
  end

  def test_with_has_many_inversing_should_try_to_set_inverse_instances_when_the_inverse_is_a_has_many
    with_has_many_inversing(Interest) do
      ActiveRecord.with_dynamic_includes(enabled: true) do
        interest = interests(:trainspotting)
        human = interest.human
        assert_not_nil human.interests
        iz = human.interests.detect { |_iz| _iz.id == interest.id }
        assert_not_nil iz
        assert_equal interest.topic, iz.topic, "Interest topics should be the same before changes to child"
        interest.topic = "Eating cheese with a spoon"
        assert_equal interest.object_id, iz.object_id
        assert_equal interest.topic, iz.topic, "Interest topics should be the same after changes to child"
        iz.topic = "Cow tipping"
        assert_equal interest.topic, iz.topic, "Interest topics should be the same after changes to parent-owned instance"
      end
    end
  end

  test "manually running an include should work with dynamic includes mainting an appropriate sibling tree" do
    developer = Developer.first
    ship = Ship.first
    ship.update_column(:developer_id, developer.id)
    stern1 = ShipPart.create!(name: "Stern", ship: ship)
    bow1 = ShipPart.create!(name: "bow", ship: ship)
    bow1.trinkets.create!(name: "Bow Trinket")
    stern1.trinkets.create!(name: "Stern Trinket")
    stern1.trinkets.create!(name: "Stern Trinket 2")

    developer2 = Developer.last
    ship2 = Ship.create!(developer_id: developer2.id, name: "Ship2")
    ship2_stern = ShipPart.create!(name: "Stern2", ship: ship2)
    ship2_bow = ShipPart.create!(name: "bow2", ship: ship2)
    ship2_stern.trinkets.create!(name: "Stern Trinket")
    ship2_bow.trinkets.create!(name: "Bow Trinket")

    developers = Developer.includes(ship: [:parts]).where(id: [developer.id, developer2.id])

    assert_queries(4) do
      developers.each do |d|
        ActiveRecord.with_dynamic_includes(enabled: true) do
          assert_equal d.ship._load_tree_node.siblings, [ship, ship2]
          d.ship.parts.each do |part|
            assert_equal part._load_tree_node.siblings, [stern1, bow1, ship2_stern, ship2_bow]
            part.trinkets.each do |t|
              t
            end
          end
        end
      end
    end
  end

  def test_works_with_polymorphic_belongs_to
    author = Author.first
    comment = Post.first.comments.create!(body: "Comment", author: author)

    ActiveRecord.with_dynamic_includes(enabled: true) do
      comment = Comment.find(comment.id)
      assert_equal comment.author._load_tree_node.siblings, [comment.author]
    end
  end

  test "iterating over a sub array will properly load includes for all parents" do
    developer = Developer.first
    firm = Firm.create(name: "Nasa")
    firm2 = Firm.create(name: "SpaceX")
    developer.projects.create!(name: "Apollo", firm: firm)
    developer.projects.create!(name: "Icarus", firm: firm2)
    developer.projects.create!(name: "no results", firm: firm2)

    ActiveRecord.with_dynamic_includes(enabled: true) do
      developer = Developer.find(developer.id)
      scope = developer.projects
      projects1 = scope.select { |p| p.name.start_with?("Apollo") }
      projects2 = scope.select { |p| p.name.start_with?("Icarus") }
      firms = (projects1 + projects2).map(&:firm)
      firms.each do |firm|
        assert_not_nil firm
      end
    end
  end

  def test_works_with_polymorphic_belongs_to_when_selecting_from_array
    author = Author.first
    author2 = EncryptedAuthor.last
    post = Post.first
    comment = post.comments.create!(body: "Comment", author: author)
    comment1 = post.comments.create!(body: "Something", author: author2)
    comment2 = post.comments.create!(body: "no result", author: nil)

    ActiveRecord.with_dynamic_includes(enabled: true) do
      comments = Comment.where(id: [comment.id, comment1.id, comment2.id])
      comment1 = comments.select { |c| c.body.start_with?("Comment") }
      comment2 = comments.select { |c| c.body.start_with?("Something") }
      authors = (comment1 + comment2).map(&:author)
      assert authors.length == 2
      authors.each do |author|
        assert_not_nil author
      end
    end
  end

  def test_preload_groups_queries_with_same_scope_separates_the_siblings_dynamic_includes_properly_preloads
    book = books(:awdr)
    book.author = authors(:david)
    book.save
    post = posts(:welcome)
    post.author = authors(:mary)
    post.save
    member_type = MemberType.create(name: "club")
    member = Member.create(member_type: member_type)
    post.comments.create(body: "text", origin: member)

    book = Book.find(book.id)
    post = Post.find(post.id)

    davids_posts = authors(:david).posts.to_a
    marys_members = authors(:mary).members.to_a

    assert_queries(3) do
      ActiveRecord.with_dynamic_includes(enabled: true) do
        preloader = ActiveRecord::Associations::Preloader.new(records: [book, post], associations: :author)
        preloader.call
        book.author.posts.each do |post|
          assert_equal post._load_tree_node.siblings, davids_posts.select { |p| p.class.name == post.class.name }
        end

        assert_equal post.author.members.to_a.first._load_tree_node.siblings, marys_members
      end
    end
  end
end
