## Rails 5.2.0.rc2 (March 20, 2018) ##

*   No changes.


## Rails 5.2.0.rc1 (January 30, 2018) ##

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


## Rails 5.2.0.beta2 (November 28, 2017) ##

*   No changes.


## Rails 5.2.0.beta1 (November 27, 2017) ##

*   Support redis-rb 4.0.

    *Jeremy Daer*

Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/activejob/CHANGELOG.md) for previous changes.
