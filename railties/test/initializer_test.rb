require 'abstract_unit'
require 'rails/initializer'
require 'rails/generators'

require 'action_view'
require 'action_mailer'
require 'active_record'

require 'plugin_test_helper'

class RailsRootTest < Test::Unit::TestCase
  def test_rails_dot_root_equals_rails_root
    assert_equal RAILS_ROOT, Rails.root.to_s
  end

  def test_rails_dot_root_should_be_a_pathname
    assert_equal File.join(RAILS_ROOT, 'app', 'controllers'), Rails.root.join('app', 'controllers').to_s
  end
end

