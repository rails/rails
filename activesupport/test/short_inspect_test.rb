require 'abstract_unit'
require 'active_support/short_inspect'

class ShortInspectTest < Test::Unit::TestCase
  def test_inspect_excludes_instance_variables
    o = Object.new
    o.instance_eval { @a = "hello" }
    o.extend(ActiveSupport::ShortInspect)
    assert !o.inspect.include?("hello")
  end
end
