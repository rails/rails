class Rails::Conductor::MiddlewaresController < Rails::Conductor::CommandController
  def show
    @middlewares = Rails.configuration.middleware.map do |middleware|
      "use #{middleware.inspect}"
    end

    @middlewares << "run #{Rails.application.class.name}.routes"
  end
end
