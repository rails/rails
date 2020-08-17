# frozen_string_literal: true

require "cases/helper"
require "models/computer"
require "models/developer"
require "models/project"
require "models/company"
require "models/categorization"
require "models/category"
require "models/post"
require "models/author"
require "models/comment"
require "models/tag"
require "models/tagging"
require "models/person"
require "models/reader"
require "models/ship_part"
require "models/ship"
require "models/liquid"
require "models/molecule"
require "models/electron"
require "models/man"
require "models/interest"
require "models/pirate"
require "models/parrot"
require "models/bird"
require "models/treasure"
require "models/price_estimate"

class AssociationsTest < ActiveRecord::TestCase
  fixtures :accounts, :companies, :developers, :projects, :developers_projects,
           :computers, :people, :readers, :authors, :author_addresses, :author_favorites

  def test_eager_loading_should_not_change_count_of_children
    liquid = Liquid.create(name: "salty")
    molecule = liquid.molecules.create(name: "molecule_1")
    molecule.electrons.create(name: "electron_1")
    molecule.electrons.create(name: "electron_2")

    liquids = Liquid.includes(molecules: :electrons).references(:molecules).where("molecules.id is not null")
    assert_equal 1, liquids[0].molecules.length
  end

  def test_subselect
    author = authors :david
    favs = author.author_favorites
    fav2 = author.author_favorites.where(author: Author.where(id: author.id)).to_a
    assert_equal favs, fav2
  end

  def test_loading_the_association_target_should_keep_child_records_marked_for_destruction
    ship = Ship.create!(name: "The good ship Dollypop")
    part = ship.parts.create!(name: "Mast")
    part.mark_for_destruction
    assert_predicate ship.parts[0], :marked_for_destruction?
  end

  def test_loading_the_association_target_should_load_most_recent_attributes_for_child_records_marked_for_destruction
    ship = Ship.create!(name: "The good ship Dollypop")
    part = ship.parts.create!(name: "Mast")
    part.mark_for_destruction
    ShipPart.find(part.id).update_columns(name: "Deck")
    assert_equal "Deck", ship.parts[0].name
  end

  def test_include_with_order_works
    assert_nothing_raised { Account.all.merge!(order: "id", includes: :firm).first }
    assert_nothing_raised { Account.all.merge!(order: :id, includes: :firm).first }
  end

  def test_bad_collection_keys
    assert_raise(ArgumentError, "ActiveRecord should have barked on bad collection keys") do
      Class.new(ActiveRecord::Base).has_many(:wheels, name: "wheels")
    end
  end

  def test_should_construct_new_finder_sql_after_create
    person = Person.new first_name: "clark"
    assert_equal [], person.readers.to_a
    person.save!
    reader = Reader.create! person: person, post: Post.new(title: "foo", body: "bar")
    assert person.readers.find(reader.id)
  end

  def test_force_reload
    firm = Firm.new("name" => "A New Firm, Inc")
    firm.save
    firm.clients.each { } # forcing to load all clients
    assert firm.clients.empty?, "New firm shouldn't have client objects"
    assert_equal 0, firm.clients.size, "New firm should have 0 clients"

    client = Client.new("name" => "TheClient.com", "firm_id" => firm.id)
    client.save

    assert firm.clients.empty?, "New firm should have cached no client objects"
    assert_equal 0, firm.clients.size, "New firm should have cached 0 clients count"

    firm.clients.reload

    assert_not firm.clients.empty?, "New firm should have reloaded client objects"
    assert_equal 1, firm.clients.size, "New firm should have reloaded clients count"
  end

  def test_using_limitable_reflections_helper
    using_limitable_reflections = lambda { |reflections| Tagging.all.send :using_limitable_reflections?, reflections }
    belongs_to_reflections = [Tagging.reflect_on_association(:tag), Tagging.reflect_on_association(:super_tag)]
    has_many_reflections = [Tag.reflect_on_association(:taggings), Developer.reflect_on_association(:projects)]
    mixed_reflections = (belongs_to_reflections + has_many_reflections).uniq
    assert using_limitable_reflections.call(belongs_to_reflections), "Belong to associations are limitable"
    assert_not using_limitable_reflections.call(has_many_reflections), "All has many style associations are not limitable"
    assert_not using_limitable_reflections.call(mixed_reflections), "No collection associations (has many style) should pass"
  end

  def test_association_with_references
    firm = companies(:first_firm)
    assert_includes firm.association_with_references.references_values, "foo"
  end
end

class AssociationProxyTest < ActiveRecord::TestCase
  fixtures :authors, :author_addresses, :posts, :categorizations, :categories, :developers, :projects, :developers_projects

  def test_push_does_not_load_target
    david = authors(:david)

    david.posts << (post = Post.new(title: "New on Edge", body: "More cool stuff!"))
    assert_not_predicate david.posts, :loaded?
    assert_includes david.posts, post
  end

  def test_push_has_many_through_does_not_load_target
    david = authors(:david)

    david.categories << categories(:technology)
    assert_not_predicate david.categories, :loaded?
    assert_includes david.categories, categories(:technology)
  end

  def test_push_followed_by_save_does_not_load_target
    david = authors(:david)

    david.posts << (post = Post.new(title: "New on Edge", body: "More cool stuff!"))
    assert_not_predicate david.posts, :loaded?
    david.save
    assert_not_predicate david.posts, :loaded?
    assert_includes david.posts, post
  end

  def test_push_does_not_lose_additions_to_new_record
    josh = Author.new(name: "Josh")
    josh.posts << Post.new(title: "New on Edge", body: "More cool stuff!")
    assert_predicate josh.posts, :loaded?
    assert_equal 1, josh.posts.size
  end

  def test_append_behaves_like_push
    josh = Author.new(name: "Josh")
    josh.posts.append Post.new(title: "New on Edge", body: "More cool stuff!")
    assert_predicate josh.posts, :loaded?
    assert_equal 1, josh.posts.size
  end

  def test_prepend_is_not_defined
    josh = Author.new(name: "Josh")
    assert_raises(NoMethodError) { josh.posts.prepend Post.new }
  end

  def test_save_on_parent_does_not_load_target
    david = developers(:david)

    assert_not_predicate david.projects, :loaded?
    david.update_columns(created_at: Time.now)
    assert_not_predicate david.projects, :loaded?
  end

  def test_load_does_load_target
    david = developers(:david)

    assert_not_predicate david.projects, :loaded?
    david.projects.load
    assert_predicate david.projects, :loaded?
  end

  def test_inspect_does_not_reload_a_not_yet_loaded_target
    andreas = Developer.new name: "Andreas", log: "new developer added"
    assert_not_predicate andreas.audit_logs, :loaded?
    assert_match(/message: "new developer added"/, andreas.audit_logs.inspect)
  end

  def test_save_on_parent_saves_children
    developer = Developer.create name: "Bryan", salary: 50_000
    assert_equal 1, developer.reload.audit_logs.size
  end

  def test_create_via_association_with_block
    post = authors(:david).posts.create(title: "New on Edge") { |p| p.body = "More cool stuff!" }
    assert_equal post.title, "New on Edge"
    assert_equal post.body, "More cool stuff!"
  end

  def test_create_with_bang_via_association_with_block
    post = authors(:david).posts.create!(title: "New on Edge") { |p| p.body = "More cool stuff!" }
    assert_equal post.title, "New on Edge"
    assert_equal post.body, "More cool stuff!"
  end

  def test_reload_returns_association
    david = developers(:david)
    assert_nothing_raised do
      assert_equal david.projects, david.projects.reload.reload
    end
  end

  def test_proxy_association_accessor
    david = developers(:david)
    assert_equal david.association(:projects), david.projects.proxy_association
  end

  def test_scoped_allows_conditions
    assert developers(:david).projects.merge(where: "foo").to_sql.include?("foo")
  end

  test "getting a scope from an association" do
    david = developers(:david)

    assert david.projects.scope.is_a?(ActiveRecord::Relation)
    assert_equal david.projects, david.projects.scope
  end

  test "proxy object is cached" do
    david = developers(:david)
    assert_same david.projects, david.projects
  end

  test "proxy object can be stubbed" do
    david = developers(:david)
    david.projects.define_singleton_method(:extra_method) { 42 }

    assert_equal 42, david.projects.extra_method
  end

  test "inverses get set of subsets of the association" do
    man = Man.create
    man.interests.create

    man = Man.find(man.id)

    assert_queries(1) do
      assert_equal man, man.interests.where("1=1").first.man
    end
  end

  test "first! works on loaded associations" do
    david = authors(:david)
    assert_equal david.first_posts.first, david.first_posts.reload.first!
    assert_predicate david.first_posts, :loaded?
    assert_no_queries { david.first_posts.first! }
  end

  def test_pluck_uses_loaded_target
    david = authors(:david)
    assert_equal david.first_posts.pluck(:title), david.first_posts.load.pluck(:title)
    assert_predicate david.first_posts, :loaded?
    assert_no_queries { david.first_posts.pluck(:title) }
  end

  def test_reset_unloads_target
    david = authors(:david)
    david.posts.reload

    assert_predicate david.posts, :loaded?
    assert_predicate david.posts, :loaded
    david.posts.reset
    assert_not_predicate david.posts, :loaded?
    assert_not_predicate david.posts, :loaded
  end
end

class OverridingAssociationsTest < ActiveRecord::TestCase
  class DifferentPerson < ActiveRecord::Base; end

  class PeopleList < ActiveRecord::Base
    has_and_belongs_to_many :has_and_belongs_to_many, before_add: :enlist
    has_many :has_many, before_add: :enlist
    belongs_to :belongs_to
    has_one :has_one
  end

  class DifferentPeopleList < PeopleList
    # Different association with the same name, callbacks should be omitted here.
    has_and_belongs_to_many :has_and_belongs_to_many, class_name: "DifferentPerson"
    has_many :has_many, class_name: "DifferentPerson"
    belongs_to :belongs_to, class_name: "DifferentPerson"
    has_one :has_one, class_name: "DifferentPerson"
  end

  def test_habtm_association_redefinition_callbacks_should_differ_and_not_inherited
    # redeclared association on AR descendant should not inherit callbacks from superclass
    callbacks = PeopleList.before_add_for_has_and_belongs_to_many
    assert_equal(1, callbacks.length)
    callbacks = DifferentPeopleList.before_add_for_has_and_belongs_to_many
    assert_equal([], callbacks)
  end

  def test_has_many_association_redefinition_callbacks_should_differ_and_not_inherited
    # redeclared association on AR descendant should not inherit callbacks from superclass
    callbacks = PeopleList.before_add_for_has_many
    assert_equal(1, callbacks.length)
    callbacks = DifferentPeopleList.before_add_for_has_many
    assert_equal([], callbacks)
  end

  def test_habtm_association_redefinition_reflections_should_differ_and_not_inherited
    assert_not_equal(
      PeopleList.reflect_on_association(:has_and_belongs_to_many),
      DifferentPeopleList.reflect_on_association(:has_and_belongs_to_many)
    )
  end

  def test_has_many_association_redefinition_reflections_should_differ_and_not_inherited
    assert_not_equal(
      PeopleList.reflect_on_association(:has_many),
      DifferentPeopleList.reflect_on_association(:has_many)
    )
  end

  def test_belongs_to_association_redefinition_reflections_should_differ_and_not_inherited
    assert_not_equal(
      PeopleList.reflect_on_association(:belongs_to),
      DifferentPeopleList.reflect_on_association(:belongs_to)
    )
  end

  def test_has_one_association_redefinition_reflections_should_differ_and_not_inherited
    assert_not_equal(
      PeopleList.reflect_on_association(:has_one),
      DifferentPeopleList.reflect_on_association(:has_one)
    )
  end

  def test_requires_symbol_argument
    assert_raises ArgumentError do
      Class.new(Post) do
        belongs_to "author"
      end
    end
  end
end

class PreloaderTest < ActiveRecord::TestCase
  fixtures :posts, :comments

  def test_preload_with_scope
    post = posts(:welcome)

    preloader = ActiveRecord::Associations::Preloader.new
    preloader.preload([post], :comments, Comment.where(body: "Thank you for the welcome"))

    assert_predicate post.comments, :loaded?
    assert_equal [comments(:greetings)], post.comments
  end
end

class GeneratedMethodsTest < ActiveRecord::TestCase
  fixtures :developers, :computers, :posts, :comments

  def test_association_methods_override_attribute_methods_of_same_name
    assert_equal(developers(:david), computers(:workstation).developer)
    # this next line will fail if the attribute methods module is generated lazily
    # after the association methods module is generated
    assert_equal(developers(:david), computers(:workstation).developer)
    assert_equal(developers(:david).id, computers(:workstation)[:developer])
  end

  def test_model_method_overrides_association_method
    assert_equal(comments(:greetings).body, posts(:welcome).first_comment)
  end

  module MyModule
    def comments; :none end
  end

  class MyArticle < ActiveRecord::Base
    self.table_name = "articles"
    include MyModule
    has_many :comments, inverse_of: false
  end

  def test_included_module_overwrites_association_methods
    assert_equal :none, MyArticle.new.comments
  end
end

class WithAnnotationsTest < ActiveRecord::TestCase
  fixtures :pirates, :parrots

  def test_belongs_to_with_annotation_includes_a_query_comment
    pirate = SpacePirate.where.not(parrot_id: nil).first
    assert pirate, "should have a Pirate record"

    log = capture_sql do
      pirate.parrot
    end
    assert_not_predicate log, :empty?
    assert_predicate log.select { |query| query.match?(%r{/\*}) }, :empty?

    assert_sql(%r{/\* that tells jokes \*/}) do
      pirate.parrot_with_annotation
    end
  end

  def test_has_and_belongs_to_many_with_annotation_includes_a_query_comment
    pirate = SpacePirate.first
    assert pirate, "should have a Pirate record"

    log = capture_sql do
      pirate.parrots.first
    end
    assert_not_predicate log, :empty?
    assert_predicate log.select { |query| query.match?(%r{/\*}) }, :empty?

    assert_sql(%r{/\* that are very colorful \*/}) do
      pirate.parrots_with_annotation.first
    end
  end

  def test_has_one_with_annotation_includes_a_query_comment
    pirate = SpacePirate.first
    assert pirate, "should have a Pirate record"

    log = capture_sql do
      pirate.ship
    end
    assert_not_predicate log, :empty?
    assert_predicate log.select { |query| query.match?(%r{/\*}) }, :empty?

    assert_sql(%r{/\* that is a rocket \*/}) do
      pirate.ship_with_annotation
    end
  end

  def test_has_many_with_annotation_includes_a_query_comment
    pirate = SpacePirate.first
    assert pirate, "should have a Pirate record"

    log = capture_sql do
      pirate.birds.first
    end
    assert_not_predicate log, :empty?
    assert_predicate log.select { |query| query.match?(%r{/\*}) }, :empty?

    assert_sql(%r{/\* that are also parrots \*/}) do
      pirate.birds_with_annotation.first
    end
  end

  def test_has_many_through_with_annotation_includes_a_query_comment
    pirate = SpacePirate.first
    assert pirate, "should have a Pirate record"

    log = capture_sql do
      pirate.treasure_estimates.first
    end
    assert_not_predicate log, :empty?
    assert_predicate log.select { |query| query.match?(%r{/\*}) }, :empty?

    assert_sql(%r{/\* yarrr \*/}) do
      pirate.treasure_estimates_with_annotation.first
    end
  end

  def test_has_many_through_with_annotation_includes_a_query_comment_when_eager_loading
    pirate = SpacePirate.first
    assert pirate, "should have a Pirate record"

    log = capture_sql do
      pirate.treasure_estimates.first
    end
    assert_not_predicate log, :empty?
    assert_predicate log.select { |query| query.match?(%r{/\*}) }, :empty?

    assert_sql(%r{/\* yarrr \*/}) do
      SpacePirate.includes(:treasure_estimates_with_annotation, :treasures).first
    end
  end
end
