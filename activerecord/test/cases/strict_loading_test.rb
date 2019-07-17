# frozen_string_literal: true

require "cases/helper"
require "models/developer"
require "models/computer"

class StrictLoadingTest < ActiveRecord::TestCase
  fixtures :developers

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
end
