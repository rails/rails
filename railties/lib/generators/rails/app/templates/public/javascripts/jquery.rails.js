jQuery(function ($) {
    var rails = {
        update: function (selector, content, position) {
            var element = $('#' + selector);
            if (position) {
                switch (position) {
                    case "before":
                        element.before(content); 
                        break;
                    case "after":
                        element.after(content); 
                        break;
                    case "top":
                        element.prepend(content); 
                        break;
                    case "bottom":
                        element.append(content); 
                        break;
                    default:
                        element.append(content); 
                        break;
                }
            } else {
                element.html(content); 
            }
        },
        remote: function (e) {
            var el          = $(this),
                data        = [],
                condition   = el.attr('data-condition') ? eval(el.attr('data-condition')) : true,
                method      = el.attr('method') || el.attr('data-method') || 'GET',
                url         = el.attr('action') || el.attr('data-url') || '#',
                async       = el.attr('data-remote-type') === 'synchronous' ? false : true;

            if (el.attr('data-submit')) {
                data = $('#' + el.attr('data-submit')).serializeArray();
            } else if (el.attr('data-with')) {

                if (e && e.target.tagName.toUpperCase() == 'SCRIPT' && el.attr('data-observed') !== null) {
                    var observed = $('#' + el.attr('data-observed'));
                    if(observed[0].tagName.toUpperCase() === 'FORM'){
                        data = el.attr('data-with') + '=' + observed.serialize();
                    } else if(observed[0].tagName.toUpperCase() === 'INPUT' && observed.attr('type').toUpperCase() !== "BUTTON" && observed.attr('type').toUpperCase() !== "SUBMIT") {
                        data = el.attr('data-with') + '=' + observed.val();
                    }
                } else {
                    // TODO: remove eval when deprecated
                    data = eval(el.attr('data-with'));
                }
            } else if (e && e.target.tagName.toUpperCase() == 'FORM') {
                data = el.serializeArray();
            } else if (e && e.target.tagName.toUpperCase() == 'INPUT') {
                data = el.closest('form').serializeArray();
            }

            if (condition) {
                el.trigger('rails:before');
                
                $.ajax({
                    async: async,
                    url: url,
                    data: data,
                    type: method.toUpperCase(),
                    beforeSend: function (xhr) {
                        xhr.setRequestHeader("Accept", "text/javascript")
                        el.trigger('rails:after', xhr);
                        el.trigger('rails:loading', xhr);
                    },
                    success: function (data, status, xhr) {
                        el.trigger('rails:success', [data, status, xhr]);
                        if (el.attr('data-update-success')) {
                           rails.update(el.attr('data-update-success'), data, el.attr('data-update-position')); 
                        }
                    },
                    complete: function (xhr) {
                        // enable disabled_with buttons
                        if (el[0].tagName.toUpperCase() == 'FORM') {
                          el.children('input[type="button"][data-enable-with],input[type="submit"][data-enable-with]').each(function(i, button){
                            button = $(button);
                            button.attr('value', button.attr('data-enable-with'));
                            button.removeAttr('data-enable-with');
                            button.removeAttr('disabled');
                              
                          });
                        } else {
                          el.attr('value', el.attr('data-enable-with'));
                          el.removeAttr('data-enable-with');
                          el.removeAttr('disabled');
                        }

                        el.trigger('rails:complete', xhr);
                        el.trigger('rails:loaded', xhr);
                    },
                    error: function (xhr, status, error) {
                        el.trigger('rails:failure', [xhr, status, error]);
                        if (el.attr('data-update-failure')) {
                           rails.update(el.attr('data-update-failure'), xhr.responseText, el.attr('data-update-position')); 
                        }
                    }
                });
            }
            e.preventDefault();
        }
    }

    /**
     * observe_form, and observe_field
     */
    $('script[data-observe="true"]').each(function (index, e) {
        var el          = $(e),
            observed    = $('#' + $(e).attr('data-observed'));
            frequency   = el.attr('data-frequency') ? el.attr('data-frequency') : 10,
            value       = observed[0].tagName.toUpperCase() === 'FORM' ? observed.serialize() : observed.val();

        var observe = function (observed, frequency, value, e) {
            return function () {
                var event       = new jQuery.Event('periodical'),
                    newValue    = observed[0].tagName.toUpperCase() === 'FORM' ? observed.serialize() : observed.val();
                event.target = e;

                if(value !== newValue) {
                    value = newValue;
                    $(e).trigger('rails:observe');
                    rails.remote.call(el, event);
                }
            }
        }(observed, frequency, value, e);

        setInterval(observe, frequency * 1000);
    });

    /**
     * confirm
     * make sure this event is first!
     */
    $('a[data-confirm],input[type="submit"][data-confirm],input[type="button"][data-confirm]').live('click', function(e){
        var el = $(this);

        if(!confirm(el.attr('data-confirm'))){
          return false;
        }
    });

    /**
     * periodically_call_remote
     */
    $('script[data-periodical="true"]').each(function (index, e) {
        var el          = $(e),
            frequency   = el.attr('data-frequency') ? el.attr('data-frequency') : 10;
            
        setInterval(function () {
            return function () {
                var event = new jQuery.Event('periodical');
                event.target = e;

                rails.remote.call(el, event);
            }
        }(e, el), frequency * 1000);
    });

    /**
     * disable_with
     */
    $('input[type="button"][data-disable-with],input[type="submit"][data-disable-with]').live('click', function(e){
        var el = $(this);

        el.attr('data-enable-with', el.attr('value'));
        el.attr('disabled', 'disabled');
        el.attr('value', el.attr('data-disable-with'));
    });

    /**
     * remote_form_tag, and remote_form_for
     */
    $('form[data-remote="true"]').live('submit', rails.remote);

    /**
     * link_to_remote, button_to_remote, and submit_to_remote
     */
    $('a[data-remote="true"],input[data-remote="true"],input[data-remote-submit="true"]').live('click', rails.remote);
   
    /*
     * popup
     */
    $('a[data-popup],input[type="button"][data-popup]').live('click', function(e){
        var el  = $(this),
            url = el.attr('data-url') || el.attr('href');

        e.preventDefault();

        if(el.attr('data-popup') === "true"){
          window.open(url);
        } else {
          window.open(url, el.attr('data-popup'));
        }
    });

    /**
     *
     * Rails 2.x Helper / Event Handlers
     * By default we listen to all callbacks, and status code callbacks and
     * check the element for data-<callback> attribute and eval it.
     *
     */
    rails.compat = {
        evalAttribute: function (element, attribute) {
            var el = $(element),
                attr = el.attr('data-' + attribute);
            return (attr) ? eval(attr) : true;
        }
    };

    $('form[data-remote="true"],a[data-remote="true"],input[data-remote="true"],script[data-observe="true"]')
        .live('rails:before', function (e) {
            rails.compat.evalAttribute(this, 'onbefore'); 
        })
        .live('rails:after', function (e, xhr) {
            rails.compat.evalAttribute(this, 'onafter'); 
        })
        .live('rails:loading', function (e, xhr) {
            rails.compat.evalAttribute(this, 'onloading'); 
        })
        .live('rails:loaded', function (e, xhr) {
            rails.compat.evalAttribute(this, 'onloaded'); 
        })
        .live('rails:complete', function (e, xhr) {
            rails.compat.evalAttribute(this, 'oncomplete'); 
            rails.compat.evalAttribute(this, 'on' + xhr.status); 
        })
        .live('rails:success', function (e, data, status, xhr) {
            rails.compat.evalAttribute(this, 'onsuccess'); 
        })
        .live('rails:failure', function (e, xhr, status, error) {
            rails.compat.evalAttribute(this, 'onfailure'); 
        })
        .live('rails:observe', function (e) {
            rails.compat.evalAttribute(this, 'onobserve'); 
        });
});
