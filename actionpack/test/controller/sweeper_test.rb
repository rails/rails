require 'abstract_unit'


class SweeperTest < ActionController::TestCase

  class ::AppSweeper < ActionController::Caching::Sweeper; end

  def test_sweeper_should_not_ignore_unknown_method_calls
    sweeper = ActionController::Caching::Sweeper.send(:new)
    assert_raise NameError do
      sweeper.instance_eval do
        some_method_that_doesnt_exist
      end
    end
  end
end
