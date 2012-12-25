require 'cases/helper'
require 'models/project'

class DeprecatedMassAssignmentSecurityTest < ActiveModel::TestCase
  def test_attr_accessible_raise_error
    assert_raise RuntimeError, /protected_attributes/ do
      Project.attr_accessible :username
    end
  end

  def test_attr_protected_raise_error
    assert_raise RuntimeError, /protected_attributes/ do
      Project.attr_protected :username
    end
  end
end
