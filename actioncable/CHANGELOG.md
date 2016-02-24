## Rails 5.0.0.beta3 (February 24, 2016) ##

*  Added ActionCable::SubscriptionAdapter::EventedRedis.em_redis_connector/redis_connector and
   ActionCable::SubscriptionAdapter::Redis.redis_connector factory methods for redis connections, 
   so you can overwrite with your own initializers. This is used when you want to use different-than-standard Redis adapters,
   like for Makara distributed Redis.

   *DHH*

## Rails 5.0.0.beta2 (February 01, 2016) ##

*   Support PostgreSQL pubsub adapter.

    *Jon Moss*

*   Remove EventMachine dependency.

    *Matthew Draper*

*   Remove Celluloid dependency.

    *Mike Perham*

*   Create notion of an `ActionCable::SubscriptionAdapter`.
    Separate out Redis functionality into
    `ActionCable::SubscriptionAdapter::Redis`, and add a
    PostgreSQL adapter as well. Configuration file for
    ActionCable was changed from`config/redis/cable.yml` to
    `config/cable.yml`.

   *Jon Moss*

## Rails 5.0.0.beta1 (December 18, 2015) ##

*   Added to Rails!

    *DHH*
