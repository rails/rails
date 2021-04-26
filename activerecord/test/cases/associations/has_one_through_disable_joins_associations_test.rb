# frozen_string_literal: true

require "cases/helper"
require "models/member"
require "models/organization"

class HasOneThroughDisableJoinsAssociationsTest < ActiveRecord::TestCase
  fixtures :members, :organizations

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
end
