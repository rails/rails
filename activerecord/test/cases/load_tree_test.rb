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
require "models/post"
require "models/pirate"
require "models/treasure"
require "models/book"

class LoadTreeTest < ActiveRecord::TestCase
  fixtures :developers, :developers_projects, :projects, :ships, :books, :posts, :authors

  test "load tree has a parent and siblings" do
    tree = ActiveRecord::LoadTree.new(creator: Ship.first, siblings: [Ship.first, Ship.last]).set_records
    assert_equal [Ship.first, Ship.last], tree.siblings
  end

  test "if a load tree gets a sibling that is not of the same class it ignores it" do
    tree = ActiveRecord::LoadTree.new(creator: Ship.first, siblings: [Ship.first, Ship.last, Post.first]).set_records
    assert_equal [Ship.first, Ship.last], tree.siblings
  end

  test "an association is able to find its siblings" do
    developer = Developer.first
    ship = Ship.first
    stern1 = ShipPart.create!(name: "Stern", ship: ship)
    bow1 = ShipPart.create!(name: "bow", ship: ship)
    ship_parts_array = [stern1, bow1]
    trinket_for_parents = [
      stern1.trinkets.create!(name: "Stern Trinket"),
      stern1.trinkets.create!(name: "Stern Trinket 2"),
      bow1.trinkets.create!(name: "Bow Trinket")
    ].sort

    firm = Firm.create!(name: "NASA")
    project = Project.create!(name: "Apollo", firm: firm)
    project2 = Project.create!(name: "Apollo2", firm: firm)

    ship.update_column(:developer_id, developer.id)
    developer.projects << project
    developer.projects << project2
    developer = Developer.find(developer.id)

    ActiveRecord.with_dynamic_includes(enabled: true) do
      developer.projects.each do |project|
        assert_equal developer.projects.to_a, project._load_tree.siblings
      end
      assert_equal developer.ship._load_tree.siblings, [developer.ship]

      developer.ship.parts.each do |part|
        assert_equal ship_parts_array, part._load_tree.siblings
        part.trinkets.each do |trinket|
          assert_equal trinket_for_parents, trinket._load_tree.siblings
        end
      end

      developer.ship.parts.first.trinkets.first._load_tree.siblings.each do |trinket|
        assert_equal trinket_for_parents, trinket._load_tree.siblings
      end
    end
  end

  test "when a where at the top level is requested, it should have a load tree" do
    records = Developer.where(id: [Developer.first.id, Developer.last.id])
    records.each do |record|
      assert_equal record._load_tree.siblings, records
    end
  end


  test "when a record is duplicated it does not inherit the load tree" do
    records = Developer.where(id: [Developer.first.id, Developer.last.id])
    dup_records = records.map(&:dup)
    dup_records.each do |record|
      assert_equal record._load_tree.siblings, [record]
    end
  end

  test "when a record is at the top level it should be a root node and not have a parent" do
    records = Developer.where(id: [Developer.first.id, Developer.last.id])
    records.each do |record|
      assert record._load_tree.root?
      assert record._load_tree.parent.nil?
      assert_nil record._load_tree.association_name
    end
  end

  test "when a record is not at the top level it should have a parent and the association name that loaded it" do
    developer = Developer.first
    ship = Ship.first
    stern1 = ShipPart.create!(name: "Stern", ship: ship)
    bow1 = ShipPart.create!(name: "bow", ship: ship)
    stern1.trinkets.create!(name: "Stern Trinket")
    stern1.trinkets.create!(name: "Stern Trinket 2")
    bow1.trinkets.create!(name: "Bow Trinket")

    firm = Firm.create!(name: "NASA")
    project = Project.create!(name: "Apollo", firm: firm)
    project2 = Project.create!(name: "Apollo2", firm: firm)

    ship.update_column(:developer_id, developer.id)
    developer.projects << project
    developer.projects << project2
    developer = Developer.find(developer.id)

    assert developer._load_tree.root?
    assert_equal developer._load_tree.siblings, [developer]

    developer.projects.each do |project|
      assert_not project._load_tree.root?
      assert_equal developer, project._load_tree.parent
      assert_equal :projects, project._load_tree.association_name
    end
    assert_equal developer.ship._load_tree.parent, developer
    assert_equal :ship, developer.ship._load_tree.association_name

    developer.ship.parts.each do |part|
      assert_equal developer.ship, part._load_tree.parent
      assert_not part._load_tree.root?
      assert_equal :parts, part._load_tree.association_name
      part.trinkets.each do |trinket|
        assert_equal part, trinket._load_tree.parent
        assert_not trinket._load_tree.root?
        assert_equal :trinkets, trinket._load_tree.association_name
        assert_equal ship, trinket._load_tree.parent._load_tree.parent
      end
    end
  end

  test "when an association is loaded, it lets the parent know that it is loaded to assist with tree crawling" do
    developer = Developer.first
    ship = Ship.first
    stern1 = ShipPart.create!(name: "Stern", ship: ship)
    bow1 = ShipPart.create!(name: "bow", ship: ship)
    stern1.trinkets.create!(name: "Stern Trinket")
    stern1.trinkets.create!(name: "Stern Trinket 2")
    bow1.trinkets.create!(name: "Bow Trinket")

    firm = Firm.create!(name: "NASA")
    project = Project.create!(name: "Apollo", firm: firm)
    project2 = Project.create!(name: "Apollo2", firm: firm)

    ship.update_column(:developer_id, developer.id)
    developer.projects << project
    developer.projects << project2
    developer = Developer.find(developer.id)

    developer.projects.each do |project|
      assert developer._load_tree.loaded_associations.include?(:projects), "Loaded association should include :project #{developer._load_tree.loaded_associations}"
    end
    developer.ship
    assert developer._load_tree.loaded_associations.include?(:ship), "Loaded association should include :ship #{developer._load_tree.loaded_associations}"

    developer.ship.parts.each do |part|
      assert developer.ship._load_tree.loaded_associations.include?(:parts), "Loaded association should include :parts #{developer.ship._load_tree.loaded_associations}"
      part.trinkets.each do |trinket|
        assert part._load_tree.loaded_associations.include?(:trinkets), "Loaded association should include :trinkets #{part._load_tree.loaded_associations}"
      end
    end

    developer._load_tree.loaded_associations.each do |assoc|
      child = developer.send(assoc)
      if child.is_a?(Array) || child.is_a?(ActiveRecord::Associations::CollectionProxy)
        child.each do |c|
          assert_equal c._load_tree.parent, developer
        end
        last_child = child.last
      else
        assert_equal child._load_tree.parent, developer
        last_child = child
      end
      last_child._load_tree.loaded_associations.each do |assoc2|
        grandchild = last_child.send(assoc2).first
        assert_equal grandchild._load_tree.parent, last_child
      end
    end
  end

  test "load tree can get the full method path from the tree for a particular object" do
    developer = Developer.first
    ship = Ship.first
    stern1 = ShipPart.create!(name: "Stern", ship: ship)
    stern1.trinkets.create!(name: "Stern Trinket")

    firm = Firm.create!(name: "NASA")
    project = Project.create!(name: "Apollo", firm: firm)

    ship.update_column(:developer_id, developer.id)
    developer.projects.destroy_all
    developer.projects << project

    developer = Developer.find(developer.id)

    assert_equal "Developer.projects.firm", developer.projects.first.firm._load_tree.full_load_path
    assert_equal "Developer.ship.parts.trinkets", developer.ship.parts.first.trinkets.first._load_tree.full_load_path
  end

  def test_preload_groups_queries_with_same_scope_separates_the_siblings
    book = books(:awdr)
    book.author = authors(:david)
    book.save
    book2 = books(:rfr)
    book2.author = authors(:mary)
    book2.save
    post = posts(:welcome)
    post.author = authors(:mary)
    post.save


    book = Book.find(book.id)
    book2 = Book.find(book2.id)
    post = Post.find(post.id)
    assert_queries(1) do
      preloader = ActiveRecord::Associations::Preloader.new(records: [book, book2, post], associations: :author)
      preloader.call

      assert_equal book.author._load_tree.siblings, [book.author, book2.author]
      post.author
      assert_equal post.author._load_tree.siblings, [post.author]
    end
  end
end
