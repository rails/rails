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

def create_parent(parent, name)
  ActiveRecord::LoadTree::Parent.new(parent: parent, child_name: name, child_type: :association)
end

def create_parent_hash(parent, name)
  { instance: parent, child_name: name, child_type: :association }
end

class LoadTreeTest < ActiveRecord::TestCase
  fixtures :developers, :developers_projects, :projects, :ships, :books, :posts, :authors

  def setup
    ActiveRecord.load_tree_enabled = true
  end

  def teardown
    ActiveRecord.load_tree_enabled = false
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
    developer = Developer.includes(:projects, ship: [parts: [:trinkets]]).find(developer.id)

    developer.projects.each do |project|
      assert_equal developer.projects.to_a.sort, project._load_tree_node.siblings.sort
    end
    assert_equal developer.ship._load_tree_node.siblings, [developer.ship]

    developer.ship.parts.each do |part|
      assert_equal ship_parts_array, part._load_tree_node.siblings
      part.trinkets.each do |trinket|
        assert_equal trinket_for_parents, trinket._load_tree_node.siblings
      end
    end

    developer.ship.parts.first.trinkets.first._load_tree_node.siblings.each do |trinket|
      assert_equal trinket_for_parents, trinket._load_tree_node.siblings
    end
  end

  test "when a where at the top level is requested, it should have a load tree" do
    records = Developer.where(id: [Developer.first.id, Developer.last.id])
    records.each do |record|
      assert_equal record._load_tree_node.siblings, records
    end
  end


  test "when a record is duplicated it does not inherit the load tree" do
    records = Developer.where(id: [Developer.first.id, Developer.last.id])
    dup_records = records.map(&:dup)
    dup_records.each do |record|
      assert_equal record._load_tree_node.siblings, [record]
    end
  end

  test "when a record is at the top level it should be a root node and not have a parent" do
    records = Developer.where(id: [Developer.first.id, Developer.last.id])
    records.each do |record|
      assert record._load_tree_node.root?
      assert record._load_tree_node.parents.empty?
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

    assert developer._load_tree_node.root?
    assert_equal developer._load_tree_node.siblings, [developer]

    developer.projects.each do |project|
      assert_not project._load_tree_node.root?
      assert_equal [create_parent(developer, :projects)], project._load_tree_node.parents
    end
    assert_equal developer.ship._load_tree_node.parents, [create_parent(developer, :ship)]

    developer.ship.parts.each do |part|
      assert_equal [create_parent(developer.ship, :parts)], part._load_tree_node.parents
      assert_not part._load_tree_node.root?
      part.trinkets.each do |trinket|
        assert_equal [create_parent(part, :trinkets)], trinket._load_tree_node.parents
        assert_not trinket._load_tree_node.root?
        assert_equal [create_parent(ship, :parts)], trinket._load_tree_node.parents.first.parent._load_tree_node.parents
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
      assert developer._load_tree_node.children.include?(:projects), "Loaded association should include :project #{developer._load_tree_node.children}"
    end
    developer.ship
    assert developer._load_tree_node.children.include?(:ship), "Loaded association should include :ship #{developer._load_tree_node.children}"

    developer.ship.parts.each do |part|
      assert developer.ship._load_tree_node.children.include?(:parts), "Loaded association should include :parts #{developer.ship._load_tree_node.children}"
      part.trinkets.each do |trinket|
        assert part._load_tree_node.children.include?(:trinkets), "Loaded association should include :trinkets #{part._load_tree_node.children}"
      end
    end

    developer._load_tree_node.children.each do |assoc|
      child = developer.send(assoc)
      if child.is_a?(Array) || child.is_a?(ActiveRecord::Associations::CollectionProxy)
        child.each do |c|
          assert_equal c._load_tree_node.parents, [create_parent(developer, assoc)]
        end
        last_child = child.last
      else
        assert_equal child._load_tree_node.parents, [create_parent(developer, assoc)]
        last_child = child
      end
      last_child._load_tree_node.children.each do |assoc2|
        grandchild = last_child.send(assoc2).first
        assert_equal grandchild._load_tree_node.parents, [create_parent(last_child, assoc2)]
      end
    end
  end

  def test_preload_groups_queries_with_same_scope_but_different_sti_classes_separates_the_siblings_by_sti_class
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

      assert_equal book.author._load_tree_node.siblings, [book.author, book2.author]
      assert_equal book.author._load_tree_node.parents, [create_parent(book, :author)]
      post.author
      assert_equal post.author._load_tree_node.siblings, [post.author]
      assert_equal post.author._load_tree_node.parents, [create_parent(book2, :author), create_parent(post, :author)]
    end
  end

  test "preload sets a load tree" do
    ship = Ship.first
    ship2 = Ship.last
    10.times do |i|
      ShipPart.create!(name: "Stern#{i}", ship: ship)
      ShipPart.create!(name: "Stern#{i}", ship: ship2)
    end
    ships = Ship.preload(:parts).where(id: [ship.id, ship2.id]).to_a
    ship = ships.first
    tree = ship.parts.to_a.first._load_tree_node

    (ship.parts + ship2.parts).each do |part|
      assert tree.siblings.include?(part), "Siblings should include #{part.inspect}"
    end
    assert_equal [:parts], ship._load_tree_node.children
    assert_equal [create_parent(ship, :parts)], tree.parents
    assert_equal :association, tree.parents.first.child_type
    assert_equal :parts, tree.parents.first.child_name
  end

  test "eager load sets a load tree" do
    ship = Ship.first
    ship2 = Ship.last
    10.times do |i|
      ShipPart.create!(name: "Stern#{i}", ship: ship)
      ShipPart.create!(name: "Stern#{i}", ship: ship2)
    end
    ships = Ship.preload(:parts).where(id: [ship.id, ship2.id]).to_a
    ship = ships.first
    tree = ship.parts.to_a.first._load_tree_node
    (ship.parts + ship2.parts).each do |part|
      assert tree.siblings.include?(part), "Siblings should include #{part.inspect}"
    end
    assert_equal [:parts], ship._load_tree_node.children
    assert_equal [create_parent(ship, :parts)], tree.parents
    assert_equal :association, tree.parents.first.child_type
    assert_equal :parts, tree.parents.first.child_name
  end
end


class BookNonAR
  attr_accessor :author, :reviews
  include ActiveRecord::LoadTree

  def initialize(author)
    @author = author
    @reviews = []
  end
end

class ReviewNonAR
  attr_accessor :book, :author
  include ActiveRecord::LoadTree

  def initialize(book, author)
    @book = book
    book.reviews << self
    @author = author
    author.reviews << self
  end
end


class AuthorNonAR
  attr_accessor :reviews, :books, :author_bio
  include ActiveRecord::LoadTree

  def initialize(author_bio)
    @author_bio = author_bio
    author_bio.author = self
    @reviews = []
  end
end

class AuthorBioNonAR
  attr_accessor :author
  include ActiveRecord::LoadTree
end

class LoadTreeNodeTest < ActiveRecord::TestCase
  def setup
    @review_author_bio = AuthorBioNonAR.new
    @author_bio = AuthorBioNonAR.new
    @review_author = AuthorNonAR.new(@review_author_bio)
    @author = AuthorNonAR.new(@author_bio)

    @book1 = BookNonAR.new(@author)
    @book2 = BookNonAR.new(@author)
    @review = ReviewNonAR.new(@book1, @review_author)


    @book1._create_load_tree_node(siblings: [@book1, @book2]).set_records
    @book2._create_load_tree_node(siblings: [@book1, @book2]).set_records
    @review._create_load_tree_node(siblings: [@review], parents: [create_parent_hash(@book1, :reviews)]).set_records
    @author._create_load_tree_node(siblings: [@author], parents: [create_parent_hash(@book1, :author)]).set_records
    @author_bio._create_load_tree_node(siblings: [@author_bio], parents: [create_parent_hash(@author, :author_bio)]).set_records
    @review_author._create_load_tree_node(siblings: [@review_author], parents: [create_parent_hash(@review, :author)]).set_records
    @review_author_bio._create_load_tree_node(siblings: [@review_author_bio], parents: [create_parent_hash(@review_author, :author_bio)]).set_records
  end


  test "if a load tree gets a sibling that is not of the same class it ignores it" do
    tree = ActiveRecord::LoadTree::Node.new(creator: @book1, siblings: [@book1, @book2, @post]).set_records
    assert_equal [@book1, @book2], tree.siblings
  end

  test "attributes properly set" do
    tree = @review._load_tree_node
    assert_equal @review.class.name, tree.model_class_name
    assert_equal [create_parent(@book1, :reviews)], tree.parents
    assert_equal :reviews, tree.parents.first.child_name
    assert_equal :association, tree.parents.first.child_type
    assert_not tree.root?
  end

  test "parent/child associations setup up" do
    review_tree = @review._load_tree_node
    book_tree = review_tree.parents.first.parent._load_tree_node
    assert book_tree.root?
    assert_not review_tree.root?
    assert_equal [:reviews, :author], book_tree.children
    assert_equal [:author], review_tree.children
    assert_equal :association, review_tree.parents.first.child_type
    assert book_tree.parents.empty?
  end

  test "load trees can be traversed up" do
    tree = @review_author_bio._load_tree_node
    assert_equal tree.parents, [create_parent(@review_author, :author_bio)]
    assert_equal tree.parents.first.parent._load_tree_node.parents, [create_parent(@review, :author)]
    assert_equal tree.parents.first.parent._load_tree_node.parents.first.parent._load_tree_node.parents, [create_parent(@book1, :reviews)]
  end

  test "load trees can be traversed down" do
    child_recurse(@book1)
  end

  def child_recurse(parent)
    tree = parent._load_tree_node
    tree.children.each do |child_method|
      children_helper(parent, child_method)
    end
  end

  def children_helper(parent, child_method)
    child = parent.send(child_method)
    if child.is_a?(Array)
      child.each do |sub_child|
        assert_equal sub_child._load_tree_node.parents.first.parent, parent
        child_recurse(sub_child)
      end
    else
      assert_equal child._load_tree_node.parents.first.parent, parent
      child_recurse(child)
    end
  end
end
