# frozen_string_literal: true

require "cases/helper"
require "models/developer"
require "models/computer"
require "models/mentor"
require "models/project"
require "models/ship"
require "models/strict_zine"
require "models/interest"

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

    developer.strict_loading!(false)
    assert_not_predicate developer, :strict_loading?

    assert_nothing_raised do
      developer.audit_logs.to_a
    end
  end

  def test_strict_loading
    Developer.all.each { |d| assert_not d.strict_loading? }
    Developer.strict_loading.each { |d| assert d.strict_loading? }
  end

  def test_strict_loading_by_default
    with_strict_loading_by_default(Developer) do
      Developer.all.each { |d| assert d.strict_loading? }
    end
  end

  def test_strict_loading_by_default_can_be_set_per_model
    model1 = Class.new(ActiveRecord::Base) do
      self.table_name = "developers"
      self.strict_loading_by_default = true
    end.new

    model2 = Class.new(ActiveRecord::Base) do
      self.table_name = "developers"
      self.strict_loading_by_default = false
    end.new

    assert_predicate model1, :strict_loading?
    assert_not_predicate model2, :strict_loading?
  end

  def test_strict_loading_by_default_is_inheritable
    with_strict_loading_by_default(ActiveRecord::Base) do
      model1 = Class.new(ActiveRecord::Base) do
        self.table_name = "developers"
      end.new

      model2 = Class.new(ActiveRecord::Base) do
        self.table_name = "developers"
        self.strict_loading_by_default = false
      end.new

      assert_predicate model1, :strict_loading?
      assert_not_predicate model2, :strict_loading?
    end
  end

  def test_raises_if_strict_loading_and_lazy_loading
    dev = Developer.strict_loading.first
    assert_predicate dev, :strict_loading?

    assert_raises ActiveRecord::StrictLoadingViolationError do
      dev.audit_logs.to_a
    end
  end

  def test_raises_if_strict_loading_by_default_and_lazy_loading
    with_strict_loading_by_default(Developer) do
      dev = Developer.first
      assert_predicate dev, :strict_loading?

      assert_raises ActiveRecord::StrictLoadingViolationError do
        dev.audit_logs.to_a
      end
    end
  end

  def test_strict_loading_is_ignored_in_validation_context
    with_strict_loading_by_default(Developer) do
      developer = Developer.first
      assert_predicate developer, :strict_loading?

      assert_nothing_raised do
        AuditLogRequired.create! developer_id: developer.id, message: "i am a message"
      end
    end
  end

  def test_strict_loading_with_reflection_is_ignored_in_validation_context
    with_strict_loading_by_default(Developer) do
      developer = Developer.first
      assert_predicate developer, :strict_loading?

      developer.required_audit_logs.build(message: "I am message")
      developer.save!
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

  def test_preload_audit_logs_are_strict_loading_because_it_is_strict_loading_by_default
    with_strict_loading_by_default(AuditLog) do
      developer = Developer.first

      3.times do
        AuditLog.create(developer: developer, message: "I am message")
      end

      dev = Developer.includes(:audit_logs).first

      assert_not_predicate dev, :strict_loading?
      assert dev.audit_logs.all?(&:strict_loading?), "Expected all audit logs to be strict_loading"
    end
  end

  def test_eager_load_audit_logs_are_strict_loading_because_parent_is_strict_loading_in_hm_relation
    developer = Developer.first

    3.times do
      AuditLog.create(developer: developer, message: "I am message")
    end

    dev = Developer.eager_load(:strict_loading_audit_logs).first

    assert dev.strict_loading_audit_logs.all?(&:strict_loading?), "Expected all audit logs to be strict_loading"

    dev = Developer.eager_load(:strict_loading_audit_logs).strict_loading(false).first

    assert dev.audit_logs.none?(&:strict_loading?), "Expected no audit logs to be strict_loading"
  end

  def test_eager_load_audit_logs_are_strict_loading_because_parent_is_strict_loading
    developer = Developer.first

    3.times do
      AuditLog.create(developer: developer, message: "I am message")
    end

    dev = Developer.eager_load(:audit_logs).strict_loading.first

    assert_predicate dev, :strict_loading?
    assert dev.audit_logs.all?(&:strict_loading?), "Expected all audit logs to be strict_loading"

    dev = Developer.eager_load(:audit_logs).strict_loading(false).first

    assert_not_predicate dev, :strict_loading?
    assert dev.audit_logs.none?(&:strict_loading?), "Expected no audit logs to be strict_loading"
  end

  def test_eager_load_audit_logs_are_strict_loading_because_it_is_strict_loading_by_default
    with_strict_loading_by_default(AuditLog) do
      developer = Developer.first

      3.times do
        AuditLog.create(developer: developer, message: "I am message")
      end

      dev = Developer.eager_load(:audit_logs).first

      assert_not_predicate dev, :strict_loading?
      assert_predicate AuditLog.last, :strict_loading?
      assert dev.audit_logs.all?(&:strict_loading?), "Expected all audit logs to be strict_loading"
    end
  end

  def test_raises_on_unloaded_relation_methods_if_strict_loading
    dev = Developer.strict_loading.first
    assert_predicate dev, :strict_loading?

    assert_raises ActiveRecord::StrictLoadingViolationError do
      dev.audit_logs.first
    end
  end

  def test_raises_on_unloaded_relation_methods_if_strict_loading_by_default
    with_strict_loading_by_default(Developer) do
      dev = Developer.first
      assert_predicate dev, :strict_loading?

      assert_raises ActiveRecord::StrictLoadingViolationError do
        dev.audit_logs.first
      end
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

  def test_raises_on_lazy_loading_a_belongs_to_relation_if_strict_loading_by_default
    with_strict_loading_by_default(Developer) do
      mentor = Mentor.create!(name: "Mentor")

      developer = Developer.first
      developer.update_column(:mentor_id, mentor.id)

      assert_raises ActiveRecord::StrictLoadingViolationError do
        developer.mentor
      end
    end
  end

  def test_strict_loading_can_be_turned_off_on_an_association_in_a_model_with_strict_loading_on
    with_strict_loading_by_default(Developer) do
      mentor = Mentor.create!(name: "Mentor")

      developer = Developer.first
      developer.update_column(:mentor_id, mentor.id)

      assert_nothing_raised do
        developer.strict_loading_off_mentor
      end
    end
  end

  def test_does_not_raise_on_eager_loading_a_strict_loading_belongs_to_relation
    mentor = Mentor.create!(name: "Mentor")

    Developer.first.update_column(:mentor_id, mentor.id)
    developer = Developer.includes(:strict_loading_mentor).first

    assert_nothing_raised { developer.strict_loading_mentor }
  end

  def test_does_not_raise_on_eager_loading_a_belongs_to_relation_if_strict_loading_by_default
    with_strict_loading_by_default(Developer) do
      mentor = Mentor.create!(name: "Mentor")

      Developer.first.update_column(:mentor_id, mentor.id)
      developer = Developer.includes(:mentor).first

      assert_nothing_raised { developer.mentor }
    end
  end

  def test_raises_on_lazy_loading_a_strict_loading_has_one_relation
    developer = Developer.first
    ship = Ship.first

    ship.update_column(:developer_id, developer.id)

    assert_raises ActiveRecord::StrictLoadingViolationError do
      developer.strict_loading_ship
    end
  end

  def test_raises_on_lazy_loading_a_has_one_relation_if_strict_loading_by_default
    with_strict_loading_by_default(Developer) do
      developer = Developer.first
      ship = Ship.first

      ship.update_column(:developer_id, developer.id)

      assert_raises ActiveRecord::StrictLoadingViolationError do
        developer.ship
      end
    end
  end

  def test_does_not_raise_on_eager_loading_a_strict_loading_has_one_relation
    Ship.first.update_column(:developer_id, Developer.first.id)
    developer = Developer.includes(:strict_loading_ship).first

    assert_nothing_raised { developer.strict_loading_ship }
  end

  def test_does_not_raise_on_eager_loading_a_has_one_relation_if_strict_loading_by_default
    with_strict_loading_by_default(Developer) do
      Ship.first.update_column(:developer_id, Developer.first.id)
      developer = Developer.includes(:ship).first

      assert_nothing_raised { developer.ship }
    end
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

  def test_raises_on_lazy_loading_a_has_many_relation_if_strict_loading_by_default
    with_strict_loading_by_default(Developer) do
      developer = Developer.first

      AuditLog.create(
        3.times.map do
          { developer_id: developer.id, message: "I am message" }
        end
      )

      assert_raises ActiveRecord::StrictLoadingViolationError do
        developer.audit_logs.first
      end
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

  def test_does_not_raise_on_eager_loading_a_has_many_relation_if_strict_loading_by_default
    with_strict_loading_by_default(Developer) do
      developer = Developer.first

      AuditLog.create(
        3.times.map do
          { developer_id: developer.id, message: "I am message" }
        end
      )

      developer = Developer.includes(:audit_logs).first

      assert_nothing_raised { developer.audit_logs.first }
    end
  end

  def test_raises_on_lazy_loading_a_strict_loading_habtm_relation
    developer = Developer.first
    developer.projects << Project.first

    assert_not developer.strict_loading_projects.loaded?

    assert_raises ActiveRecord::StrictLoadingViolationError do
      developer.strict_loading_projects.first
    end
  end

  def test_raises_on_lazy_loading_a_habtm_relation_if_strict_loading_by_default
    with_strict_loading_by_default(Developer) do
      developer = Developer.first
      developer.projects << Project.first

      assert_not developer.projects.loaded?

      assert_raises ActiveRecord::StrictLoadingViolationError do
        developer.projects.first
      end
    end
  end

  def test_does_not_raise_on_eager_loading_a_strict_loading_habtm_relation
    Developer.first.projects << Project.first
    developer = Developer.includes(:strict_loading_projects).first

    assert_nothing_raised { developer.strict_loading_projects.first }
  end

  def test_does_not_raise_on_eager_loading_a_habtm_relation_if_strict_loading_by_default
    with_strict_loading_by_default(Developer) do
      Developer.first.projects << Project.first
      developer = Developer.includes(:projects).first

      assert_nothing_raised { developer.projects.first }
    end
  end

  def test_strict_loading_violation_raises_by_default
    assert_equal :raise, ActiveRecord::Base.action_on_strict_loading_violation

    developer = Developer.first
    assert_not_predicate developer, :strict_loading?

    developer.strict_loading!
    assert_predicate developer, :strict_loading?

    assert_raises ActiveRecord::StrictLoadingViolationError do
      developer.audit_logs.to_a
    end
  end

  def test_strict_loading_violation_can_log_instead_of_raise
    old_value = ActiveRecord::Base.action_on_strict_loading_violation
    ActiveRecord::Base.action_on_strict_loading_violation = :log
    assert_equal :log, ActiveRecord::Base.action_on_strict_loading_violation

    developer = Developer.first
    assert_not_predicate developer, :strict_loading?

    developer.strict_loading!
    assert_predicate developer, :strict_loading?

    assert_logged("Strict loading violation: Developer is marked for strict loading. The AuditLog association named :audit_logs cannot be lazily loaded.") do
      developer.audit_logs.to_a
    end
  ensure
    ActiveRecord::Base.action_on_strict_loading_violation = old_value
  end

  private
    def with_strict_loading_by_default(model)
      previous_strict_loading_by_default = model.strict_loading_by_default

      model.strict_loading_by_default = true

      yield
    ensure
      model.strict_loading_by_default = previous_strict_loading_by_default
    end

    def assert_logged(message)
      old_logger = ActiveRecord::Base.logger
      log = StringIO.new
      ActiveRecord::Base.logger = Logger.new(log)

      begin
        yield

        log.rewind
        assert_match message, log.read
      ensure
        ActiveRecord::Base.logger = old_logger
      end
    end
end

class StrictLoadingFixturesTest < ActiveRecord::TestCase
  fixtures :strict_zines

  test "strict loading violations are ignored on fixtures" do
    ActiveRecord::FixtureSet.reset_cache
    create_fixtures("strict_zines")

    assert_nothing_raised do
      strict_zines(:going_out).interests.to_a
    end

    assert_raises(ActiveRecord::StrictLoadingViolationError) do
      StrictZine.first.interests.to_a
    end
  end
end
