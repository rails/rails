*   Fix `console` and `generators` blocks defined at different environments.

    Fixes #14748.

    *Rafael Mendonça França*

*   Move configuration of asset precompile list and version to an initializer.

    *Matthew Draper*

*   Do not set the Rails environment to test by default when using test_unit Railtie.

    *Konstantin Shabanov*

*   Remove sqlite3 lines from `.gitignore` if the application is not using sqlite3.

    *Dmitrii Golub*

*   Add public API to register new extensions for `rake notes`.

    Example:

        config.annotations.register_extensions("scss", "sass") { |tag| /\/\/\s*(#{tag}):?\s*(.*)$/ }

    *Roberto Miranda*

*   Removed unnecessary `rails application` command.

    *Arun Agrawal*

*   Make the `rails:template` rake task load the application's initializers.

    Fixes #12133.

    *Robin Dupret*

*   Introduce `Rails.gem_version` as a convenience method to return
    `Gem::Version.new(Rails.version)`, suggesting a more reliable way to perform
    version comparison.

    Example:

        Rails.version #=> "4.1.2"
        Rails.gem_version #=> #<Gem::Version "4.1.2">

        Rails.version > "4.1.10" #=> false
        Rails.gem_version > Gem::Version.new("4.1.10") #=> true
        Gem::Requirement.new("~> 4.1.2") =~ Rails.gem_version #=> true

    *Prem Sichanugrist*

*   Avoid namespacing routes inside engines.

    Mountable engines are namespaced by default so the generated routes
    were too while they should not.

    Fixes #14079.

    *Yves Senn*, *Carlos Antonio da Silva*, *Robin Dupret*

Please check [4-1-stable](https://github.com/rails/rails/blob/4-1-stable/railties/CHANGELOG.md) for previous changes.
