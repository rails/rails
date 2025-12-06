**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Active Support Structured Events
================================

Active Support provides a unified API for reporting *structured events* inside your application. A structured event is a
named record of something that occured in your application, including what happened, when, and from where. They form the
foundation for Rails' observability story and can be exported to any external provider.

This guide explains the concepts, design, and usage patterns behind structured events, and how Rails integrates them with framework instrumentation.

After reading this guide, you will understand:

* What structured events are and when to use them
* How Rails reports events
* How subscribers consume and export events
* How tags and context work
* Where to find the authoritative API definitions
* How to test structured events
* Framework events that Rails emits by default

-------------------------------------------------------------

Introduction to Structured Events
---------------------------------

Structured events are machine-friendly, semantically consistent records describing something that occurred in your application. They are designed for production observability, fast search, analytics platforms, and developer-facing diagnostic tools.

Each event contains:

* **name** - A string identifier for the event. When passing a string or symbol to `notify`, it's coerced to a string. When passing an event object, the class name is used (e.g., `"UserCreatedEvent"`).

* **payload** - The event data, which can be either:
  - A hash with symbolized keys (automatically filtered for sensitive parameters)
  - An event object (passed through as-is to subscribers for custom serialization)

* **timestamp** - A nanosecond-precision timestamp captured at event creation.

* **source_location** - Automatically captured metadata about where the event was emitted, containing:
  - `filepath`: The file path where `notify` was called
  - `lineno`: The line number
  - `label`: The method or context name (e.g., `"UserService#create"`)

* **tags** - Domain-specific metadata attached via the `tagged` method. Tags are fiber-local and stack-oriented, meaning nested `tagged` blocks accumulate tags.

* **context** - Request or job-scoped metadata set via `set_context`. Unlike tags, context persists across the entire request/job lifecycle until explicitly cleared.

```ruby
# Set context for the request
Rails.event.set_context(request_id: "abc123", user_agent: "Mozilla/5.0")

# Use tags for domain-specific context
Rails.event.tagged("graphql", query_type: "mutation") do
  # Emit event from UserService#create at line 42
  Rails.event.notify("user.created", { id: 456, email: "user@example.com" })
end

# Resulting event hash passed to subscribers:
# {
#   name: "user.created",
#   payload: { id: 456, email: "user@example.com" },
#   tags: { graphql: true, query_type: "mutation" },
#   context: { request_id: "abc123", user_agent: "Mozilla/5.0" },
#   timestamp: 1738964843208679035,
#   source_location: {
#     filepath: "/app/services/user_service.rb",
#     lineno: 42,
#     label: "UserService#create"
#   }
# }
```

Rails automatically attaches timestamp and source location information to events. Developers can use
tags and context to supply events with additional information. Individual events require a name and payload.

### Why Structured Events?

Rails already emits unstructured logs. They are ideal for development but become difficult and expensive to use in production. Some of the challenges of logs are as follows:

* logs from many threads and processes interleave, making it difficult to understand what's happening
* a lack of consistent schema requires specialized knowledge to query the logs
* indexing costs grow with volume

Structured events fix these problems as they:

* have a consistent shape
* have semantic naming and predictable payload keys
* are cheap to index in structured stores
* are easy to query
* are easily integrated with any Observability backend

They also unify **business events** and **developer observability events** behind a single API.
For example:

```ruby
# Business events represent domain-specific application logic
Rails.event.notify("order_created", order_id: 123, total: 99.99)
Rails.event.notify("payment_processed", transaction_id: "abc", amount: 49.99)
Rails.event.notify("user_signed_up", user_id: 456, plan: "premium")

# Developer observability events represent framework and system behavior
Rails.event.notify("sql.query", sql: "SELECT * FROM users", duration: 12.5)
Rails.event.notify("cache.hit", key: "user:123", store: "redis")
Rails.event.notify("request.completed", path: "/api/orders", status: 200)
```

Both event types use the same API and receive the same metadata (timestamp, source location, tags, context).

Reporting Events
----------------

The canonical entry point is `#notify`:

```ruby
Rails.event.notify("event.name", { id: 123 })
```

This attaches metadata and forwards the event to any configured subscribers.

For full method signatures and advanced options (debug, caller depth, filtering rules), see the [EventReporter API documentation][].

### Event Names

Event names should be descriptive and specific. A series of structured events should tell a good story about what happened.

```ruby
# Good
Rails.event.notify("order_created", order_id: order.id, shop_id: shop.id)
Rails.event.notify("payment_processed", amount: 49.99, currency: "USD")
Rails.event.notify("shipping_label_generated", carrier: "USPS")

# Avoid: Too generic or interpolated
Rails.event.notify("order", ...)              # Too vague
Rails.event.notify("order_#{order.id}", ...)  # String interpolation creates high cardinality
```

Names should reflect *what happened*, not how or why. Variable data belongs in the payload, not the event name.
Event names can be reused, but repeated events should represent the same "thing" conceptually.

### Event Payloads

Payloads are Ruby hashes containing event-specific attributes. Consider an order fulfillment workflow:

```ruby
# When an order is created
Rails.event.notify("order_created",
  order_id: order.id,
  shop_id: shop.id,
  total_amount: order.total_price,
  currency: order.currency,
  line_item_count: order.line_items.count
)

# When payment is processed
Rails.event.notify("payment_processed",
  order_id: order.id,
  payment_id: payment.id,
  amount: payment.amount,
  currency: payment.currency,
  gateway: payment.gateway_name,
  status: "captured"
)

# When shipping label is created
Rails.event.notify("shipping_label_generated",
  order_id: order.id,
  fulfillment_id: fulfillment.id,
  carrier: "USPS",
  tracking_number: fulfillment.tracking_number,
  shipping_method: "standard"
)
```

The resulting event includes automatically-attached metadata:

```ruby
# Emits event:
{
  name: "order_completed",
  payload: { order_id: 123, shipped_at: 2025-01-15 10:30:00 UTC },
  timestamp: 1738964843208679035,
  source_location: {
    filepath: "app/services/fulfillment_service.rb",
    lineno: 45,
    label: "FulfillmentService#complete"
  }
}
```

#### Best Practices for Payload Design

* Use consistent attribute names across related events
* Include identifiers for correlation: `order_id`, `shop_id`, `user_id`
* Keep payloads focused, and only include relevant data
* Omit nil values
* Follow semantic conventions when available (e.g., OpenTelemetry)

Further details on object payloads and automatic key normalization can be found in the [Event Objects][] section of the API documentation.

* **[Event Objects][]**

### Debug Events

Debug events are emitted only when debug mode is enabled:

```ruby
# High-volume diagnostic information
Rails.event.debug("inventory_check_performed",
  order_id: order.id,
  sku: line_item.sku,
  available_quantity: inventory.quantity
)

# Expensive payload: only computed in debug mode
Rails.event.debug("large_data_exported",
  user_id: user.id,
  export_id: export.id
) do
  {
    exported_data: generate_large_export_data, # This could be computationally intensive
    record_count: export.items.count,
    export_time_ms: export.elapsed_time
  }
end
```

Debug events help diagnose issues in development or when explicitly enabled via `Rails.event.with_debug`.
For example:

```ruby
class ApplicationController < ActionController::Base
  around_action :with_event_debug_if_requested

  private

  def with_event_debug_if_requested
    if params[:debug]
      Rails.event.with_debug { yield }
    else
      yield
    end
  end
end
```

With this setup in `ApplicationController`, any request with the `debug` query parameter (e.g., `?debug=1`) will execute inside `Rails.event.with_debug`. All `Rails.event.debug` events triggered during that request will be emitted.

This prevents high-volume diagnostic telemetry from flooding production logs by default.

Further details on debug events can be found in the [Debug Events][] section of the API documentation.

* **[Debug Events][]**

Subscribers
-----------

A subscriber receives events and is responsible for exporting them to a destination such as:

* a log file
* a streaming platform
* a metrics or analytics system
* a SaaS observability backend

Here's an example of a subscriber that exports order events to an analytics platform:

```ruby
class OrderAnalyticsSubscriber
  def emit(event)
    case event[:name]
    when "order_created", "order_completed", "payment_processed"
      AnalyticsPlatform.track(
        event_name: event[:name],
        timestamp: event[:timestamp],
        properties: event[:payload],
        source: event[:source_location]
      )
    end
  end
end

Rails.event.subscribe(OrderAnalyticsSubscriber.new)
```

Subscribers can also filter events to receive only specific types:

```ruby
Rails.event.subscribe(
  OrderAnalyticsSubscriber.new,
  filter: ->(event) { event[:name].start_with?("order_") }
)
```

Real-world subscriber implementations often:

* Batch events for efficiency
* Handle errors gracefully to avoid disrupting the application
* Perform async export to external systems
* Apply additional filtering or transformation

For more information on [Subscribers][] and [Filtered Subscriptions][], please see their respective sections within the Structured Events API documentation.

* **[Subscribers][]**
* **[Filtered Subscriptions][]**

Tags
----

Tags annotate events with domain-specific labels that help categorize and filter events across your application. Use tags when you want to mark related events with categorical attributes without repeating them in every payload.

Here's an example tagging payment events by gateway and environment:

```ruby
class PaymentProcessor
  def charge(order)
    # Tag all payment-related events with the gateway being used
    Rails.event.tagged(gateway: payment_gateway.name) do
      Rails.event.notify("payment_processing_started",
        order_id: order.id,
        amount: order.total_price
      )

      result = payment_gateway.charge(order)

      if result.success?
        Rails.event.notify("payment_captured",
          order_id: order.id,
          transaction_id: result.transaction_id,
          amount: order.total_price
        )
      else
        Rails.event.notify("payment_declined",
          order_id: order.id,
          error_code: result.error_code
        )
      end
    end
  end
end
```

All three events receive the `gateway` tag, making it easy to filter payment events by gateway in your observability platform:

```json
{
  "name": "payment_captured",
  "tags": { "gateway": "stripe" },
  "payload": { "order_id": 123, "transaction_id": "ch_abc", "amount": 49.99 }
}
```

Tags are stack-based, meaning that they automatically clear when the block exits. Tags can also nest: when you enter a nested `tagged` block, the new tags are merged with outer tags and applied to events inside the block.

Further details on tags can be found in the [Tags][] section of the API documentation.

* **[Tags][]**

Context
-------

Context expresses execution-scoped metadata that should be attached to *all events* within a request, job, or other work unit. Unlike tags, which are block-scoped, context is set once and automatically flows through your entire application for the duration of that execution.

### Setting Context in Middleware

The most common pattern is setting context early in the request lifecycle, such as in Rack middleware:

```ruby
class EventContextMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)

    # Set context once for the entire request
    Rails.event.set_context(
      request_id: request.request_id,
      shop_id: extract_shop_id(env),
      api_client_id: extract_api_client_id(env)
    )

    @app.call(env)
  end

  private

  def extract_shop_id(env)
    env['HTTP_X_SHOP_ID']&.to_i
  end

  def extract_api_client_id(env)
    env['HTTP_X_API_CLIENT_ID']&.to_i
  end
end
```

With this middleware in place, every event in your application automatically includes the context:

```ruby
class OrdersController < ApplicationController
  def create
    order = Order.create!(order_params)

    Rails.event.notify("order_created",
      order_id: order.id,
      total_amount: order.total_price
    )
  end
end
```

```json
{
  "name": "order_created",
  "payload": { "order_id": 123, "total_amount": 49.99 },
  "context": {
    "request_id": "req_abc123",
    "shop_id": 456,
    "api_client_id": 789
  }
}
```

You can also set context for background jobs, ensuring that every event emitted during the job's execution includes
relevant job-scoped metadata such as the job ID or custom attributes. For example:

```ruby
class ExportOrdersJob < ApplicationJob
  before_perform do |job|
    Rails.event.set_context(job_id: job.job_id)
  end

  def perform(exporter, export_params)
    Rails.event.notify("orders.export.started", count: Order.count)
    # Perform export logic...
    Rails.event.notify("orders.export.finished", status: "ok")
  end
end
```

Which results in the following events when the job runs:

```json
{
  "name": "orders.export.started",
  "payload": { "count": 42 },
  "context": {
    "job_id": "abcd-1234",
  }
}
```

NOTE: Context is automatically reset between requests and jobs, ensuring complete isolation between work units.

### Context vs Payload

A key principle: **correlation IDs belong in context, business data belongs in the payload**.

```ruby
# Good: shop_id in context, order-specific data in payload
Rails.event.set_context(shop_id: current_shop.id, request_id: request.uuid)
Rails.event.notify("order_created",
  order_id: order.id,
  total_amount: order.total_price,
  currency: order.currency
)

# Avoid: Repeating shop_id in every event payload
Rails.event.notify("order_created",
  shop_id: current_shop.id,  # Should be in context
  order_id: order.id,
  total_amount: order.total_price
)
Rails.event.notify("payment_processed",
  shop_id: current_shop.id,  # Should be in context
  order_id: order.id,
  amount: 49.99
)
```

Further details on the context store can be found in the [Context Store][] section of the API documentation.

* **[Context Store][]**

Testing Structured Events
-------------------------

<TBD>

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
Relationship to ActiveSupport::Notifications
--------------------------------------------

If you're familiar with `ActiveSupport::Notifications`, you might wonder how Structured Events differ. While both systems help you understand what's happening inside your application, they're designed for different use cases.

`ActiveSupport::Notifications` is an instrumentation API focused on measuring performance. When you want to track how long something takes, how much memory it allocates, or when it starts and finishes, you wrap that code in an instrumentation block. Subscribers listen for these notifications and react synchronously within your application. This is perfect for things like logging slow queries or tracking request timing.

Structured Events takes a different approach. Rather than measuring performance, it's designed to report on what happened in your application using structured, semantic data. Each event includes a payload describing the action along with automatically-attached metadata. This makes Structured Events particularly well-suited for external observability systems, where you need rich, searchable data about application behavior. The system is optimized for high-cardinality events, such as tracking every user action or API call, with efficient querying in modern observability platforms.

In practice, you'll often use both: `ActiveSupport::Notifications` for performance monitoring and Structured Events for behavioral analytics and debugging.

### How ActiveSupport::Notifications and Structured Events Work Together

`ActiveSupport::StructuredEventSubscriber` bridges the two systems:

1. listens to Notifications (e.g., `"process_action.action_controller"`)
2. transforms them
`ActiveSupport::StructuredEventSubscriber` bridges the two systems by:

1. listening to notifications (e.g., `"process_action.action_controller"`)
2. transforming them, and
3. emitting structured events via `Rails.event.notify`.

In the following section, you will see how framework components such as Action Controller, Active Record, Active Job, and others use structured subscribers to convert internal instrumentation into structured events.

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

A structured subscriber:

* auto-names methods based on the notification name
* supports silencing "debug-only" events
* forwards errors to `ActiveSupport.error_reporter`

These subscribers form the backbone of Rails' built-in events.

Security
--------

Hash-based payloads are filtered automatically using [`config.filter_parameters`][].

[Event objects][Event Objects] must be filtered by the subscriber, e.g. with [ActiveSupport::ParameterFilter][].
Security
--------

Structured Events respects your application's privacy settings by automatically filtering sensitive data from hash-based payloads using [`config.filter_parameters`][]. This means if you've set up filters for passwords, tokens, or credit card numbers elsewhere in your app, those same filters apply here.

However, if you're using [Event objects][Event Objects], you'll need to handle filtering yourself in your subscriber. You can use [ActiveSupport::ParameterFilter][] to apply the same filtering rules. This extra step with Event objects gives you full control over how data is filtered before it leaves your application, which is particularly important when exporting to external systems.

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

Rails emits structured events across the framework covering controllers, jobs, database activity, caching, mailing, streaming, and more. Below you can find a list of these events and their payloads.

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
