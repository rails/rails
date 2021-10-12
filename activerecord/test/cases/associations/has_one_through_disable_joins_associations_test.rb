# frozen_string_literal: true

require "cases/helper"
require "models/member"
require "models/member_detail"
require "models/organization"
require "models/project"
require "models/developer"
require "models/company"
require "models/computer"
require "models/club"
require "models/membership"

class HasOneThroughDisableJoinsAssociationsTest < ActiveRecord::TestCase
  fixtures :members, :organizations, :projects, :developers, :companies, :clubs, :memberships

  def setup
    @member = members(:groucho)
    @organization = organizations(:discordians)
    @member.organization = @organization
    @member.save!
    @member.reload
  end

  def test_counting_on_disable_joins_through
    no_joins = capture_sql { @member.organization_without_joins }
    joins = capture_sql { @member.organization }

    assert_equal @member.organization, @member.organization_without_joins
    assert_equal 2, no_joins.count
    assert_equal 1, joins.count
    assert_match(/INNER JOIN/, joins.first)
    no_joins.each do |nj|
      assert_no_match(/INNER JOIN/, nj)
    end
  end

  def test_nil_on_disable_joins_through
    member = members(:blarpy_winkup)
    assert_nil assert_queries(1) { member.organization }
    assert_nil assert_queries(1) { member.organization_without_joins }
  end

  def test_preload_on_disable_joins_through
    members = Member.preload(:organization, :organization_without_joins).to_a
    assert_no_queries { members[0].organization }
    assert_no_queries { members[0].organization_without_joins }
  end

  def test_has_one_through_with_belongs_to_on_disable_joins
    firm = Firm.create!(name: "Adequate Holdings")
    project = Project.create!(name: "Project 1", firm: firm)
    Developer.create!(name: "Gorbypuff", firm: firm)

    joins = capture_sql { project.lead_developer }
    no_joins = capture_sql { project.lead_developer_disable_joins }

    assert_equal project.lead_developer, project.lead_developer_disable_joins
    assert_equal 2, no_joins.count
    assert_equal 1, joins.count
    assert_match(/INNER JOIN/, joins.first)
    no_joins.each do |nj|
      assert_no_match(/INNER JOIN/, nj)
    end
  end

  def test_disable_joins_through_with_enum_type
    joins = capture_sql { @member.club }
    no_joins = capture_sql { @member.club_without_joins }

    assert_equal 1, joins.size
    assert_equal 2, no_joins.size

    assert_match(/INNER JOIN/, joins.first)
    no_joins.each do |nj|
      assert_no_match(/INNER JOIN/, nj)
    end

    if current_adapter?(:Mysql2Adapter)
      assert_match(/`memberships`.`type`/, no_joins.first)
    else
      assert_match(/"memberships"."type"/, no_joins.first)
    end
  end
end
