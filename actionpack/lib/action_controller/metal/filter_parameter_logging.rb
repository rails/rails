module ActionController
  module FilterParameterLogging
    extend ActiveSupport::Concern

    module ClassMethods
      # This method has been moved to ActionDispatch::Http::ParametersFilter.filter_parameters
      def filter_parameter_logging(*filter_words, &block)
        ActiveSupport::Deprecation.warn("Setting filter_parameter_logging in ActionController is deprecated, please set 'config.filter_parameters' in application.rb or environments/[environment_name].rb instead.", caller)
        ActionDispatch::Http::ParametersFilter.filter_parameters(*filter_words, &block)
      end
    end
  end
end
