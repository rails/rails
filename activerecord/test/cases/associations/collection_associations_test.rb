require "cases/helper"
require 'models/computer'
require 'models/developer'
require 'models/computer'
require 'models/project'
require 'models/company'

class CollectionAssociationTest < ActiveRecord::TestCase
  fixtures :developers, :projects, :developers_projects, :companies, :computers

  def test_size
    projects = Developer.first.projects

    assert_queries(1) { assert_equal 2, projects.size }

    assert ! projects.loaded?
    projects.to_a # force load
    assert_no_queries { assert_equal 2, projects.size }
  end

  def test_size_with_limit
    projects = Developer.first.projects.limit(1)

    assert_queries(1) { assert_equal 1, projects.size }

    assert ! projects.loaded?
    projects.to_a # force load
    assert_no_queries { assert_equal 1, projects.size }
  end

  def test_size_with_zero_limit
    projects = Developer.first.projects.limit(0)

    assert_no_queries { assert_equal 0, projects.size }

    assert ! projects.loaded?
    projects.to_a # force load
    assert_no_queries { assert_equal 0, projects.size }
  end

  def test_empty
    projects = Developer.first.projects

    assert_queries(1) { assert_equal false, projects.empty? }
    assert ! projects.loaded?
    projects.to_a # force load
    assert_no_queries { assert_equal false, projects.empty? }

    no_projects = projects.where(:name => "")
    assert_queries(1) { assert_equal true, no_projects.empty? }
    assert ! no_projects.loaded?
  end

  def test_empty_with_zero_limit
    projects = Developer.first.projects.limit(0)

    assert_no_queries { assert_equal true, projects.empty? }
    assert ! projects.loaded?
  end



  def test_none
    projects = Developer.first.projects

    assert_queries(1) { assert_equal false, projects.none? }
    assert ! projects.loaded?

    assert_queries(1) { assert_equal false, projects.none? { |p| p.id > 0} }
    assert projects.loaded?

    assert_no_queries { assert_equal true, projects.none? { |p| p.id < 0 } }
  end

  def test_any
    projects = Developer.first.projects

    assert_queries(1) { assert_equal true, projects.any? }
    assert ! projects.loaded?

    assert_queries(1) { assert_equal true, projects.any? { |p| p.id > 0 } }
    assert projects.loaded?

    assert_no_queries { assert_equal false, projects.any? { |p| p.id < 0 } }
  end

  def test_one
    projects = Developer.first.projects

    assert_queries(1) { assert_equal false, projects.one? }
    assert ! projects.loaded?

    assert_queries(1) { assert_equal true, projects.one? { |p| p.id == 1 } }
    assert projects.loaded?

    assert_no_queries { assert_equal false, projects.one? { |p| p.id < 0 } }
  end

  def test_many
    projects = Developer.first.projects

    assert_queries(1) { assert_equal true, projects.many? }
    assert ! projects.loaded?

    assert_queries(1) { assert_equal false, projects.many? { |p| p.id == 1 } }
    assert projects.loaded?

    assert_no_queries { assert_equal false, projects.many? { |p| p.id < 0 } }
  end

  def test_many_with_limits
    projects = Developer.first.projects
    
    assert_queries(1) { assert_equal true, projects.many? }
    assert_queries(1) { assert_equal false, projects.limit(1).many? }
  end
end
