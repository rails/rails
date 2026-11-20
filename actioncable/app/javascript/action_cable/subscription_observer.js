class SubscriptionObserver {
  #value = {};

  constructor(subscription, initial = {}, parser = String) {
    this.#value = initial;
    this.parser = parser;
    this.subscribers = new Set();
    this.subscription = subscription;
    
    this.subscription.received = (data) => {
      this.value = data;
    }
  }
  
  set value(val) {
    this.#value = val
    this.subscribers.forEach((subscriber) => {
      subscriber(this.value)
    })
  }
  
  get value() {
    return this.parser(this.#value)
  }
    
  subscribe(callback) {
    this.subscribers.add(callback)
    this.subscribers.forEach((subscriber) => {
      subscriber(this.value)
    })
    return () => { this.subscribers.remove(callback) }
  }
}

export default SubscriptionObserver;
