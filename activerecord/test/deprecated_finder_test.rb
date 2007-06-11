require 'abstract_unit'
require 'fixtures/entrant'

class DeprecatedFinderTest < Test::Unit::TestCase
  fixtures :entrants

  def test_deprecated_find_all_was_removed
    assert_raise(NoMethodError) { Entrant.find_all }
  end

  def test_deprecated_find_first_was_removed
    assert_raise(NoMethodError) { Entrant.find_first }
  end

  def test_deprecated_find_on_conditions_was_removed
    assert_raise(NoMethodError) { Entrant.find_on_conditions }
  end

  def test_count
    assert_equal(0, Entrant.count(:conditions => "id > 3"))
    assert_equal(1, Entrant.count(:conditions => ["id > ?", 2]))
    assert_equal(2, Entrant.count(:conditions => ["id > ?", 1]))
  end

  def test_count_by_sql
    assert_equal(0, Entrant.count_by_sql("SELECT COUNT(*) FROM entrants WHERE id > 3"))
    assert_equal(1, Entrant.count_by_sql(["SELECT COUNT(*) FROM entrants WHERE id > ?", 2]))
    assert_equal(2, Entrant.count_by_sql(["SELECT COUNT(*) FROM entrants WHERE id > ?", 1]))
  end
end
