# frozen_string_literal: true

require "cases/helper"
require "models/developer"
require "models/computer"
require "models/project"
require "models/company"
require "models/course"
require "models/customer"
require "models/order"
require "models/categorization"
require "models/category"
require "models/post"
require "models/author"
require "models/tag"
require "models/tagging"
require "models/parrot"
require "models/person"
require "models/pirate"
require "models/professor"
require "models/treasure"
require "models/price_estimate"
require "models/club"
require "models/user"
require "models/member"
require "models/membership"
require "models/sponsor"
require "models/country"
require "models/treaty"
require "models/vertex"
require "models/publisher"
require "models/publisher/article"
require "models/publisher/magazine"
require "active_support/core_ext/string/conversions"

class ProjectWithAfterCreateHook < ActiveRecord::Base
  self.table_name = "projects"
  has_and_belongs_to_many :developers,
    class_name: "DeveloperForProjectWithAfterCreateHook",
    join_table: "developers_projects",
    foreign_key: "project_id",
    association_foreign_key: "developer_id"

  after_create :add_david

  def add_david
    david = DeveloperForProjectWithAfterCreateHook.find_by_name("David")
    david.projects << self
  end
end

class DeveloperForProjectWithAfterCreateHook < ActiveRecord::Base
  self.table_name = "developers"
  has_and_belongs_to_many :projects,
    class_name: "ProjectWithAfterCreateHook",
    join_table: "developers_projects",
    association_foreign_key: "project_id",
    foreign_key: "developer_id"
end

class ProjectWithSymbolsForKeys < ActiveRecord::Base
  self.table_name = "projects"
  has_and_belongs_to_many :developers,
    class_name: "DeveloperWithSymbolsForKeys",
    join_table: :developers_projects,
    foreign_key: :project_id,
    association_foreign_key: "developer_id"
end

class DeveloperWithSymbolsForKeys < ActiveRecord::Base
  self.table_name = "developers"
  has_and_belongs_to_many :projects,
    class_name: "ProjectWithSymbolsForKeys",
    join_table: :developers_projects,
    association_foreign_key: :project_id,
    foreign_key: "developer_id"
end

class SubDeveloper < Developer
  self.table_name = "developers"
  has_and_belongs_to_many :special_projects,
    join_table: "developers_projects",
    foreign_key: "project_id",
    association_foreign_key: "developer_id"
end

class DeveloperWithSymbolClassName < Developer
  has_and_belongs_to_many :projects, class_name: :ProjectWithSymbolsForKeys
end

class DeveloperWithExtendOption < Developer
  module NamedExtension
    def category
      "sns"
    end
  end

  has_and_belongs_to_many :projects, extend: NamedExtension
end

class ProjectUnscopingDavidDefaultScope < ActiveRecord::Base
  self.table_name = "projects"
  has_and_belongs_to_many :developers, -> { unscope(where: "name") },
    class_name: "LazyBlockDeveloperCalledDavid",
    join_table: "developers_projects",
    foreign_key: "project_id",
    association_foreign_key: "developer_id"
end

class Kitchen < ActiveRecord::Base
  has_one :sink
end

class Sink < ActiveRecord::Base
  has_and_belongs_to_many :sources, join_table: :edges
  belongs_to :kitchen
  accepts_nested_attributes_for :kitchen
end

class Source < ActiveRecord::Base
  self.table_name = "men"
  has_and_belongs_to_many :sinks, join_table: :edges
end

class HasAndBelongsToManyAssociationsTest < ActiveRecord::TestCase
  fixtures :accounts, :companies, :categories, :posts, :categories_posts, :developers, :projects, :developers_projects,
           :parrots, :pirates, :parrots_pirates, :treasures, :price_estimates, :tags, :taggings, :computers

  def setup_data_for_habtm_case
    ActiveRecord::Base.connection.execute("delete from countries_treaties")

    country = Country.new(name: "India")
    country.country_id = "c1"
    country.save!

    treaty = Treaty.new(name: "peace")
    treaty.treaty_id = "t1"
    country.treaties << treaty
  end

  def test_marshal_dump
    post = posts :welcome
    preloaded = Post.includes(:categories).find post.id
    assert_equal preloaded, Marshal.load(Marshal.dump(preloaded))
  end

  def test_should_property_quote_string_primary_keys
    setup_data_for_habtm_case

    con = ActiveRecord::Base.connection
    sql = "select * from countries_treaties"
    record = con.select_rows(sql).last
    assert_equal "c1", record[0]
    assert_equal "t1", record[1]
  end

  def test_proper_usage_of_primary_keys_and_join_table
    setup_data_for_habtm_case

    assert_equal "country_id", Country.primary_key
    assert_equal "treaty_id", Treaty.primary_key

    country = Country.first
    assert_equal 1, country.treaties.count
  end

  def test_join_table_composite_primary_key_should_not_warn
    country = Country.new(name: "India")
    country.country_id = "c1"
    country.save!

    treaty = Treaty.new(name: "peace")
    treaty.treaty_id = "t1"
    warning = capture(:stderr) do
      country.treaties << treaty
    end
    assert_no_match(/WARNING: Active Record does not support composite primary key\./, warning)
  end

  def test_has_and_belongs_to_many
    david = Developer.find(1)

    assert_not_empty david.projects
    assert_equal 2, david.projects.size

    active_record = Project.find(1)
    assert_not_empty active_record.developers
    assert_equal 3, active_record.developers.size
    assert_includes active_record.developers, david
  end

  def test_adding_single
    jamis = Developer.find(2)
    jamis.projects.reload # causing the collection to load
    action_controller = Project.find(2)
    assert_equal 1, jamis.projects.size
    assert_equal 1, action_controller.developers.size

    jamis.projects << action_controller

    assert_equal 2, jamis.projects.size
    assert_equal 2, jamis.projects.reload.size
    assert_equal 2, action_controller.developers.reload.size
  end

  def test_adding_type_mismatch
    jamis = Developer.find(2)
    assert_raise(ActiveRecord::AssociationTypeMismatch) { jamis.projects << nil }
    assert_raise(ActiveRecord::AssociationTypeMismatch) { jamis.projects << 1 }
  end

  def test_adding_from_the_project
    jamis = Developer.find(2)
    action_controller = Project.find(2)
    action_controller.developers.reload
    assert_equal 1, jamis.projects.size
    assert_equal 1, action_controller.developers.size

    action_controller.developers << jamis

    assert_equal 2, jamis.projects.reload.size
    assert_equal 2, action_controller.developers.size
    assert_equal 2, action_controller.developers.reload.size
  end

  def test_adding_from_the_project_fixed_timestamp
    jamis = Developer.find(2)
    action_controller = Project.find(2)
    action_controller.developers.reload
    assert_equal 1, jamis.projects.size
    assert_equal 1, action_controller.developers.size
    updated_at = jamis.updated_at

    action_controller.developers << jamis

    assert_equal updated_at, jamis.updated_at
    assert_equal 2, jamis.projects.reload.size
    assert_equal 2, action_controller.developers.size
    assert_equal 2, action_controller.developers.reload.size
  end

  def test_adding_multiple
    aredridel = Developer.new("name" => "Aredridel")
    aredridel.save
    aredridel.projects.reload
    aredridel.projects.push(Project.find(1), Project.find(2))
    assert_equal 2, aredridel.projects.size
    assert_equal 2, aredridel.projects.reload.size
  end

  def test_adding_a_collection
    aredridel = Developer.new("name" => "Aredridel")
    aredridel.save
    aredridel.projects.reload
    aredridel.projects.concat([Project.find(1), Project.find(2)])
    assert_equal 2, aredridel.projects.size
    assert_equal 2, aredridel.projects.reload.size
  end

  def test_habtm_adding_before_save
    no_of_devels = Developer.count
    no_of_projects = Project.count
    aredridel = Developer.new("name" => "Aredridel")
    aredridel.projects.concat([Project.find(1), p = Project.new("name" => "Projekt")])
    assert_not_predicate aredridel, :persisted?
    assert_not_predicate p, :persisted?
    assert aredridel.save
    assert_predicate aredridel, :persisted?
    assert_equal no_of_devels + 1, Developer.count
    assert_equal no_of_projects + 1, Project.count
    assert_equal 2, aredridel.projects.size
    assert_equal 2, aredridel.projects.reload.size
  end

  def test_habtm_saving_multiple_relationships
    new_project = Project.new("name" => "Grimetime")
    amount_of_developers = 4
    developers = (0...amount_of_developers).collect { |i| Developer.create(name: "JME #{i}") }.reverse

    new_project.developer_ids = [developers[0].id, developers[1].id]
    new_project.developers_with_callback_ids = [developers[2].id, developers[3].id]
    assert new_project.save

    new_project.reload
    assert_equal amount_of_developers, new_project.developers.size
    assert_equal developers, new_project.developers
  end

  def test_habtm_distinct_order_preserved
    assert_equal developers(:poor_jamis, :jamis, :david), projects(:active_record).non_unique_developers
    assert_equal developers(:poor_jamis, :jamis, :david), projects(:active_record).developers
  end

  def test_habtm_collection_size_from_build
    devel = Developer.create("name" => "Fred Wu")
    devel.projects << Project.create("name" => "Grimetime")
    devel.projects.build

    assert_equal 2, devel.projects.size
  end

  def test_habtm_collection_size_from_params
    devel = Developer.new(
      projects_attributes: {
        "0" => {}
      })

    assert_equal 1, devel.projects.size
  end

  def test_build
    devel = Developer.find(1)
    proj = assert_no_queries(ignore_none: false) { devel.projects.build("name" => "Projekt") }
    assert_not_predicate devel.projects, :loaded?

    assert_equal devel.projects.last, proj
    assert_predicate devel.projects, :loaded?

    assert_not_predicate proj, :persisted?
    devel.save
    assert_predicate proj, :persisted?
    assert_equal devel.projects.last, proj
    assert_equal Developer.find(1).projects.sort_by(&:id).last, proj  # prove join table is updated
  end

  def test_new_aliased_to_build
    devel = Developer.find(1)
    proj = assert_no_queries(ignore_none: false) { devel.projects.new("name" => "Projekt") }
    assert_not_predicate devel.projects, :loaded?

    assert_equal devel.projects.last, proj
    assert_predicate devel.projects, :loaded?

    assert_not_predicate proj, :persisted?
    devel.save
    assert_predicate proj, :persisted?
    assert_equal devel.projects.last, proj
    assert_equal Developer.find(1).projects.sort_by(&:id).last, proj  # prove join table is updated
  end

  def test_build_by_new_record
    devel = Developer.new(name: "Marcel", salary: 75000)
    devel.projects.build(name: "Make bed")
    proj2 = devel.projects.build(name: "Lie in it")
    assert_equal devel.projects.last, proj2
    assert_not_predicate proj2, :persisted?
    devel.save
    assert_predicate devel, :persisted?
    assert_predicate proj2, :persisted?
    assert_equal devel.projects.last, proj2
    assert_equal Developer.find_by_name("Marcel").projects.last, proj2  # prove join table is updated
  end

  def test_create
    devel = Developer.find(1)
    proj = devel.projects.create("name" => "Projekt")
    assert_not_predicate devel.projects, :loaded?

    assert_equal devel.projects.last, proj
    assert_not_predicate devel.projects, :loaded?

    assert_predicate proj, :persisted?
    assert_equal Developer.find(1).projects.sort_by(&:id).last, proj  # prove join table is updated
  end

  def test_creation_respects_hash_condition
    # in Oracle '' is saved as null therefore need to save ' ' in not null column
    post = categories(:general).post_with_conditions.build(body: " ")

    assert        post.save
    assert_equal  "Yet Another Testing Title", post.title

    # in Oracle '' is saved as null therefore need to save ' ' in not null column
    another_post = categories(:general).post_with_conditions.create(body: " ")

    assert_predicate        another_post, :persisted?
    assert_equal  "Yet Another Testing Title", another_post.title
  end

  def test_distinct_after_the_fact
    dev = developers(:jamis)
    dev.projects << projects(:active_record)
    dev.projects << projects(:active_record)

    assert_equal 3, dev.projects.size
    assert_equal 1, dev.projects.uniq.size
  end

  def test_distinct_before_the_fact
    projects(:active_record).developers << developers(:jamis)
    projects(:active_record).developers << developers(:david)
    assert_equal 3, projects(:active_record, :reload).developers.size
  end

  def test_distinct_option_prevents_duplicate_push
    project = projects(:active_record)
    project.developers << developers(:jamis)
    project.developers << developers(:david)
    assert_equal 3, project.developers.size

    project.developers << developers(:david)
    project.developers << developers(:jamis)
    assert_equal 3, project.developers.size
  end

  def test_distinct_when_association_already_loaded
    project = projects(:active_record)
    project.developers << [ developers(:jamis), developers(:david), developers(:jamis), developers(:david) ]
    assert_equal 3, Project.includes(:developers).find(project.id).developers.size
  end

  def test_deleting
    david = Developer.find(1)
    active_record = Project.find(1)
    david.projects.reload
    assert_equal 2, david.projects.size
    assert_equal 3, active_record.developers.size

    david.projects.delete(active_record)

    assert_equal 1, david.projects.size
    assert_equal 1, david.projects.reload.size
    assert_equal 2, active_record.developers.reload.size
  end

  def test_deleting_array
    david = Developer.find(1)
    david.projects.reload
    david.projects.delete(Project.all.to_a)
    assert_equal 0, david.projects.size
    assert_equal 0, david.projects.reload.size
  end

  def test_deleting_all
    david = Developer.find(1)
    david.projects.reload
    david.projects.clear
    assert_equal 0, david.projects.size
    assert_equal 0, david.projects.reload.size
  end

  def test_removing_associations_on_destroy
    david = DeveloperWithBeforeDestroyRaise.find(1)
    assert_not_empty david.projects
    david.destroy
    assert_empty david.projects
    assert_empty DeveloperWithBeforeDestroyRaise.connection.select_all("SELECT * FROM developers_projects WHERE developer_id = 1")
  end

  def test_destroying
    david = Developer.find(1)
    project = Project.find(1)
    david.projects.reload
    assert_equal 2, david.projects.size
    assert_equal 3, project.developers.size

    assert_no_difference "Project.count" do
      david.projects.destroy(project)
    end

    join_records = Developer.connection.select_all("SELECT * FROM developers_projects WHERE developer_id = #{david.id} AND project_id = #{project.id}")
    assert_empty join_records

    assert_equal 1, david.reload.projects.size
    assert_equal 1, david.projects.reload.size
  end

  def test_destroying_many
    david = Developer.find(1)
    david.projects.reload
    projects = Project.all.to_a

    assert_no_difference "Project.count" do
      david.projects.destroy(*projects)
    end

    join_records = Developer.connection.select_all("SELECT * FROM developers_projects WHERE developer_id = #{david.id}")
    assert_empty join_records

    assert_equal 0, david.reload.projects.size
    assert_equal 0, david.projects.reload.size
  end

  def test_destroy_all
    david = Developer.find(1)
    david.projects.reload
    assert_not_empty david.projects

    assert_no_difference "Project.count" do
      david.projects.destroy_all
    end

    join_records = Developer.connection.select_all("SELECT * FROM developers_projects WHERE developer_id = #{david.id}")
    assert_empty join_records

    assert_empty david.projects
    assert_empty david.projects.reload
  end

  def test_destroy_associations_destroys_multiple_associations
    george = parrots(:george)
    assert_not_empty george.pirates
    assert_not_empty george.treasures

    assert_no_difference "Pirate.count" do
      assert_no_difference "Treasure.count" do
        george.destroy_associations
      end
    end

    join_records = Parrot.connection.select_all("SELECT * FROM parrots_pirates WHERE parrot_id = #{george.id}")
    assert_empty join_records
    assert_empty george.pirates.reload

    join_records = Parrot.connection.select_all("SELECT * FROM parrots_treasures WHERE parrot_id = #{george.id}")
    assert_empty join_records
    assert_empty george.treasures.reload
  end

  def test_associations_with_conditions
    assert_equal 3, projects(:active_record).developers.size
    assert_equal 1, projects(:active_record).developers_named_david.size
    assert_equal 1, projects(:active_record).developers_named_david_with_hash_conditions.size

    assert_equal developers(:david), projects(:active_record).developers_named_david.find(developers(:david).id)
    assert_equal developers(:david), projects(:active_record).developers_named_david_with_hash_conditions.find(developers(:david).id)
    assert_equal developers(:david), projects(:active_record).salaried_developers.find(developers(:david).id)

    projects(:active_record).developers_named_david.clear
    assert_equal 2, projects(:active_record, :reload).developers.size
  end

  def test_find_in_association
    # Using sql
    assert_equal developers(:david), projects(:active_record).developers.find(developers(:david).id), "SQL find"

    # Using ruby
    active_record = projects(:active_record)
    active_record.developers.reload
    assert_equal developers(:david), active_record.developers.find(developers(:david).id), "Ruby find"
  end

  def test_include_uses_array_include_after_loaded
    project = projects(:active_record)
    project.developers.load_target

    developer = project.developers.first

    assert_no_queries(ignore_none: false) do
      assert_predicate project.developers, :loaded?
      assert_includes project.developers, developer
    end
  end

  def test_include_checks_if_record_exists_if_target_not_loaded
    project = projects(:active_record)
    developer = project.developers.first

    project.reload
    assert_not_predicate  project.developers, :loaded?
    assert_queries(1) do
      assert_includes project.developers, developer
    end
    assert_not_predicate  project.developers, :loaded?
  end

  def test_include_returns_false_for_non_matching_record_to_verify_scoping
    project = projects(:active_record)
    developer = Developer.create name: "Bryan", salary: 50_000

    assert_not_predicate  project.developers, :loaded?
    assert ! project.developers.include?(developer)
  end

  def test_find_with_merged_options
    assert_equal 1, projects(:active_record).limited_developers.size
    assert_equal 1, projects(:active_record).limited_developers.to_a.size
    assert_equal 3, projects(:active_record).limited_developers.limit(nil).to_a.size
  end

  def test_dynamic_find_should_respect_association_order
    # Developers are ordered 'name DESC, id DESC'
    high_id_jamis = projects(:active_record).developers.create(name: "Jamis")

    assert_equal high_id_jamis, projects(:active_record).developers.merge(where: "name = 'Jamis'").first
    assert_equal high_id_jamis, projects(:active_record).developers.find_by_name("Jamis")
  end

  def test_find_should_append_to_association_order
    ordered_developers = projects(:active_record).developers.order("projects.id")
    assert_equal ["developers.name desc, developers.id desc", "projects.id"], ordered_developers.order_values
  end

  def test_dynamic_find_all_should_respect_readonly_access
    projects(:active_record).readonly_developers.each { |d| assert_raise(ActiveRecord::ReadOnlyRecord) { d.save!  } if d.valid? }
    projects(:active_record).readonly_developers.each(&:readonly?)
  end

  def test_new_with_values_in_collection
    jamis = DeveloperForProjectWithAfterCreateHook.find_by_name("Jamis")
    david = DeveloperForProjectWithAfterCreateHook.find_by_name("David")
    project = ProjectWithAfterCreateHook.new(name: "Cooking with Bertie")
    project.developers << jamis
    project.save!
    project.reload

    assert_includes project.developers, jamis
    assert_includes project.developers, david
  end

  def test_find_in_association_with_options
    developers = projects(:active_record).developers.to_a
    assert_equal 3, developers.size

    assert_equal developers(:poor_jamis), projects(:active_record).developers.where("salary < 10000").first
  end

  def test_association_with_extend_option
    eponine = DeveloperWithExtendOption.create(name: "Eponine")
    assert_equal "sns", eponine.projects.category
  end

  def test_replace_with_less
    david = developers(:david)
    david.projects = [projects(:action_controller)]
    assert david.save
    assert_equal 1, david.projects.length
  end

  def test_replace_with_new
    david = developers(:david)
    david.projects = [projects(:action_controller), Project.new("name" => "ActionWebSearch")]
    david.save
    assert_equal 2, david.projects.length
    assert_not_includes david.projects, projects(:active_record)
  end

  def test_replace_on_new_object
    new_developer = Developer.new("name" => "Matz")
    new_developer.projects = [projects(:action_controller), Project.new("name" => "ActionWebSearch")]
    new_developer.save
    assert_equal 2, new_developer.projects.length
  end

  def test_consider_type
    developer = Developer.first
    special_project = SpecialProject.create("name" => "Special Project")

    other_project = developer.projects.first
    developer.special_projects << special_project
    developer.reload

    assert_includes developer.projects, special_project
    assert_includes developer.special_projects, special_project
    assert_not_includes developer.special_projects, other_project
  end

  def test_symbol_join_table
    developer = Developer.first
    sp = developer.sym_special_projects.create("name" => "omg")
    developer.reload
    assert_includes developer.sym_special_projects, sp
  end

  def test_update_attributes_after_push_without_duplicate_join_table_rows
    developer = Developer.new("name" => "Kano")
    project = SpecialProject.create("name" => "Special Project")
    assert developer.save
    developer.projects << project
    developer.update_columns("name" => "Bruza")
    assert_equal 1, Developer.connection.select_value(<<-end_sql).to_i
      SELECT count(*) FROM developers_projects
      WHERE project_id = #{project.id}
      AND developer_id = #{developer.id}
    end_sql
  end

  def test_updating_attributes_on_non_rich_associations
    welcome = categories(:technology).posts.first
    welcome.title = "Something else"
    assert welcome.save!
  end

  def test_habtm_respects_select
    categories(:technology).select_testing_posts.reload.each do |o|
      assert_respond_to o, :correctness_marker
    end
    assert_respond_to categories(:technology).select_testing_posts.first, :correctness_marker
  end

  def test_habtm_selects_all_columns_by_default
    assert_equal Project.column_names.sort, developers(:david).projects.first.attributes.keys.sort
  end

  def test_habtm_respects_select_query_method
    assert_equal ["id"], developers(:david).projects.select(:id).first.attributes.keys
  end

  def test_join_table_alias
    # FIXME: `references` has no impact on the aliases generated for the join
    # query.  The fact that we pass `:developers_projects_join` to `references`
    # and that the SQL string contains `developers_projects_join` is merely a
    # coincidence.
    assert_equal(
      3,
      Developer.references(:developers_projects_join).merge(
        includes: { projects: :developers },
        where: "projects_developers_projects_join.joined_on IS NOT NULL"
      ).to_a.size
    )
  end

  def test_join_with_group
    # FIXME: `references` has no impact on the aliases generated for the join
    # query.  The fact that we pass `:developers_projects_join` to `references`
    # and that the SQL string contains `developers_projects_join` is merely a
    # coincidence.
    group = Developer.columns.inject([]) do |g, c|
      g << "developers.#{c.name}"
      g << "developers_projects_2.#{c.name}"
    end
    Project.columns.each { |c| group << "projects.#{c.name}" }

    assert_equal(
      3,
      Developer.references(:developers_projects_join).merge(
        includes: { projects: :developers }, where: "projects_developers_projects_join.joined_on IS NOT NULL",
        group: group.join(",")
      ).to_a.size
    )
  end

  def test_find_grouped
    all_posts_from_category1 = Post.all.merge!(where: "category_id = 1", joins: :categories).to_a
    grouped_posts_of_category1 = Post.all.merge!(where: "category_id = 1", group: "author_id", select: "count(posts.id) as posts_count", joins: :categories).to_a
    assert_equal 5, all_posts_from_category1.size
    assert_equal 2, grouped_posts_of_category1.size
  end

  def test_find_scoped_grouped
    assert_equal 5, categories(:general).posts_grouped_by_title.to_a.size
    assert_equal 1, categories(:technology).posts_grouped_by_title.to_a.size
  end

  def test_find_scoped_grouped_having
    assert_equal 2, projects(:active_record).well_paid_salary_groups.to_a.size
    assert projects(:active_record).well_paid_salary_groups.all? { |g| g.salary > 10000 }
  end

  def test_get_ids
    assert_equal projects(:active_record, :action_controller).map(&:id).sort, developers(:david).project_ids.sort
    assert_equal [projects(:active_record).id], developers(:jamis).project_ids
  end

  def test_get_ids_for_loaded_associations
    developer = developers(:david)
    developer.projects.reload
    assert_queries(0) do
      developer.project_ids
      developer.project_ids
    end
  end

  def test_get_ids_for_unloaded_associations_does_not_load_them
    developer = developers(:david)
    assert_not_predicate developer.projects, :loaded?
    assert_equal projects(:active_record, :action_controller).map(&:id).sort, developer.project_ids.sort
    assert_not_predicate developer.projects, :loaded?
  end

  def test_assign_ids
    developer = Developer.new("name" => "Joe")
    developer.project_ids = projects(:active_record, :action_controller).map(&:id)
    developer.save
    developer.reload
    assert_equal 2, developer.projects.length
    assert_equal [projects(:active_record), projects(:action_controller)].map(&:id).sort, developer.project_ids.sort
  end

  def test_assign_ids_ignoring_blanks
    developer = Developer.new("name" => "Joe")
    developer.project_ids = [projects(:active_record).id, nil, projects(:action_controller).id, ""]
    developer.save
    developer.reload
    assert_equal 2, developer.projects.length
    assert_equal [projects(:active_record), projects(:action_controller)].map(&:id).sort, developer.project_ids.sort
  end

  def test_scoped_find_on_through_association_doesnt_return_read_only_records
    tag = Post.find(1).tags.find_by_name("General")

    assert_nothing_raised do
      tag.save!
    end
  end

  def test_has_many_through_polymorphic_has_manys_works
    assert_equal [10, 20].to_set, pirates(:redbeard).treasure_estimates.map(&:price).to_set
  end

  def test_symbols_as_keys
    developer = DeveloperWithSymbolsForKeys.new(name: "David")
    project = ProjectWithSymbolsForKeys.new(name: "Rails Testing")
    project.developers << developer
    project.save!

    assert_equal 1, project.developers.size
    assert_equal 1, developer.projects.size
    assert_equal developer, project.developers.first
    assert_equal project, developer.projects.first
  end

  def test_dynamic_find_should_respect_association_include
    # SQL error in sort clause if :include is not included
    # due to Unknown column 'authors.id'
    assert Category.find(1).posts_with_authors_sorted_by_author_id.find_by_title("Welcome to the weblog")
  end

  def test_count
    david = Developer.find(1)
    assert_equal 2, david.projects.count
  end

  def test_association_proxy_transaction_method_starts_transaction_in_association_class
    assert_called(Post, :transaction) do
      Category.first.posts.transaction do
        # nothing
      end
    end
  end

  def test_caching_of_columns
    david = Developer.find(1)
    # clear cache possibly created by other tests
    david.projects.reset_column_information

    assert_queries(:any) { david.projects.columns }
    assert_no_queries { david.projects.columns }

    ## and again to verify that reset_column_information clears the cache correctly
    david.projects.reset_column_information

    assert_queries(:any) { david.projects.columns }
    assert_no_queries { david.projects.columns }
  end

  def test_attributes_are_being_set_when_initialized_from_habtm_association_with_where_clause
    new_developer = projects(:action_controller).developers.where(name: "Marcelo").build
    assert_equal new_developer.name, "Marcelo"
  end

  def test_attributes_are_being_set_when_initialized_from_habtm_association_with_multiple_where_clauses
    new_developer = projects(:action_controller).developers.where(name: "Marcelo").where(salary: 90_000).build
    assert_equal new_developer.name, "Marcelo"
    assert_equal new_developer.salary, 90_000
  end

  def test_include_method_in_has_and_belongs_to_many_association_should_return_true_for_instance_added_with_build
    project = Project.new
    developer = project.developers.build
    assert_includes project.developers, developer
  end

  def test_destruction_does_not_error_without_primary_key
    redbeard = pirates(:redbeard)
    george = parrots(:george)
    redbeard.parrots << george
    assert_equal 2, george.pirates.count
    Pirate.includes(:parrots).where(parrot: redbeard.parrot).find(redbeard.id).destroy
    assert_equal 1, george.pirates.count
    assert_equal [], Pirate.where(id: redbeard.id)
  end

  def test_has_and_belongs_to_many_associations_on_new_records_use_null_relations
    projects = Developer.new.projects
    assert_no_queries(ignore_none: false) do
      assert_equal [], projects
      assert_equal [], projects.where(title: "omg")
      assert_equal [], projects.pluck(:title)
      assert_equal 0, projects.count
    end
  end

  def test_association_with_validate_false_does_not_run_associated_validation_callbacks_on_create
    rich_person = RichPerson.new

    treasure = Treasure.new
    treasure.rich_people << rich_person
    treasure.valid?

    assert_equal 1, treasure.rich_people.size
    assert_nil rich_person.first_name, "should not run associated person validation on create when validate: false"
  end

  def test_association_with_validate_false_does_not_run_associated_validation_callbacks_on_update
    rich_person = RichPerson.create!
    person_first_name = rich_person.first_name
    assert_not_nil person_first_name

    treasure = Treasure.new
    treasure.rich_people << rich_person
    treasure.valid?

    assert_equal 1, treasure.rich_people.size
    assert_equal person_first_name, rich_person.first_name, "should not run associated person validation on update when validate: false"
  end

  def test_custom_join_table
    assert_equal "edges", Vertex.reflect_on_association(:sources).join_table
  end

  def test_has_and_belongs_to_many_in_a_namespaced_model_pointing_to_a_namespaced_model
    magazine = Publisher::Magazine.create
    article = Publisher::Article.create
    magazine.articles << article
    magazine.save

    assert_includes magazine.articles, article
  end

  def test_has_and_belongs_to_many_in_a_namespaced_model_pointing_to_a_non_namespaced_model
    article = Publisher::Article.create
    tag = Tag.create
    article.tags << tag
    article.save

    assert_includes article.tags, tag
  end

  def test_redefine_habtm
    child = SubDeveloper.new("name" => "Aredridel")
    child.special_projects << SpecialProject.new("name" => "Special Project")
    assert child.save, "child object should be saved"
  end

  def test_habtm_with_reflection_using_class_name_and_fixtures
    assert_not_nil Developer._reflections["shared_computers"]
    # Checking the fixture for named association is important here, because it's the only way
    # we've been able to reproduce this bug
    assert_not_nil File.read(File.expand_path("../../fixtures/developers.yml", __dir__)).index("shared_computers")
    assert_equal developers(:david).shared_computers.first, computers(:laptop)
  end

  def test_with_symbol_class_name
    assert_nothing_raised do
      developer = DeveloperWithSymbolClassName.new
      developer.projects
    end
  end

  def test_alternate_database
    professor = Professor.create(name: "Plum")
    course = Course.create(name: "Forensics")
    assert_equal 0, professor.courses.count
    assert_nothing_raised do
      professor.courses << course
    end
    assert_equal 1, professor.courses.count
  end

  def test_habtm_scope_can_unscope
    project = ProjectUnscopingDavidDefaultScope.new
    project.save!

    developer = LazyBlockDeveloperCalledDavid.new(name: "Not David")
    developer.save!
    project.developers << developer

    projects = ProjectUnscopingDavidDefaultScope.includes(:developers).where(id: project.id)
    assert_equal 1, projects.first.developers.size
  end

  def test_preloaded_associations_size
    assert_equal Project.first.salaried_developers.size,
      Project.preload(:salaried_developers).first.salaried_developers.size

    assert_equal Project.includes(:salaried_developers).references(:salaried_developers).first.salaried_developers.size,
      Project.preload(:salaried_developers).first.salaried_developers.size

    # Nested HATBM
    first_project = Developer.first.projects.first
    preloaded_first_project =
      Developer.preload(projects: :salaried_developers).
        first.
        projects.
        detect { |p| p.id == first_project.id }

    assert preloaded_first_project.salaried_developers.loaded?, true
    assert_equal first_project.salaried_developers.size, preloaded_first_project.salaried_developers.size
  end

  def test_has_and_belongs_to_many_is_useable_with_belongs_to_required_by_default
    assert_difference "Project.first.developers_required_by_default.size", 1 do
      Project.first.developers_required_by_default.create!(name: "Sean", salary: 50000)
    end
  end

  def test_association_name_is_the_same_as_join_table_name
    user = User.create!
    assert_nothing_raised { user.jobs_pool.clear }
  end

  def test_has_and_belongs_to_many_while_partial_writes_false
    begin
      original_partial_writes = ActiveRecord::Base.partial_writes
      ActiveRecord::Base.partial_writes = false
      developer = Developer.new(name: "Mehmet Emin İNAÇ")
      developer.projects << Project.new(name: "Bounty")

      assert developer.save
    ensure
      ActiveRecord::Base.partial_writes = original_partial_writes
    end
  end

  def test_has_and_belongs_to_many_with_belongs_to
    sink = Sink.create! kitchen: Kitchen.new, sources: [Source.new]
    assert_equal 1, sink.sources.count
  end
end
