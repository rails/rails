require 'abstract_unit'
require 'fixtures/developer'
require 'fixtures/project'

class ReadOnlyTest < Test::Unit::TestCase
  fixtures :developers, :projects, :developers_projects

  def test_cant_save_readonly_record
    dev = Developer.find(:first)
    assert !dev.readonly?

    dev.readonly!
    assert dev.readonly?

    assert_nothing_raised do
      dev.name = 'Luscious forbidden fruit.'
      assert !dev.save
      dev.name = 'Forbidden.'
    end
    assert_raise(ActiveRecord::ReadOnlyRecord) { dev.save  }
    assert_raise(ActiveRecord::ReadOnlyRecord) { dev.save! }
  end

  def test_find_with_readonly_option
    Developer.find(:all).each { |d| assert !d.readonly? }
    Developer.find(:all, :readonly => false).each { |d| assert !d.readonly? }
    Developer.find(:all, :readonly => true).each { |d| assert d.readonly? }
  end

  def test_find_with_joins_option_implies_readonly
    Developer.find(:all, :joins => '').each { |d| assert d.readonly? }
    Developer.find(:all, :joins => '', :readonly => false).each { |d| assert !d.readonly? }
  end

  def test_habtm_find_readonly
    dev = Developer.find(:first)
    dev.projects.each { |p| assert !p.readonly? }
    dev.projects.find(:all) { |p| assert !p.readonly? }
    dev.projects.find(:all, :readonly => true) { |p| assert p.readonly? }
  end
end
