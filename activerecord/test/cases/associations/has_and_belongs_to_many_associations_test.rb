require "cases/helper"
require 'models/developer'
require 'models/project'
require 'models/company'
require 'models/customer'
require 'models/order'
require 'models/categorization'
require 'models/category'
require 'models/post'
require 'models/author'
require 'models/tag'
require 'models/tagging'
require 'models/parrot'
require 'models/pirate'
require 'models/treasure'
require 'models/price_estimate'
require 'models/club'
require 'models/member'
require 'models/membership'
require 'models/sponsor'
require 'models/country'
require 'models/treaty'
require 'active_support/core_ext/string/conversions'

class ProjectWithAfterCreateHook < ActiveRecord::Base
  self.table_name = 'projects'
  has_and_belongs_to_many :developers,
    :class_name => "DeveloperForProjectWithAfterCreateHook",
    :join_table => "developers_projects",
    :foreign_key => "project_id",
    :association_foreign_key => "developer_id"

  after_create :add_david

  def add_david
    david = DeveloperForProjectWithAfterCreateHook.find_by_name('David')
    david.projects << self
  end
end

class DeveloperForProjectWithAfterCreateHook < ActiveRecord::Base
  self.table_name = 'developers'
  has_and_belongs_to_many :projects,
    :class_name => "ProjectWithAfterCreateHook",
    :join_table => "developers_projects",
    :association_foreign_key => "project_id",
    :foreign_key => "developer_id"
end

class ProjectWithSymbolsForKeys < ActiveRecord::Base
  self.table_name = 'projects'
  has_and_belongs_to_many :developers,
    :class_name => "DeveloperWithSymbolsForKeys",
    :join_table => :developers_projects,
    :foreign_key => :project_id,
    :association_foreign_key => "developer_id"
end

class DeveloperWithSymbolsForKeys < ActiveRecord::Base
  self.table_name = 'developers'
  has_and_belongs_to_many :projects,
    :class_name => "ProjectWithSymbolsForKeys",
    :join_table => :developers_projects,
    :association_foreign_key => :project_id,
    :foreign_key => "developer_id"
end

class DeveloperWithCounterSQL < ActiveRecord::Base
  self.table_name = 'developers'
  has_and_belongs_to_many :projects,
    :class_name => "DeveloperWithCounterSQL",
    :join_table => "developers_projects",
    :association_foreign_key => "project_id",
    :foreign_key => "developer_id",
    :counter_sql => proc { "SELECT COUNT(*) AS count_all FROM projects INNER JOIN developers_projects ON projects.id = developers_projects.project_id WHERE developers_projects.developer_id =#{id}" }
end

class HasAndBelongsToManyAssociationsTest < ActiveRecord::TestCase
  fixtures :accounts, :companies, :categories, :posts, :categories_posts, :developers, :projects, :developers_projects,
           :parrots, :pirates, :parrots_pirates, :treasures, :price_estimates, :tags, :taggings

  def setup_data_for_habtm_case
    ActiveRecord::Base.connection.execute('delete from countries_treaties')

    country = Country.new(:name => 'India')
    country.country_id = 'c1'
    country.save!

    treaty = Treaty.new(:name => 'peace')
    treaty.treaty_id = 't1'
    country.treaties << treaty
  end

  def test_should_property_quote_string_primary_keys
    setup_data_for_habtm_case

    con = ActiveRecord::Base.connection
    sql = 'select * from countries_treaties'
    record = con.select_rows(sql).last
    assert_equal 'c1', record[0]
    assert_equal 't1', record[1]
  end

  def test_proper_usage_of_primary_keys_and_join_table
    setup_data_for_habtm_case

    assert_equal 'country_id', Country.primary_key
    assert_equal 'treaty_id', Treaty.primary_key

    country = Country.first
    assert_equal 1, country.treaties.count
  end

  def test_has_and_belongs_to_many
    david = Developer.find(1)

    assert !david.projects.empty?
    assert_equal 2, david.projects.size

    active_record = Project.find(1)
    assert !active_record.developers.empty?
    assert_equal 3, active_record.developers.size
    assert active_record.developers.include?(david)
  end

  def test_triple_equality
    assert !(Array === Developer.find(1).projects)
    assert Developer.find(1).projects === Array
  end

  def test_adding_single
    jamis = Developer.find(2)
    jamis.projects.reload # causing the collection to load
    action_controller = Project.find(2)
    assert_equal 1, jamis.projects.size
    assert_equal 1, action_controller.developers.size

    jamis.projects << action_controller

    assert_equal 2, jamis.projects.size
    assert_equal 2, jamis.projects(true).size
    assert_equal 2, action_controller.developers(true).size
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

    assert_equal 2, jamis.projects(true).size
    assert_equal 2, action_controller.developers.size
    assert_equal 2, action_controller.developers(true).size
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
    assert_equal 2, jamis.projects(true).size
    assert_equal 2, action_controller.developers.size
    assert_equal 2, action_controller.developers(true).size
  end

  def test_adding_multiple
    aredridel = Developer.new("name" => "Aredridel")
    aredridel.save
    aredridel.projects.reload
    aredridel.projects.push(Project.find(1), Project.find(2))
    assert_equal 2, aredridel.projects.size
    assert_equal 2, aredridel.projects(true).size
  end

  def test_adding_a_collection
    aredridel = Developer.new("name" => "Aredridel")
    aredridel.save
    aredridel.projects.reload
    aredridel.projects.concat([Project.find(1), Project.find(2)])
    assert_equal 2, aredridel.projects.size
    assert_equal 2, aredridel.projects(true).size
  end

  def test_habtm_adding_before_save
    no_of_devels = Developer.count
    no_of_projects = Project.count
    aredridel = Developer.new("name" => "Aredridel")
    aredridel.projects.concat([Project.find(1), p = Project.new("name" => "Projekt")])
    assert !aredridel.persisted?
    assert !p.persisted?
    assert aredridel.save
    assert aredridel.persisted?
    assert_equal no_of_devels+1, Developer.count
    assert_equal no_of_projects+1, Project.count
    assert_equal 2, aredridel.projects.size
    assert_equal 2, aredridel.projects(true).size
  end

  def test_habtm_saving_multiple_relationships
    new_project = Project.new("name" => "Grimetime")
    amount_of_developers = 4
    developers = (0...amount_of_developers).collect {|i| Developer.create(:name => "JME #{i}") }.reverse

    new_project.developer_ids = [developers[0].id, developers[1].id]
    new_project.developers_with_callback_ids = [developers[2].id, developers[3].id]
    assert new_project.save

    new_project.reload
    assert_equal amount_of_developers, new_project.developers.size
    assert_equal developers, new_project.developers
  end

  def test_habtm_unique_order_preserved
    assert_equal developers(:poor_jamis, :jamis, :david), projects(:active_record).non_unique_developers
    assert_equal developers(:poor_jamis, :jamis, :david), projects(:active_record).developers
  end

  def test_build
    devel = Developer.find(1)
    proj = assert_no_queries { devel.projects.build("name" => "Projekt") }
    assert !devel.projects.loaded?

    assert_equal devel.projects.last, proj
    assert devel.projects.loaded?

    assert !proj.persisted?
    devel.save
    assert proj.persisted?
    assert_equal devel.projects.last, proj
    assert_equal Developer.find(1).projects.sort_by(&:id).last, proj  # prove join table is updated
  end

  def test_new_aliased_to_build
    devel = Developer.find(1)
    proj = assert_no_queries { devel.projects.new("name" => "Projekt") }
    assert !devel.projects.loaded?

    assert_equal devel.projects.last, proj
    assert devel.projects.loaded?

    assert !proj.persisted?
    devel.save
    assert proj.persisted?
    assert_equal devel.projects.last, proj
    assert_equal Developer.find(1).projects.sort_by(&:id).last, proj  # prove join table is updated
  end

  def test_build_by_new_record
    devel = Developer.new(:name => "Marcel", :salary => 75000)
    devel.projects.build(:name => "Make bed")
    proj2 = devel.projects.build(:name => "Lie in it")
    assert_equal devel.projects.last, proj2
    assert !proj2.persisted?
    devel.save
    assert devel.persisted?
    assert proj2.persisted?
    assert_equal devel.projects.last, proj2
    assert_equal Developer.find_by_name("Marcel").projects.last, proj2  # prove join table is updated
  end

  def test_create
    devel = Developer.find(1)
    proj = devel.projects.create("name" => "Projekt")
    assert !devel.projects.loaded?

    assert_equal devel.projects.last, proj
    assert !devel.projects.loaded?

    assert proj.persisted?
    assert_equal Developer.find(1).projects.sort_by(&:id).last, proj  # prove join table is updated
  end

  def test_create_by_new_record
    devel = Developer.new(:name => "Marcel", :salary => 75000)
    devel.projects.build(:name => "Make bed")
    proj2 = devel.projects.build(:name => "Lie in it")
    assert_equal devel.projects.last, proj2
    assert !proj2.persisted?
    devel.save
    assert devel.persisted?
    assert proj2.persisted?
    assert_equal devel.projects.last, proj2
    assert_equal Developer.find_by_name("Marcel").projects.last, proj2  # prove join table is updated
  end

  def test_creation_respects_hash_condition
    # in Oracle '' is saved as null therefore need to save ' ' in not null column
    post = categories(:general).post_with_conditions.build(:body => ' ')

    assert        post.save
    assert_equal  'Yet Another Testing Title', post.title

    # in Oracle '' is saved as null therefore need to save ' ' in not null column
    another_post = categories(:general).post_with_conditions.create(:body => ' ')

    assert        another_post.persisted?
    assert_equal  'Yet Another Testing Title', another_post.title
  end

  def test_uniq_after_the_fact
    dev = developers(:jamis)
    dev.projects << projects(:active_record)
    dev.projects << projects(:active_record)

    assert_equal 3, dev.projects.size
    assert_equal 1, dev.projects.uniq.size
  end

  def test_uniq_before_the_fact
    projects(:active_record).developers << developers(:jamis)
    projects(:active_record).developers << developers(:david)
    assert_equal 3, projects(:active_record, :reload).developers.size
  end

  def test_uniq_option_prevents_duplicate_push
    project = projects(:active_record)
    project.developers << developers(:jamis)
    project.developers << developers(:david)
    assert_equal 3, project.developers.size

    project.developers << developers(:david)
    project.developers << developers(:jamis)
    assert_equal 3, project.developers.size
  end

  def test_deleting
    david = Developer.find(1)
    active_record = Project.find(1)
    david.projects.reload
    assert_equal 2, david.projects.size
    assert_equal 3, active_record.developers.size

    david.projects.delete(active_record)

    assert_equal 1, david.projects.size
    assert_equal 1, david.projects(true).size
    assert_equal 2, active_record.developers(true).size
  end

  def test_deleting_array
    david = Developer.find(1)
    david.projects.reload
    david.projects.delete(Project.find(:all))
    assert_equal 0, david.projects.size
    assert_equal 0, david.projects(true).size
  end

  def test_deleting_with_sql
    david = Developer.find(1)
    active_record = Project.find(1)
    active_record.developers.reload
    assert_equal 3, active_record.developers_by_sql.size

    active_record.developers_by_sql.delete(david)
    assert_equal 2, active_record.developers_by_sql(true).size
  end

  def test_deleting_array_with_sql
    active_record = Project.find(1)
    active_record.developers.reload
    assert_equal 3, active_record.developers_by_sql.size

    active_record.developers_by_sql.delete(Developer.find(:all))
    assert_equal 0, active_record.developers_by_sql(true).size
  end

  def test_deleting_all_with_sql
    project = Project.find(1)
    project.developers_by_sql.delete_all
    assert_equal 0, project.developers_by_sql.size
  end

  def test_deleting_all
    david = Developer.find(1)
    david.projects.reload
    david.projects.clear
    assert_equal 0, david.projects.size
    assert_equal 0, david.projects(true).size
  end

  def test_removing_associations_on_destroy
    david = DeveloperWithBeforeDestroyRaise.find(1)
    assert !david.projects.empty?
    david.destroy
    assert david.projects.empty?
    assert DeveloperWithBeforeDestroyRaise.connection.select_all("SELECT * FROM developers_projects WHERE developer_id = 1").empty?
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
    assert join_records.empty?

    assert_equal 1, david.reload.projects.size
    assert_equal 1, david.projects(true).size
  end

  def test_destroying_many
    david = Developer.find(1)
    david.projects.reload
    projects = Project.all

    assert_no_difference "Project.count" do
      david.projects.destroy(*projects)
    end

    join_records = Developer.connection.select_all("SELECT * FROM developers_projects WHERE developer_id = #{david.id}")
    assert join_records.empty?

    assert_equal 0, david.reload.projects.size
    assert_equal 0, david.projects(true).size
  end

  def test_destroy_all
    david = Developer.find(1)
    david.projects.reload
    assert !david.projects.empty?

    assert_no_difference "Project.count" do
      david.projects.destroy_all
    end

    join_records = Developer.connection.select_all("SELECT * FROM developers_projects WHERE developer_id = #{david.id}")
    assert join_records.empty?

    assert david.projects.empty?
    assert david.projects(true).empty?
  end

  def test_destroy_associations_destroys_multiple_associations
    george = parrots(:george)
    assert !george.pirates.empty?
    assert !george.treasures.empty?

    assert_no_difference "Pirate.count" do
      assert_no_difference "Treasure.count" do
        george.destroy_associations
      end
    end

    join_records = Parrot.connection.select_all("SELECT * FROM parrots_pirates WHERE parrot_id = #{george.id}")
    assert join_records.empty?
    assert george.pirates(true).empty?

    join_records = Parrot.connection.select_all("SELECT * FROM parrots_treasures WHERE parrot_id = #{george.id}")
    assert join_records.empty?
    assert george.treasures(true).empty?
  end

  def test_deprecated_push_with_attributes_was_removed
    jamis = developers(:jamis)
    assert_raise(NoMethodError) do
      jamis.projects.push_with_attributes(projects(:action_controller), :joined_on => Date.today)
    end
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
    project.developers.class # force load target

    developer = project.developers.first

    assert_no_queries do
      assert project.developers.loaded?
      assert project.developers.include?(developer)
    end
  end

  def test_include_checks_if_record_exists_if_target_not_loaded
    project = projects(:active_record)
    developer = project.developers.first

    project.reload
    assert ! project.developers.loaded?
    assert_queries(1) do
      assert project.developers.include?(developer)
    end
    assert ! project.developers.loaded?
  end

  def test_include_returns_false_for_non_matching_record_to_verify_scoping
    project = projects(:active_record)
    developer = Developer.create :name => "Bryan", :salary => 50_000

    assert ! project.developers.loaded?
    assert ! project.developers.include?(developer)
  end

  def test_find_in_association_with_custom_finder_sql
    assert_equal developers(:david), projects(:active_record).developers_with_finder_sql.find(developers(:david).id), "SQL find"

    active_record = projects(:active_record)
    active_record.developers_with_finder_sql.reload
    assert_equal developers(:david), active_record.developers_with_finder_sql.find(developers(:david).id), "Ruby find"
  end

  def test_find_in_association_with_custom_finder_sql_and_multiple_interpolations
    # interpolate once:
    assert_equal [developers(:david), developers(:jamis), developers(:poor_jamis)], projects(:active_record).developers_with_finder_sql, "first interpolation"
    # interpolate again, for a different project id
    assert_equal [developers(:david)], projects(:action_controller).developers_with_finder_sql, "second interpolation"
  end

  def test_find_in_association_with_custom_finder_sql_and_string_id
    assert_equal developers(:david), projects(:active_record).developers_with_finder_sql.find(developers(:david).id.to_s), "SQL find"
  end

  def test_find_with_merged_options
    assert_equal 1, projects(:active_record).limited_developers.size
    assert_equal 1, projects(:active_record).limited_developers.find(:all).size
    assert_equal 3, projects(:active_record).limited_developers.find(:all, :limit => nil).size
  end

  def test_dynamic_find_should_respect_association_order
    # Developers are ordered 'name DESC, id DESC'
    high_id_jamis = projects(:active_record).developers.create(:name => 'Jamis')

    assert_equal high_id_jamis, projects(:active_record).developers.find(:first, :conditions => "name = 'Jamis'")
    assert_equal high_id_jamis, projects(:active_record).developers.find_by_name('Jamis')
  end

  def test_dynamic_find_all_should_respect_association_order
    # Developers are ordered 'name DESC, id DESC'
    low_id_jamis = developers(:jamis)
    middle_id_jamis = developers(:poor_jamis)
    high_id_jamis = projects(:active_record).developers.create(:name => 'Jamis')

    assert_equal [high_id_jamis, middle_id_jamis, low_id_jamis], projects(:active_record).developers.find(:all, :conditions => "name = 'Jamis'")
    assert_equal [high_id_jamis, middle_id_jamis, low_id_jamis], projects(:active_record).developers.find_all_by_name('Jamis')
  end

  def test_find_should_append_to_association_order
    ordered_developers = projects(:active_record).developers.order('projects.id')
    assert_equal ['developers.name desc, developers.id desc', 'projects.id'], ordered_developers.order_values
  end

  def test_dynamic_find_all_should_respect_association_limit
    assert_equal 1, projects(:active_record).limited_developers.find(:all, :conditions => "name = 'Jamis'").length
    assert_equal 1, projects(:active_record).limited_developers.find_all_by_name('Jamis').length
  end

  def test_dynamic_find_all_order_should_override_association_limit
    assert_equal 2, projects(:active_record).limited_developers.find(:all, :conditions => "name = 'Jamis'", :limit => 9_000).length
    assert_equal 2, projects(:active_record).limited_developers.find_all_by_name('Jamis', :limit => 9_000).length
  end

  def test_dynamic_find_all_should_respect_readonly_access
    projects(:active_record).readonly_developers.each { |d| assert_raise(ActiveRecord::ReadOnlyRecord) { d.save!  } if d.valid?}
    projects(:active_record).readonly_developers.each { |d| d.readonly? }
  end

  def test_new_with_values_in_collection
    jamis = DeveloperForProjectWithAfterCreateHook.find_by_name('Jamis')
    david = DeveloperForProjectWithAfterCreateHook.find_by_name('David')
    project = ProjectWithAfterCreateHook.new(:name => "Cooking with Bertie")
    project.developers << jamis
    project.save!
    project.reload

    assert project.developers.include?(jamis)
    assert project.developers.include?(david)
  end

  def test_find_in_association_with_options
    developers = projects(:active_record).developers.all
    assert_equal 3, developers.size

    assert_equal developers(:poor_jamis), projects(:active_record).developers.where("salary < 10000").first
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
    assert !david.projects.include?(projects(:active_record))
  end

  def test_replace_on_new_object
    new_developer = Developer.new("name" => "Matz")
    new_developer.projects = [projects(:action_controller), Project.new("name" => "ActionWebSearch")]
    new_developer.save
    assert_equal 2, new_developer.projects.length
  end

  def test_consider_type
    developer = Developer.find(:first)
    special_project = SpecialProject.create("name" => "Special Project")

    other_project = developer.projects.first
    developer.special_projects << special_project
    developer.reload

    assert developer.projects.include?(special_project)
    assert developer.special_projects.include?(special_project)
    assert !developer.special_projects.include?(other_project)
  end

  def test_update_attributes_after_push_without_duplicate_join_table_rows
    developer = Developer.new("name" => "Kano")
    project = SpecialProject.create("name" => "Special Project")
    assert developer.save
    developer.projects << project
    developer.update_column("name", "Bruza")
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
    categories(:technology).select_testing_posts(true).each do |o|
      assert_respond_to o, :correctness_marker
    end
    assert_respond_to categories(:technology).select_testing_posts.find(:first), :correctness_marker
  end

  def test_habtm_selects_all_columns_by_default
    assert_equal Project.column_names.sort, developers(:david).projects.first.attributes.keys.sort
  end

  def test_habtm_respects_select_query_method
    assert_equal ['id'], developers(:david).projects.select(:id).first.attributes.keys
  end

  def test_join_table_alias
    assert_equal 3, Developer.find(:all, :include => {:projects => :developers}, :conditions => 'developers_projects_join.joined_on IS NOT NULL').size
  end

  def test_join_with_group
    group = Developer.columns.inject([]) do |g, c|
      g << "developers.#{c.name}"
      g << "developers_projects_2.#{c.name}"
    end
    Project.columns.each { |c| group << "projects.#{c.name}" }

    assert_equal 3, Developer.find(:all, :include => {:projects => :developers}, :conditions => 'developers_projects_join.joined_on IS NOT NULL', :group => group.join(",")).size
  end

  def test_find_grouped
    all_posts_from_category1 = Post.find(:all, :conditions => "category_id = 1", :joins => :categories)
    grouped_posts_of_category1 = Post.find(:all, :conditions => "category_id = 1", :group => "author_id", :select => 'count(posts.id) as posts_count', :joins => :categories)
    assert_equal 5, all_posts_from_category1.size
    assert_equal 2, grouped_posts_of_category1.size
  end

  def test_find_scoped_grouped
    assert_equal 5, categories(:general).posts_grouped_by_title.size
    assert_equal 1, categories(:technology).posts_grouped_by_title.size
  end

  def test_find_scoped_grouped_having
    assert_equal 2, projects(:active_record).well_payed_salary_groups.size
    assert projects(:active_record).well_payed_salary_groups.all? { |g| g.salary > 10000 }
  end

  def test_get_ids
    assert_equal projects(:active_record, :action_controller).map(&:id).sort, developers(:david).project_ids.sort
    assert_equal [projects(:active_record).id], developers(:jamis).project_ids
  end

  def test_get_ids_for_loaded_associations
    developer = developers(:david)
    developer.projects(true)
    assert_queries(0) do
      developer.project_ids
      developer.project_ids
    end
  end

  def test_get_ids_for_unloaded_associations_does_not_load_them
    developer = developers(:david)
    assert !developer.projects.loaded?
    assert_equal projects(:active_record, :action_controller).map(&:id).sort, developer.project_ids.sort
    assert !developer.projects.loaded?
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
    developer.project_ids = [projects(:active_record).id, nil, projects(:action_controller).id, '']
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
    developer = DeveloperWithSymbolsForKeys.new(:name => 'David')
    project = ProjectWithSymbolsForKeys.new(:name => 'Rails Testing')
    project.developers << developer
    project.save!

    assert_equal 1, project.developers.size
    assert_equal 1, developer.projects.size
    assert_equal developer, project.developers.find(:first)
    assert_equal project, developer.projects.find(:first)
  end

  def test_self_referential_habtm_without_foreign_key_set_should_raise_exception
    assert_raise(ActiveRecord::HasAndBelongsToManyAssociationForeignKeyNeeded) {
      Member.class_eval do
        has_and_belongs_to_many :friends, :class_name => "Member", :join_table => "member_friends"
      end
    }
  end

  def test_dynamic_find_should_respect_association_include
    # SQL error in sort clause if :include is not included
    # due to Unknown column 'authors.id'
    assert Category.find(1).posts_with_authors_sorted_by_author_id.find_by_title('Welcome to the weblog')
  end

  def test_counting_on_habtm_association_and_not_array
    david = Developer.find(1)
    # Extra parameter just to make sure we aren't falling back to
    # Array#count in Ruby >=1.8.7, which would raise an ArgumentError
    assert_nothing_raised { david.projects.count(:all, :conditions => '1=1') }
  end

  def test_count
    david = Developer.find(1)
    assert_equal 2, david.projects.count
  end

  def test_count_with_counter_sql
    developer  = DeveloperWithCounterSQL.create(:name => 'tekin')
    developer.project_ids = [projects(:active_record).id]
    developer.save
    developer.reload
    assert_equal 1, developer.projects.count
  end

  def test_counting_should_not_fire_sql_if_parent_is_unsaved
    assert_no_queries do
      assert_equal 0, Developer.new.projects.count
    end
  end

  unless current_adapter?(:PostgreSQLAdapter)
    def test_count_with_finder_sql
      assert_equal 3, projects(:active_record).developers_with_finder_sql.count
      assert_equal 3, projects(:active_record).developers_with_multiline_finder_sql.count
    end
  end

  def test_association_proxy_transaction_method_starts_transaction_in_association_class
    Post.expects(:transaction)
    Category.find(:first).posts.transaction do
      # nothing
    end
  end

  def test_caching_of_columns
    david = Developer.find(1)
    # clear cache possibly created by other tests
    david.projects.reset_column_information

    assert_queries(1) { david.projects.columns; david.projects.columns }

    ## and again to verify that reset_column_information clears the cache correctly
    david.projects.reset_column_information
    assert_queries(1) { david.projects.columns; david.projects.columns }
  end

  def test_attributes_are_being_set_when_initialized_from_habm_association_with_where_clause
    new_developer = projects(:action_controller).developers.where(:name => "Marcelo").build
    assert_equal new_developer.name, "Marcelo"
  end

  def test_attributes_are_being_set_when_initialized_from_habm_association_with_multiple_where_clauses
    new_developer = projects(:action_controller).developers.where(:name => "Marcelo").where(:salary => 90_000).build
    assert_equal new_developer.name, "Marcelo"
    assert_equal new_developer.salary, 90_000
  end

  def test_include_method_in_has_and_belongs_to_many_association_should_return_true_for_instance_added_with_build
    project = Project.new
    developer = project.developers.build
    assert project.developers.include?(developer)
  end
end
