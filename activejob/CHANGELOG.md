*   Allow block to be passed to ActiveJob::Base.discard_on to allow custom handling of discard jobs.

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
    
*   Change logging instrumentation to log errors when a job raises an exception.

    Fixes #26848.

    *Steven Bull*


Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/activejob/CHANGELOG.md) for previous changes.
