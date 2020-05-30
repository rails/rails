# frozen_string_literal: true

require "cases/helper"
require "models/developer"
require "models/computer"
require "models/mentor"
require "models/project"
require "models/ship"

class StrictLoadingTest < ActiveRecord::TestCase
  fixtures :developers
  fixtures :projects
  fixtures :ships

  def test_strict_loading!
    developer = Developer.first
    assert_not_predicate developer, :strict_loading?

    developer.strict_loading!
    assert_predicate developer, :strict_loading?

    assert_raises ActiveRecord::StrictLoadingViolationError do
      developer.audit_logs.to_a
    end
  end

  def test_strict_loading
    Developer.all.each { |d| assert_not d.strict_loading? }
    Developer.strict_loading.each { |d| assert d.strict_loading? }
  end

  def test_raises_if_strict_loading_and_lazy_loading
    dev = Developer.strict_loading.first
    assert_predicate dev, :strict_loading?

    assert_raises ActiveRecord::StrictLoadingViolationError do
      dev.audit_logs.to_a
    end
  end

  def test_preload_audit_logs_are_strict_loading_because_parent_is_strict_loading
    developer = Developer.first

    3.times do
      AuditLog.create(developer: developer, message: "I am message")
    end

    dev = Developer.includes(:audit_logs).strict_loading.first

    assert_predicate dev, :strict_loading?
    assert dev.audit_logs.all?(&:strict_loading?), "Expected all audit logs to be strict_loading"
  end

  def test_eager_load_audit_logs_are_strict_loading_because_parent_is_strict_loading_in_hm_relation
    developer = Developer.first

    3.times do
      AuditLog.create(developer: developer, message: "I am message")
    end

    dev = Developer.eager_load(:strict_loading_audit_logs).first

    assert dev.strict_loading_audit_logs.all?(&:strict_loading?), "Expected all audit logs to be strict_loading"
  end

  def test_eager_load_audit_logs_are_strict_loading_because_parent_is_strict_loading
    developer = Developer.first

    3.times do
      AuditLog.create(developer: developer, message: "I am message")
    end

    dev = Developer.eager_load(:audit_logs).strict_loading.first

    assert_predicate dev, :strict_loading?
    assert dev.audit_logs.all?(&:strict_loading?), "Expected all audit logs to be strict_loading"
  end

  def test_raises_on_unloaded_relation_methods_if_strict_loading
    dev = Developer.strict_loading.first
    assert_predicate dev, :strict_loading?

    assert_raises ActiveRecord::StrictLoadingViolationError do
      dev.audit_logs.first
    end
  end

  def test_raises_on_lazy_loading_a_strict_loading_belongs_to_relation
    mentor = Mentor.create!(name: "Mentor")

    developer = Developer.first
    developer.update_column(:mentor_id, mentor.id)

    assert_raises ActiveRecord::StrictLoadingViolationError do
      developer.strict_loading_mentor
    end
  end

  def test_does_not_raise_on_eager_loading_a_strict_loading_belongs_to_relation
    mentor = Mentor.create!(name: "Mentor")

    Developer.first.update_column(:mentor_id, mentor.id)
    developer = Developer.includes(:strict_loading_mentor).first

    assert_nothing_raised { developer.strict_loading_mentor }
  end

  def test_raises_on_lazy_loading_a_strict_loading_has_one_relation
    developer = Developer.first
    ship = Ship.first

    ship.update_column(:developer_id, developer.id)

    assert_raises ActiveRecord::StrictLoadingViolationError do
      developer.strict_loading_ship
    end
  end

  def test_does_not_raise_on_eager_loading_a_strict_loading_has_one_relation
    Ship.first.update_column(:developer_id, Developer.first.id)
    developer = Developer.includes(:strict_loading_ship).first

    assert_nothing_raised { developer.strict_loading_ship }
  end

  def test_raises_on_lazy_loading_a_strict_loading_has_many_relation
    developer = Developer.first

    AuditLog.create(
      3.times.map do
        { developer_id: developer.id, message: "I am message" }
      end
    )

    assert_raises ActiveRecord::StrictLoadingViolationError do
      developer.strict_loading_opt_audit_logs.first
    end
  end

  def test_does_not_raise_on_eager_loading_a_strict_loading_has_many_relation
    developer = Developer.first

    AuditLog.create(
      3.times.map do
        { developer_id: developer.id, message: "I am message" }
      end
    )

    developer = Developer.includes(:strict_loading_opt_audit_logs).first

    assert_nothing_raised { developer.strict_loading_opt_audit_logs.first }
  end

  def test_raises_on_lazy_loading_a_strict_loading_habtm_relation
    developer = Developer.first
    developer.projects << Project.first

    assert_not developer.strict_loading_projects.loaded?

    assert_raises ActiveRecord::StrictLoadingViolationError do
      developer.strict_loading_projects.first
    end
  end

  def test_does_not_raise_on_eager_loading_a_strict_loading_habtm_relation
    Developer.first.projects << Project.first
    developer = Developer.includes(:strict_loading_projects).first

    assert_nothing_raised { developer.strict_loading_projects.first }
  end
end
