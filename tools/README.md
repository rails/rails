# Rails dev tools

This is a collection of utilities used for Rails internal development.
They aren't used by Rails apps directly.

  * `console` drops you in irb and loads local Rails repos
  * `railspect` provides commands to run internal linters
  * `line_statistics` provides CodeTools module and LineStatistics class to count lines
  * `test` is loaded by every major component of Rails to simplify testing, for example:
    `cd ./actioncable; bin/test ./path/to/actioncable_test_with_line_number.rb:5`
