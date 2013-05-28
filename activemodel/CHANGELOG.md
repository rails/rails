*   `validates_inclusion_of` for ranges uses the speedy Range#cover for numerical ranges, and the accurate Range#include? for non-numerical ranges.

    *Charles Bergeron*

*   Deprecate `Validator#setup`. This should be done manually now in the validator's constructor.

    *Nick Sutterer*

Please check [4-0-stable](https://github.com/rails/rails/blob/4-0-stable/activemodel/CHANGELOG.md) for previous changes.
