*   Pass the error instance as the second parameter of block executed by `discard_on`.

    Fixes #32853.

    *Yuji Yaginuma*

## Rails 5.2.0 (April 09, 2018) ##

*   Allow block to be passed to `ActiveJob::Base.discard_on` to allow custom handling of discard jobs.

    Example:

        class RemoteServiceJob < ActiveJob::Base
          discard_on(CustomAppException) do |job, exception|
            ExceptionNotifier.caught(exception)
          end

          def perform(*args)
            # Might raise CustomAppException for something domain specific
          end
        end

    *Aidan Haran*

*   Support redis-rb 4.0.

    *Jeremy Daer*

Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/activejob/CHANGELOG.md) for previous changes.
