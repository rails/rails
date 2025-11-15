**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Active Support Structured Events
================================

Active Support provides a unified API for reporting *structured events* inside your application. Structured events capture named facts about what happened, when it happened, and relevant contextual data. They form the foundation for Rails' observability story and can be exported to any external provider.

This guide explains the concepts, design, and usage patterns behind structured events, and how Rails integrates them with framework instrumentation.

After reading this guide, you will understand:

* What structured events are
* When to use them
* How Rails reports events
* How subscribers consume and export events
* How tags and context work
* How structured subscribers connect Notifications -> Events
* Where to find the authoritative API definitions
* The structured events emitted by Rails (framework hooks)

-------------------------------------------------------------

Introduction to Structured Events
---------------------------------

Structured events are machine-friendly, semantically consistent records describing something that occurred in your application. They are designed for production observability, fast search, analytics platforms, and developer-facing diagnostic tools.

Each event contains:

* a **name**
* a **payload** (hash or event object)
* **timestamp** (nanosecond precision)
* **source location**
* **tags**
* **context**

Rails automatically attaches timestamps, source location, and context so developers only need to provide a name and payload.

### Why structured events?

Rails already emits unstructured logs. They are ideal for development but become difficult and expensive to use in production:

* logs from many threads and processes interleave
* no consistent schema
* specialized knowledge needed to query
* indexing costs grow with volume
* onboarding requires understanding bespoke log formats

Structured events fix these problems:

* consistent shape
* semantic naming
* predictable payload keys
* cheap to index in structured stores
* easy to query
* compatible with any O11Y backend

They also unify **business events** and **developer observability events** behind a single API.

Reporting Events
----------------

The canonical entry point is:

```ruby
Rails.event.notify("event.name", { id: 123 })
```

This attaches metadata and forwards the event to any configured subscribers.

For full method signatures and advanced options (debug, caller depth, filtering rules), see the [EventReporter API documentation][].

### Event names

Use namespaced identifiers:

```
"controller.request_started"
"auth.user_created"
"graphql.query_resolved"
```

Names should reflect *what happened*, not how or why.

### Event payloads

Payloads may be:

* simple Ruby hashes
* domain-specific event objects that define their own schema

Rails merges any additional keyword arguments into the payload hash.

For details on object payloads and automatic key normalization, see:

* **[Event Objects][]**

### Debug events

Debug events are emitted only when debug mode is enabled:

```ruby
Rails.event.debug("cache.evicted", size: 1024)
```

Use these for high-volume diagnostic telemetry.

For details:

* **[Debug Events][]**

Subscribers
-----------

A subscriber receives events and is responsible for exporting them to a destination such as:

* a log file
* a streaming platform
* a metrics or analytics system
* a SaaS observability backend

Example:

```ruby
class JSONSubscriber
  def emit(event)
    LogExporter.write(JSON.generate(event))
  end
end

Rails.event.subscribe(JSONSubscriber.new)
```

Subscribers may also use filter procs to receive only certain events.

See:

* **[Subscribers][]**
* **[Filtered Subscriptions][]**

Tags
----

Tags annotate an event with domain-specific labels:

```ruby
Rails.event.tagged("graphql") do
  Rails.event.notify("user.created", id: 123)
end
```

Resulting event:

```json
"tags": {
  "graphql": true
}
```

Tags are stack-based and temporary.

See:

* **[Tags][]**

Context
-------

Context expresses execution-scoped metadata, such as request identifiers or job metadata. Context is automatically reset between requests and jobs.

```ruby
Rails.event.set_context(request_id: request.uuid)

Rails.event.notify("checkout.succeeded", id: order.id)
```

Resulting event:

```json
"context": {
  "request_id": "abcd123"
}
```

For custom stores and behavior:

* **[Context Store][]**

Relationship to ActiveSupport::Notifications
--------------------------------------------

Although both systems relate to what happens inside the application, they solve different problems.

### ActiveSupport::Notifications

* an *instrumentation* API
* measures *duration*, *allocations*, *start/finish*
* publishers wrap blocks of code
* subscribers react synchronously

### Structured Events (Event Reporter)

* a *reporting* API
* describes *what happened*, semantically
* payloads are structured
* metadata is attached automatically
* built for observability systems
* subscribers export data externally
* designed for high cardinality, low-cost search

### How they work together

`ActiveSupport::StructuredEventSubscriber` bridges the two systems:

1. listens to Notifications (e.g., `"process_action.action_controller"`)
2. transforms them
3. emits structured events via `Rails.event.notify`

Framework components such as Action Controller, Active Record, Active Job, and others use structured subscribers to convert internal instrumentation into structured events.

Structured Event Subscribers
----------------------------

A structured subscriber is a specialized Notifications subscriber that turns instrumentation events into structured events.

Example:

```ruby
class StructuredControllerSubscriber < ActiveSupport::StructuredEventSubscriber
  attach_to :action_controller

  def start_processing(event)
    emit_event("controller.request_started",
      controller: event.payload[:controller],
      action: event.payload[:action],
      format: event.payload[:format]
    )
  end
end
```

Key behaviors:

* auto-names methods based on the notification name
* supports silencing "debug-only" events
* forwards errors to `ActiveSupport.error_reporter`

These subscribers form the backbone of Rails' built-in events.

Security
--------

Hash-based payloads are filtered automatically using [`config.filter_parameters`][].

[Event objects][Event Objects] must be filtered by the subscriber, e.g. with [ActiveSupport::ParameterFilter][].



[EventReporter API documentation]: https://api.rubyonrails.org/classes/ActiveSupport/EventReporter.html
[Event Objects]: https://api.rubyonrails.org/classes/ActiveSupport/EventReporter.html#class-ActiveSupport::EventReporter-label-Event+Objects
[Debug Events]: https://api.rubyonrails.org/classes/ActiveSupport/EventReporter.html#class-ActiveSupport::EventReporter-label-Debug+Events
[Subscribers]: https://api.rubyonrails.org/classes/ActiveSupport/EventReporter.html#class-ActiveSupport::EventReporter-label-Subscribers
[Filtered Subscriptions]: https://api.rubyonrails.org/classes/ActiveSupport/EventReporter.html#class-ActiveSupport::EventReporter-label-Filtered+Subscriptions
[Tags]: https://api.rubyonrails.org/classes/ActiveSupport/EventReporter.html#class-ActiveSupport::EventReporter-label-Tags
[Context Store]: https://api.rubyonrails.org/classes/ActiveSupport/EventReporter.html#class-ActiveSupport::EventReporter-label-Context+Store

[`config.filter_parameters`]: https://guides.rubyonrails.org/configuring.html#config-filter-parameters
[ActiveSupport::ParameterFilter]: https://api.rubyonrails.org/classes/ActiveSupport/ParameterFilter.html


Framework Hooks (Structured Events Emitted by Rails)
----------------------------------------------------

Rails emits structured events across the framework covering controllers, jobs, database activity, caching, mailing, streaming, and more.

### Action Controller

#### `action_controller.request_started`

| Key           | Value                                                     |
| ------------- | --------------------------------------------------------- |
| `:controller` | The controller name                                       |
| `:action`     | The action                                                |
| `:format`     | html/js/json/xml etc                                      |
| `:params`     | Hash of request parameters without any filtered parameter |

#### `action_controller.request_completed`

| Key               | Value                                                      |
| ----------------- | ---------------------------------------------------------- |
| `:controller`     | The controller name                                        |
| `:action`         | The action                                                 |
| `:status`         | HTTP status code                                           |
| `:duration_ms`    | Total duration of the request in ms                        |
| `:gc_time_ms`     | Amount spent in garbage collection in ms                   |
| `:view_runtime`   | Amount spent in view in ms                                 |
| `:db_runtime`             | Amount spent executing database queries in ms      |
| `:queries_count`          | Amount of database queries executed                |
| `:cached_queries_count`   | Amount of cached database queries executed         |

#### `action_controller.file_sent`

| Key            | Value                               |
| -------------- | ----------------------------------- |
| `:path`        | Complete path to the file           |
| `:duration_ms` | Total duration of the request in ms |

#### `action_controller.data_sent`

| Key            | Value                               |
| -------------- | ----------------------------------- |
| `:filename`    | Name of the file being sent         |
| `:duration_ms` | Total duration of the request in ms |

#### `action_controller.redirected`

| Key          | Value                                    |
| ------------ | ---------------------------------------- |
| `:location`  | URL to redirect to                       |

#### `action_controller.callback_halted`

| Key       | Value                         |
| --------- | ----------------------------- |
| `:filter` | Filter that halted the action |

#### `action_controller.unpermitted_parameters`

| Key                 | Value                                                                   |
| ------------------- | ----------------------------------------------------------------------- |
| `:controller`       | The controller name                                                     |
| `:action`           | The action                                                              |
| `:unpermitted_keys` | The unpermitted keys                                                    |
| `:context`          | Hash with the following keys: `:controller`, `:action`, `:params`       |

#### `action_controller.rescue_from_handled`

| Key                    | Value                          |
| ---------------------- | ------------------------------ |
| `:exception_class`     | The class of the exception     |
| `:exception_message`   | The message of the exception   |
| `:exception_backtrace` | The backtrace of the exception |


### Action Controller: Caching

#### `action_controller.fragment_cache`

| Key            | Value            |
| -------------- | ---------------- |
| `:method`      | Cache method (e.g. `write_fragment`, `read_fragment`, `exist_fragment?`, `expire_fragment` |
| `:key`         | The complete key |
| `:duration_ms` | Duration in ms   |


### Action Dispatch

#### `action_dispatch.redirect`

| Key            | Value                                     |
| -------------- | ----------------------------------------- |
| `:location`    | URL to redirect to                        |
| `:status`      | HTTP response code                        |
| `:status_name` | HTTP response code                        |
| `:duration_ms` | Total duration of the request in ms       |
| `:source_location` | Source location of redirect in routes |


[`ActionDispatch::Request`]: https://api.rubyonrails.org/classes/ActionDispatch/Request.html
[`ActionDispatch::Response`]: https://api.rubyonrails.org/classes/ActionDispatch/Response.html

### Action Mailer

#### `action_mailer.delivered`

| Key                   | Value                                        |
| --------------------- | -------------------------------------------- |
| `:message_id`         | ID of the message, generated by the Mail gem |
| `:duration_ms`        | Total duration of the request in ms          |
| `:mail`               | The encoded form of the mail                 |
| `:perform_deliveries` | Whether delivery of this message is performed or not |
| `:exception_class`    | The class of the exception if present   |
| `:exception_message`  | The message of the exception if present |

#### `action_mailer.processed`

| Key             | Value                     |
| --------------- | ------------------------- |
| `:mailer`       | Name of the mailer class  |
| `:action`       | The action                |
| `:duration_ms`  | Total duration of the request in ms          |


### Action View

#### `action_view.render_template`

| Key           | Value                                    |
| ------------- | ---------------------------------------- |
| `:identifier` | Full path to template                    |
| `:layout`     | Applicable layout                        |
| `:duration_ms`   | Duration in ms                           |
| `:gc_ms`         | Amount spent in garbage collection in ms |

#### `action_view.render_partial`

| Key            | Value                                        |
| -------------- | -------------------------------------------- |
| `:identifier`  | Full path to template                        |
| `:layout`      | Applicable layout                            |
| `:duration_ms` | Duration in ms                               |
| `:gc_ms`       | Amount spent in garbage collection in ms     |
| `:cache_hit`   | `true` if the partial was fetched from cache |

#### `action_view.render_collection`

| Key             | Value                                    |
| --------------- | ---------------------------------------- |
| `:identifier`   | Full path to template                    |
| `:layout`       | Applicable layout                        |
| `:duration_ms`  | Duration in ms                           |
| `:gc_ms`        | Amount spent in garbage collection in ms |
| `:cache_hits`   | Number of partials fetched from cache    |
| `:count`        | Size of collection                       |

#### `action_view.render_layout`

| Key             | Value                                    |
| --------------- | ---------------------------------------- |
| `:identifier`   | Full path to template                    |
| `:duration_ms`  | Duration in ms                           |
| `:gc_ms`        | Amount spent in garbage collection in ms |

#### `action_view.render_start`

| Key             | Value                                    |
| --------------- | ---------------------------------------- |
| `:is_layout`    | If the template is a layout              |
| `:identifier`   | Full path to template                    |
| `:layout`       | Applicable layout                        |

### Active Job

#### `active_job.enqueued`

| Key             | Value                        |
| --------------- | ---------------------------- |
| `:job_class`    | Job class name               |
| `:job_id`       | Job ID                       |
| `:queue`        | Queue name                   |
| `:adapter`        | QueueAdapter object processing the job |
| `:aborted`        | Whether this job was aborted |
| `:exception_class`   | The class of the exception if present |
| `:exception_message` | The message of the exception if present |
| `:arguments`         | Arguments passed to the job if `log_arguments` is enabled |


#### `active_job.enqueue_at`

| Key                  | Value                        |
| -------------------- | ---------------------------- |
| `:job_class`         | Job class name               |
| `:job_id`            | Job ID                       |
| `:queue`             | Queue name                   |
| `:scheduled_at`      | Time the job was scheduled   |
| `:adapter`        | QueueAdapter object processing the job |
| `:aborted`        | Whether this job was aborted |
| `:exception_class`   | The class of the exception if present |
| `:exception_message` | The message of the exception if present |
| `:arguments`         | Arguments passed to the job if `log_arguments` is enabled |


#### `active_job.bulk_enqueued`

| Key                      | Value                                  |
| ------------------------ | -------------------------------------- |
| `:adapter`               | QueueAdapter object processing the job |
| `:job_count`             | Total number of jobs enqueued          |
| `:enqueued_count`        | Count of successfully enqueued jobs    |
| `:failed_enqueue_count`  | Count of jobs that failed to enqueue   |
| `:enqueued_classes`      | Array of job class names               |


#### `active_job.started`

| Key            | Value                     |
| -------------  | ------------------------- |
| `:job_class`   | Job class name            |
| `:job_id`      | Job ID                    |
| `:queue`       | Queue name                |
| `:enqueued_at` | Time the job was enqueued |
| `:arguments`   | Arguments passed to the job if `log_arguments` is enabled |


#### `active_job.completed`

| Key            | Value          |
| -------------- | -------------- |
| `:job_class`   | Job class name |
| `:job_id`      | Job ID         |
| `:queue`       | Queue name     |
| `:adapter`     | QueueAdapter object processing the job |
| `:aborted`     | Whether this job was aborted |
| `:duration`    | Duration in ms |
| `:exception_class`   | The class of the exception if present |
| `:exception_message` | The message of the exception if present |
| `:exception_backtrace` | The backtrace of the exception if present |


#### `active_job.retry_scheduled`

| Key                  | Value                        |
| -------------------- | ---------------------------- |
| `:job_class`         | Job class name               |
| `:job_id`            | Job ID                       |
| `:executions`        | Number of attempts           |
| `:wait_seconds`      | Seconds to wait before retry |
| `:exception_class`   | The class of the exception   |
| `:exception_message` | The message of the exception |


#### `active_job.retry_stopped`

| Key                  | Value                        |
| -------------------- | ---------------------------- |
| `:job_class`         | Job class name               |
| `:job_id`            | Job ID                       |
| `:executions`        | Number of attempts           |
| `:exception_class`   | The class of the exception   |
| `:exception_message` | The message of the exception |


#### `active_job.discarded`

| Key                  | Value                        |
| -------------------- | ---------------------------- |
| `:job_class`         | Job class name               |
| `:job_id`            | Job ID                       |
| `:exception_class`   | The class of the exception   |
| `:exception_message` | The message of the exception |


#### `active_job.interrupt`

| Key            | Value                        |
| -------------- | ---------------------------- |
| `:job_class`   | Job class name               |
| `:job_id`      | Job ID                       |
| `:description` | Description of the interrupt |
| `:reason`      | Reason for the interrupt     |


#### `active_job.resume`

| Key            | Value                        |
| -------------- | ---------------------------- |
| `:job_class`   | Job class name               |
| `:job_id`      | Job ID                       |
| `:description` | Description of the interrupt |

#### `active_job.step_skipped`

| Key          | Value                          |
| ------------ | ------------------------------ |
| `:job_class` | Job class name                 |
| `:job_id`    | Job ID                         |
| `:step`      | Name of the step being skipped |

#### `active_job.step_started`

| Key          | Value                            |
| ------------ | -------------------------------- |
| `:job_class` | Job class name                   |
| `:job_id`    | Job ID                           |
| `:step`      | Name of the step being skipped   |
| `:cursor`    | Cursor at which the step resumes |
| `:resumed`   | Whether the step is resuming     |


#### `active_job.step`

| Key                  | Value                            |
| -------------------- | -------------------------------- |
| `:job_class`         | Job class name                   |
| `:job_id`            | Job ID                           |
| `:step`              | Name of the step being skipped   |
| `:interrupted`       | Whether the step was interrupted |
| `:duration`          | Duration in ms                   |
| `:exception_class`   | The class of the exception if present   |
| `:exception_message` | The message of the exception if present |


### Active Record

#### `active_record.sql`

| Key            | Value                                                  |
| -------------- | ------------------------------------------------------ |
| `:async`       | `true` if query is loaded asynchronously               |
| `:name`        | Name of the operation                                  |
| `:sql`         | SQL statement                                          |
| `:cached`      | `true` is added when result comes from the query cache |
| `:lock_wait`   | How long the query waited to perform asynchronously    |
| `:binds`       | Bind parameters                                        |
| `:duration_ms` | Total duration of the query in ms                      |

#### `active_record.strict_loading_violation`

| Key      | Value                                                   |
| -------- | ------------------------------------------------------- |
| `:owner` | Model with `strict_loading` enabled                     |
| `:class` | Name of the class for the reflection of the association |
| `:name`  | Name of the reflection of the association               |


### Active Storage

#### `active_storage.preview`

| Key          | Value               |
| ------------ | ------------------- |
| `:key`       | Secure token        |
| `:duration_ms` | Total duration of the process |

### Active Storage: Storage Service

#### `active_storage.service_upload`

| Key          | Value                        |
| ------------ | ---------------------------- |
| `:key`       | Secure token                 |
| `:checksum`  | Checksum to ensure integrity |
| `:duration_ms` | Total duration of the process |

#### `active_storage.service_download`

| Key          | Value               |
| ------------ | ------------------- |
| `:key`       | Secure token        |
| `:duration_ms` | Total duration of the process |

#### `active_storage.service_streaming_download`

| Key          | Value               |
| ------------ | ------------------- |
| `:key`       | Secure token        |
| `:duration_ms` | Total duration of the process |

#### `active_storage.service_delete`

| Key          | Value               |
| ------------ | ------------------- |
| `:key`       | Secure token        |
| `:duration_ms` | Total duration of the process |

#### `active_storage.service_delete_prefixed`

| Key          | Value               |
| ------------ | ------------------- |
| `:prefix`    | Key prefix          |
| `:duration_ms` | Total duration of the process |

#### `active_storage.service_exist`

| Key          | Value                       |
| ------------ | --------------------------- |
| `:key`       | Secure token                |
| `:exist`     | File or blob exists or not  |
| `:duration_ms` | Total duration of the process |

#### `active_storage.service_url`

| Key          | Value               |
| ------------ | ------------------- |
| `:key`       | Secure token        |
| `:url`       | Generated URL       |
| `:duration_ms` | Total duration of the process |

#### `active_storage.service_mirror`

| Key             | Value                            |
| --------------- | -------------------------------- |
| `:key`          | Secure token                     |
| `:checksum`  | Checksum to ensure integrity |
| `:duration_ms` | Total duration of the process |


### Rails

#### `rails.deprecation`

| Key                    | Value                                                 |
| ---------------------- | ------------------------------------------------------|
| `:message`             | The deprecation warning                               |
| `:callstack`           | Where the deprecation came from                       |
| `:gem_name`            | Name of the gem reporting the deprecation             |
| `:deprecation_horizon` | Version where the deprecated behavior will be removed |
