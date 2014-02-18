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
