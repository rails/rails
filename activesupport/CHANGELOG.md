* Add ActiveSupport::Deprecation::DeprecatedConstantAccessor

  Provides transparent deprecation of constants, compatible with exceptions.
  Example usage:

      module Example
        include ActiveSupport::Deprecation::DeprecatedConstantAccessor
        deprecate_constant 'OldException', 'Elsewhere::NewException'
      end

  *Dominic Cleal*

Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/activesupport/CHANGELOG.md) for previous changes.
