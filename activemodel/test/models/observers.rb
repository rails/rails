class ORM
  include ActiveModel::Observing

  def save
    notify_observers :before_save
  end

  class Observer < ActiveModel::Observer
    def before_save_invocations
      @before_save_invocations ||= []
    end

    def before_save(record)
      before_save_invocations << record
    end
  end
end

class Widget < ORM; end
class Budget < ORM; end
class WidgetObserver < ORM::Observer; end
class BudgetObserver < ORM::Observer; end
class AuditTrail < ORM::Observer
  observe :widget, :budget
end

ORM.instantiate_observers
