class Rails::Conductor::InitializersController < Rails::Conductor::CommandController
  def show
    @initializers = Rails.application.initializers.tsort_each.map do |initializer|
      "#{initializer.context_class}.#{initializer.name}"
    end
  end
end
