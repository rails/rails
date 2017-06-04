module ActionController
  # Specify binary encoding for parameters for a given action.
  module ParameterEncoding
    extend ActiveSupport::Concern

    module ClassMethods
      def inherited(klass) # :nodoc:
        super
        klass.setup_param_encode
      end

      def setup_param_encode # :nodoc:
        @_parameter_encodings = {}
      end

      def binary_params_for?(action) # :nodoc:
        @_parameter_encodings[action.to_s]
      end

      # Specify that a given action's parameters should all be encoded as
      # ASCII-8BIT (it "skips" the encoding default of UTF-8).
      #
      # For example, a controller would use it like this:
      #
      #   class RepositoryController < ActionController::Base
      #     skip_parameter_encoding :show
      #
      #     def show
      #       @repo = Repository.find_by_filesystem_path params[:file_path]
      #
      #       # `repo_name` is guaranteed to be UTF-8, but was ASCII-8BIT, so
      #       # tag it as such
      #       @repo_name = params[:repo_name].force_encoding 'UTF-8'
      #     end
      #
      #     def index
      #       @repositories = Repository.all
      #     end
      #   end
      #
      # The show action in the above controller would have all parameter values
      # encoded as ASCII-8BIT. This is useful in the case where an application
      # must handle data but encoding of the data is unknown, like file system data.
      def skip_parameter_encoding(action)
        @_parameter_encodings[action.to_s] = true
      end
    end
  end
end
