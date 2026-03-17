# frozen_string_literal: true

module ActiveSupport::Dependencies::RequireDependency
  # <b>Warning:</b> This method is deprecated.
  def require_dependency(filename)
    ActiveSupport.deprecator.warn <<~MSG
      require_dependency is deprecated without replacement and will be removed
      in Rails 9.

      - Recommendations for applications:

          - If the call is an old one written in the days of the classic autoloader to ensure a
            certain constant is loaded for constant lookup to work as expected, you can simply
            remove it.

          - In order to preload classes when the application boots, which may be necessary for
            things like STIs or Kafka consumers, please check the autoloading guide for modern
            approaches.

      - Recommendations for engines that depend on Rails >= 7.0:

        Same recommendations as for applications, since the classic autoloader is no longer
        available starting with Rails 7.0.

      - Recommendations for engines that support Rails < 7.0:

        Guard the call with a version check just in case the parent application is using
        the classic autoloader:

            require_dependency "some_file" if Rails::VERSION::MAJOR < 7
    MSG

    filename = filename.to_path if filename.respond_to?(:to_path)

    unless filename.is_a?(String)
      raise ArgumentError, "the file name must be either a String or implement #to_path -- you passed #{filename.inspect}"
    end

    if abspath = ActiveSupport::Dependencies.search_for_file(filename)
      require abspath
    else
      require filename
    end
  end

  # We could define require_dependency in Object directly, but a module makes
  # the extension apparent if you list ancestors.
  Object.prepend(self)
end
