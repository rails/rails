require 'abstract_unit'

module Rails
  def self.root
    @root ||= File.expand_path(File.join(File.dirname(__FILE__), '..', 'fixtures'))
  end
end
Rails.application.config.root = Rails.root

require 'rails/generators'
require 'rails/generators/test_case'

require 'rubygems'
require 'active_record'
require 'action_dispatch'

class GeneratorsTestCase < Rails::Generators::TestCase
  destination File.join(Rails.root, "tmp")
  setup :prepare_destination

  def self.inherited(base)
    base.tests Rails::Generators.const_get(base.name.sub(/Test$/, ''))
  rescue
    # Do nothing.
  end

  def test_truth
    # Don't cry test/unit
  end
end