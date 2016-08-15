require "abstract_unit"
require "active_support/security_utils"

class SecurityUtilsTest < ActiveSupport::TestCase
  def test_secure_compare_should_perform_string_comparison
    assert ActiveSupport::SecurityUtils.secure_compare("a", "a")
    assert !ActiveSupport::SecurityUtils.secure_compare("a", "b")
  end
end
