require "cases/helper"
require 'models/post'
require 'models/topic'
require 'models/reply'
require 'models/author'
require 'models/entrant'
require 'models/developer'
require 'models/company'

class RelationTest < ActiveRecord::TestCase
  fixtures :authors, :topics, :entrants, :developers, :companies, :developers_projects, :accounts, :categories, :categorizations, :posts

  def test_finding_with_conditions
    assert_equal Author.find(:all, :conditions => "name = 'David'"), Author.all.conditions!("name = 'David'").to_a
  end

  def test_finding_with_order
    topics = Topic.all.order!('id')
    assert_equal 4, topics.size
    assert_equal topics(:first).title, topics.first.title
  end

  def test_finding_with_order_and_take
    entrants = Entrant.all.order!("id ASC").limit!(2).to_a

    assert_equal(2, entrants.size)
    assert_equal(entrants(:first).name, entrants.first.name)
  end

  def test_finding_with_order_limit_and_offset
    entrants = Entrant.all.order!("id ASC").limit!(2).offset!(1)

    assert_equal(2, entrants.size)
    assert_equal(entrants(:second).name, entrants.first.name)

    entrants = Entrant.all.order!("id ASC").limit!(2).offset!(2)
    assert_equal(1, entrants.size)
    assert_equal(entrants(:third).name, entrants.first.name)
  end

  def test_finding_with_group
    developers = Developer.all.group!("salary").select!("salary").to_a
    assert_equal 4, developers.size
    assert_equal 4, developers.map(&:salary).uniq.size
  end

  def test_finding_with_hash_conditions_on_joined_table
    firms = DependentFirm.all.joins!(:account).conditions!({:name => 'RailsCore', :accounts => { :credit_limit => 55..60 }}).to_a
    assert_equal 1, firms.size
    assert_equal companies(:rails_core), firms.first
  end

  def test_find_all_with_join
    developers_on_project_one = Developer.all.joins!('LEFT JOIN developers_projects ON developers.id = developers_projects.developer_id').conditions!('project_id=1').to_a

    assert_equal 3, developers_on_project_one.length
    developer_names = developers_on_project_one.map { |d| d.name }
    assert developer_names.include?('David')
    assert developer_names.include?('Jamis')
  end

  def test_find_on_hash_conditions
    assert_equal Topic.find(:all, :conditions => {:approved => false}), Topic.all.conditions!({ :approved => false }).to_a
  end

  def test_joins_with_string_array
    person_with_reader_and_post = Post.all.joins!([
        "INNER JOIN categorizations ON categorizations.post_id = posts.id",
        "INNER JOIN categories ON categories.id = categorizations.category_id AND categories.type = 'SpecialCategory'"
      ]
    ).to_a
    assert_equal 1, person_with_reader_and_post.size
  end
end

