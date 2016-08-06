require "abstract_unit"
require "action_controller/metal/strong_parameters"

class LogOnUnpermittedParamsTest < ActiveSupport::TestCase
  def setup
    ActionController::Parameters.action_on_unpermitted_parameters = :log
  end

  def teardown
    ActionController::Parameters.action_on_unpermitted_parameters = false
  end

  test "logs on unexpected param" do
    params = ActionController::Parameters.new(      book: { pages: 65 },
      fishing: "Turnips")

    assert_logged("Unpermitted parameter: fishing") do
      params.permit(book: [:pages])
    end
  end

  test "logs on unexpected params" do
    params = ActionController::Parameters.new(      book: { pages: 65 },
      fishing: "Turnips",
      car: "Mersedes")

    assert_logged("Unpermitted parameters: fishing, car") do
      params.permit(book: [:pages])
    end
  end

  test "logs on unexpected nested param" do
    params = ActionController::Parameters.new(      book: { pages: 65, title: "Green Cats and where to find then." })

    assert_logged("Unpermitted parameter: title") do
      params.permit(book: [:pages])
    end
  end

  test "logs on unexpected nested params" do
    params = ActionController::Parameters.new(      book: { pages: 65, title: "Green Cats and where to find then.", author: "G. A. Dog" })

    assert_logged("Unpermitted parameters: title, author") do
      params.permit(book: [:pages])
    end
  end

  private

    def assert_logged(message)
      old_logger = ActionController::Base.logger
      log = StringIO.new
      ActionController::Base.logger = Logger.new(log)

      begin
        yield

        log.rewind
        assert_match message, log.read
      ensure
        ActionController::Base.logger = old_logger
      end
    end
end
