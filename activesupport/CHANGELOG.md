*   Add `Range#intersection(other)` and `Range#inverted?` methods

    Given ranges `r1` and `r2`, `r1.intersection(r2)` returns the overlapping range (or `nil` if no overlap)

        (1..5).intersection(2..6) => (2..5)

    Given range `r`, `r.inverted?` is true if `r.begin > r.end` else false

        (5..1).inverted? => true

    *Chris Natali*

*   Improve `File.atomic_write` error handling

*   Fix `Class#descendants` and `DescendantsTracker#descendants` compatibility with Ruby 3.1.

    [The native `Class#descendants` was reverted prior to Ruby 3.1 release](https://bugs.ruby-lang.org/issues/14394#note-33),
    but `Class#subclasses` was kept, breaking the feature detection.

    *Jean Boussier*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/activesupport/CHANGELOG.md) for previous changes.
