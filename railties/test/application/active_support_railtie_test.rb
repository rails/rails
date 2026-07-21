# frozen_string_literal: true

require "isolation/abstract_unit"
require "active_support/testing/ractors_assertions.rb"

module ApplicationTests
  class ActiveSupportRailtieTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include ActiveSupport::Testing::RactorsAssertions

    setup :build_app
    teardown :teardown_app

    test "inflections instances are frozen after the app boots" do
      app "development"

      ActiveSupport::Inflector::Inflections.all_instances.each do |instance|
        assert_ractor_shareable(instance)
      end

      assert_ractor_shareable(ActiveSupport::Inflector.inflections)
    end

    test "mutating inflections after the app boots is deprecated" do
      app "development"

      ActiveSupport::Inflector.inflections do |inflect|
        assert_raises(FrozenError) do
          inflect.plural("animal", "animaux")
        end
      end
    end
  end
end
