/*
Trix 1.3.1
Copyright © 2020 Basecamp, LLC
http://trix-editor.org/
 */
var commonjsGlobal = typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : {};
function createCommonjsModule(fn, basedir, module) {
  return module = {
    path: basedir,
    exports: {},
    require: function(path, base) {
      return commonjsRequire(path, base === void 0 || base === null ? module.path : base);
    }
  }, fn(module, module.exports), module.exports;
}
function commonjsRequire() {
  throw new Error("Dynamic requires are not currently supported by @rollup/plugin-commonjs");
}
var trix = createCommonjsModule(function(module) {
  (function() {
  }).call(commonjsGlobal), function() {
    var t;
    window.Set == null && (window.Set = t = function() {
      function t2() {
        this.clear();
      }
      return t2.prototype.clear = function() {
        return this.values = [];
      }, t2.prototype.has = function(t3) {
        return this.values.indexOf(t3) !== -1;
      }, t2.prototype.add = function(t3) {
        return this.has(t3) || this.values.push(t3), this;
      }, t2.prototype["delete"] = function(t3) {
        var e;
        return (e = this.values.indexOf(t3)) === -1 ? false : (this.values.splice(e, 1), true);
      }, t2.prototype.forEach = function() {
        var t3;
        return (t3 = this.values).forEach.apply(t3, arguments);
      }, t2;
    }());
  }.call(commonjsGlobal), function(t) {
    function e() {
    }
    function n(t2, e2) {
      return function() {
        t2.apply(e2, arguments);
      };
    }
    function i(t2) {
      if (typeof this != "object")
        throw new TypeError("Promises must be constructed via new");
      if (typeof t2 != "function")
        throw new TypeError("not a function");
      this._state = 0, this._handled = false, this._value = void 0, this._deferreds = [], c(t2, this);
    }
    function o(t2, e2) {
      for (; t2._state === 3; )
        t2 = t2._value;
      return t2._state === 0 ? void t2._deferreds.push(e2) : (t2._handled = true, void h(function() {
        var n2 = t2._state === 1 ? e2.onFulfilled : e2.onRejected;
        if (n2 === null)
          return void (t2._state === 1 ? r : s)(e2.promise, t2._value);
        var i2;
        try {
          i2 = n2(t2._value);
        } catch (o2) {
          return void s(e2.promise, o2);
        }
        r(e2.promise, i2);
      }));
    }
    function r(t2, e2) {
      try {
        if (e2 === t2)
          throw new TypeError("A promise cannot be resolved with itself.");
        if (e2 && (typeof e2 == "object" || typeof e2 == "function")) {
          var o2 = e2.then;
          if (e2 instanceof i)
            return t2._state = 3, t2._value = e2, void a(t2);
          if (typeof o2 == "function")
            return void c(n(o2, e2), t2);
        }
        t2._state = 1, t2._value = e2, a(t2);
      } catch (r2) {
        s(t2, r2);
      }
    }
    function s(t2, e2) {
      t2._state = 2, t2._value = e2, a(t2);
    }
    function a(t2) {
      t2._state === 2 && t2._deferreds.length === 0 && setTimeout(function() {
        t2._handled || p(t2._value);
      }, 1);
      for (var e2 = 0, n2 = t2._deferreds.length; n2 > e2; e2++)
        o(t2, t2._deferreds[e2]);
      t2._deferreds = null;
    }
    function u(t2, e2, n2) {
      this.onFulfilled = typeof t2 == "function" ? t2 : null, this.onRejected = typeof e2 == "function" ? e2 : null, this.promise = n2;
    }
    function c(t2, e2) {
      var n2 = false;
      try {
        t2(function(t3) {
          n2 || (n2 = true, r(e2, t3));
        }, function(t3) {
          n2 || (n2 = true, s(e2, t3));
        });
      } catch (i2) {
        if (n2)
          return;
        n2 = true, s(e2, i2);
      }
    }
    var l = setTimeout, h = typeof setImmediate == "function" && setImmediate || function(t2) {
      l(t2, 1);
    }, p = function(t2) {
      typeof console != "undefined" && console && console.warn("Possible Unhandled Promise Rejection:", t2);
    };
    i.prototype["catch"] = function(t2) {
      return this.then(null, t2);
    }, i.prototype.then = function(t2, n2) {
      var r2 = new i(e);
      return o(this, new u(t2, n2, r2)), r2;
    }, i.all = function(t2) {
      var e2 = Array.prototype.slice.call(t2);
      return new i(function(t3, n2) {
        function i2(r3, s2) {
          try {
            if (s2 && (typeof s2 == "object" || typeof s2 == "function")) {
              var a2 = s2.then;
              if (typeof a2 == "function")
                return void a2.call(s2, function(t4) {
                  i2(r3, t4);
                }, n2);
            }
            e2[r3] = s2, --o2 === 0 && t3(e2);
          } catch (u2) {
            n2(u2);
          }
        }
        if (e2.length === 0)
          return t3([]);
        for (var o2 = e2.length, r2 = 0; r2 < e2.length; r2++)
          i2(r2, e2[r2]);
      });
    }, i.resolve = function(t2) {
      return t2 && typeof t2 == "object" && t2.constructor === i ? t2 : new i(function(e2) {
        e2(t2);
      });
    }, i.reject = function(t2) {
      return new i(function(e2, n2) {
        n2(t2);
      });
    }, i.race = function(t2) {
      return new i(function(e2, n2) {
        for (var i2 = 0, o2 = t2.length; o2 > i2; i2++)
          t2[i2].then(e2, n2);
      });
    }, i._setImmediateFn = function(t2) {
      h = t2;
    }, i._setUnhandledRejectionFn = function(t2) {
      p = t2;
    }, module.exports ? module.exports = i : t.Promise || (t.Promise = i);
  }(commonjsGlobal), function() {
    var t = typeof window.customElements == "object", e = typeof document.registerElement == "function", n = t || e;
    n || (typeof WeakMap == "undefined" && !function() {
      var t2 = Object.defineProperty, e2 = Date.now() % 1e9, n2 = function() {
        this.name = "__st" + (1e9 * Math.random() >>> 0) + (e2++ + "__");
      };
      n2.prototype = {set: function(e3, n3) {
        var i = e3[this.name];
        return i && i[0] === e3 ? i[1] = n3 : t2(e3, this.name, {value: [e3, n3], writable: true}), this;
      }, get: function(t3) {
        var e3;
        return (e3 = t3[this.name]) && e3[0] === t3 ? e3[1] : void 0;
      }, delete: function(t3) {
        var e3 = t3[this.name];
        return e3 && e3[0] === t3 ? (e3[0] = e3[1] = void 0, true) : false;
      }, has: function(t3) {
        var e3 = t3[this.name];
        return e3 ? e3[0] === t3 : false;
      }}, window.WeakMap = n2;
    }(), function(t2) {
      function e2(t3) {
        A.push(t3), b || (b = true, g(i));
      }
      function n2(t3) {
        return window.ShadowDOMPolyfill && window.ShadowDOMPolyfill.wrapIfNeeded(t3) || t3;
      }
      function i() {
        b = false;
        var t3 = A;
        A = [], t3.sort(function(t4, e4) {
          return t4.uid_ - e4.uid_;
        });
        var e3 = false;
        t3.forEach(function(t4) {
          var n3 = t4.takeRecords();
          o(t4), n3.length && (t4.callback_(n3, t4), e3 = true);
        }), e3 && i();
      }
      function o(t3) {
        t3.nodes_.forEach(function(e3) {
          var n3 = m.get(e3);
          n3 && n3.forEach(function(e4) {
            e4.observer === t3 && e4.removeTransientObservers();
          });
        });
      }
      function r(t3, e3) {
        for (var n3 = t3; n3; n3 = n3.parentNode) {
          var i2 = m.get(n3);
          if (i2)
            for (var o2 = 0; o2 < i2.length; o2++) {
              var r2 = i2[o2], s2 = r2.options;
              if (n3 === t3 || s2.subtree) {
                var a2 = e3(s2);
                a2 && r2.enqueue(a2);
              }
            }
        }
      }
      function s(t3) {
        this.callback_ = t3, this.nodes_ = [], this.records_ = [], this.uid_ = ++C;
      }
      function a(t3, e3) {
        this.type = t3, this.target = e3, this.addedNodes = [], this.removedNodes = [], this.previousSibling = null, this.nextSibling = null, this.attributeName = null, this.attributeNamespace = null, this.oldValue = null;
      }
      function u(t3) {
        var e3 = new a(t3.type, t3.target);
        return e3.addedNodes = t3.addedNodes.slice(), e3.removedNodes = t3.removedNodes.slice(), e3.previousSibling = t3.previousSibling, e3.nextSibling = t3.nextSibling, e3.attributeName = t3.attributeName, e3.attributeNamespace = t3.attributeNamespace, e3.oldValue = t3.oldValue, e3;
      }
      function c(t3, e3) {
        return x = new a(t3, e3);
      }
      function l(t3) {
        return w ? w : (w = u(x), w.oldValue = t3, w);
      }
      function h() {
        x = w = void 0;
      }
      function p(t3) {
        return t3 === w || t3 === x;
      }
      function d(t3, e3) {
        return t3 === e3 ? t3 : w && p(t3) ? w : null;
      }
      function f(t3, e3, n3) {
        this.observer = t3, this.target = e3, this.options = n3, this.transientObservedNodes = [];
      }
      if (!t2.JsMutationObserver) {
        var g, m = new WeakMap();
        if (/Trident|Edge/.test(navigator.userAgent))
          g = setTimeout;
        else if (window.setImmediate)
          g = window.setImmediate;
        else {
          var v = [], y = String(Math.random());
          window.addEventListener("message", function(t3) {
            if (t3.data === y) {
              var e3 = v;
              v = [], e3.forEach(function(t4) {
                t4();
              });
            }
          }), g = function(t3) {
            v.push(t3), window.postMessage(y, "*");
          };
        }
        var b = false, A = [], C = 0;
        s.prototype = {observe: function(t3, e3) {
          if (t3 = n2(t3), !e3.childList && !e3.attributes && !e3.characterData || e3.attributeOldValue && !e3.attributes || e3.attributeFilter && e3.attributeFilter.length && !e3.attributes || e3.characterDataOldValue && !e3.characterData)
            throw new SyntaxError();
          var i2 = m.get(t3);
          i2 || m.set(t3, i2 = []);
          for (var o2, r2 = 0; r2 < i2.length; r2++)
            if (i2[r2].observer === this) {
              o2 = i2[r2], o2.removeListeners(), o2.options = e3;
              break;
            }
          o2 || (o2 = new f(this, t3, e3), i2.push(o2), this.nodes_.push(t3)), o2.addListeners();
        }, disconnect: function() {
          this.nodes_.forEach(function(t3) {
            for (var e3 = m.get(t3), n3 = 0; n3 < e3.length; n3++) {
              var i2 = e3[n3];
              if (i2.observer === this) {
                i2.removeListeners(), e3.splice(n3, 1);
                break;
              }
            }
          }, this), this.records_ = [];
        }, takeRecords: function() {
          var t3 = this.records_;
          return this.records_ = [], t3;
        }};
        var x, w;
        f.prototype = {enqueue: function(t3) {
          var n3 = this.observer.records_, i2 = n3.length;
          if (n3.length > 0) {
            var o2 = n3[i2 - 1], r2 = d(o2, t3);
            if (r2)
              return void (n3[i2 - 1] = r2);
          } else
            e2(this.observer);
          n3[i2] = t3;
        }, addListeners: function() {
          this.addListeners_(this.target);
        }, addListeners_: function(t3) {
          var e3 = this.options;
          e3.attributes && t3.addEventListener("DOMAttrModified", this, true), e3.characterData && t3.addEventListener("DOMCharacterDataModified", this, true), e3.childList && t3.addEventListener("DOMNodeInserted", this, true), (e3.childList || e3.subtree) && t3.addEventListener("DOMNodeRemoved", this, true);
        }, removeListeners: function() {
          this.removeListeners_(this.target);
        }, removeListeners_: function(t3) {
          var e3 = this.options;
          e3.attributes && t3.removeEventListener("DOMAttrModified", this, true), e3.characterData && t3.removeEventListener("DOMCharacterDataModified", this, true), e3.childList && t3.removeEventListener("DOMNodeInserted", this, true), (e3.childList || e3.subtree) && t3.removeEventListener("DOMNodeRemoved", this, true);
        }, addTransientObserver: function(t3) {
          if (t3 !== this.target) {
            this.addListeners_(t3), this.transientObservedNodes.push(t3);
            var e3 = m.get(t3);
            e3 || m.set(t3, e3 = []), e3.push(this);
          }
        }, removeTransientObservers: function() {
          var t3 = this.transientObservedNodes;
          this.transientObservedNodes = [], t3.forEach(function(t4) {
            this.removeListeners_(t4);
            for (var e3 = m.get(t4), n3 = 0; n3 < e3.length; n3++)
              if (e3[n3] === this) {
                e3.splice(n3, 1);
                break;
              }
          }, this);
        }, handleEvent: function(t3) {
          switch (t3.stopImmediatePropagation(), t3.type) {
            case "DOMAttrModified":
              var e3 = t3.attrName, n3 = t3.relatedNode.namespaceURI, i2 = t3.target, o2 = new c("attributes", i2);
              o2.attributeName = e3, o2.attributeNamespace = n3;
              var s2 = t3.attrChange === MutationEvent.ADDITION ? null : t3.prevValue;
              r(i2, function(t4) {
                return !t4.attributes || t4.attributeFilter && t4.attributeFilter.length && t4.attributeFilter.indexOf(e3) === -1 && t4.attributeFilter.indexOf(n3) === -1 ? void 0 : t4.attributeOldValue ? l(s2) : o2;
              });
              break;
            case "DOMCharacterDataModified":
              var i2 = t3.target, o2 = c("characterData", i2), s2 = t3.prevValue;
              r(i2, function(t4) {
                return t4.characterData ? t4.characterDataOldValue ? l(s2) : o2 : void 0;
              });
              break;
            case "DOMNodeRemoved":
              this.addTransientObserver(t3.target);
            case "DOMNodeInserted":
              var a2, u2, p2 = t3.target;
              t3.type === "DOMNodeInserted" ? (a2 = [p2], u2 = []) : (a2 = [], u2 = [p2]);
              var d2 = p2.previousSibling, f2 = p2.nextSibling, o2 = c("childList", t3.target.parentNode);
              o2.addedNodes = a2, o2.removedNodes = u2, o2.previousSibling = d2, o2.nextSibling = f2, r(t3.relatedNode, function(t4) {
                return t4.childList ? o2 : void 0;
              });
          }
          h();
        }}, t2.JsMutationObserver = s, t2.MutationObserver || (t2.MutationObserver = s, s._isPolyfilled = true);
      }
    }(self), function() {
      if (!window.performance || !window.performance.now) {
        var t2 = Date.now();
        window.performance = {now: function() {
          return Date.now() - t2;
        }};
      }
      window.requestAnimationFrame || (window.requestAnimationFrame = function() {
        var t3 = window.webkitRequestAnimationFrame || window.mozRequestAnimationFrame;
        return t3 ? function(e3) {
          return t3(function() {
            e3(performance.now());
          });
        } : function(t4) {
          return window.setTimeout(t4, 1e3 / 60);
        };
      }()), window.cancelAnimationFrame || (window.cancelAnimationFrame = function() {
        return window.webkitCancelAnimationFrame || window.mozCancelAnimationFrame || function(t3) {
          clearTimeout(t3);
        };
      }());
      var e2 = function() {
        var t3 = document.createEvent("Event");
        return t3.initEvent("foo", true, true), t3.preventDefault(), t3.defaultPrevented;
      }();
      if (!e2) {
        var n2 = Event.prototype.preventDefault;
        Event.prototype.preventDefault = function() {
          this.cancelable && (n2.call(this), Object.defineProperty(this, "defaultPrevented", {get: function() {
            return true;
          }, configurable: true}));
        };
      }
      var i = /Trident/.test(navigator.userAgent);
      if ((!window.CustomEvent || i && typeof window.CustomEvent != "function") && (window.CustomEvent = function(t3, e3) {
        e3 = e3 || {};
        var n3 = document.createEvent("CustomEvent");
        return n3.initCustomEvent(t3, Boolean(e3.bubbles), Boolean(e3.cancelable), e3.detail), n3;
      }, window.CustomEvent.prototype = window.Event.prototype), !window.Event || i && typeof window.Event != "function") {
        var o = window.Event;
        window.Event = function(t3, e3) {
          e3 = e3 || {};
          var n3 = document.createEvent("Event");
          return n3.initEvent(t3, Boolean(e3.bubbles), Boolean(e3.cancelable)), n3;
        }, window.Event.prototype = o.prototype;
      }
    }(), window.CustomElements = window.CustomElements || {flags: {}}, function(t2) {
      var e2 = t2.flags, n2 = [], i = function(t3) {
        n2.push(t3);
      }, o = function() {
        n2.forEach(function(e3) {
          e3(t2);
        });
      };
      t2.addModule = i, t2.initializeModules = o, t2.hasNative = Boolean(document.registerElement), t2.isIE = /Trident/.test(navigator.userAgent), t2.useNative = !e2.register && t2.hasNative && !window.ShadowDOMPolyfill && (!window.HTMLImports || window.HTMLImports.useNative);
    }(window.CustomElements), window.CustomElements.addModule(function(t2) {
      function e2(t3, e3) {
        n2(t3, function(t4) {
          return e3(t4) ? true : void i(t4, e3);
        }), i(t3, e3);
      }
      function n2(t3, e3, i2) {
        var o2 = t3.firstElementChild;
        if (!o2)
          for (o2 = t3.firstChild; o2 && o2.nodeType !== Node.ELEMENT_NODE; )
            o2 = o2.nextSibling;
        for (; o2; )
          e3(o2, i2) !== true && n2(o2, e3, i2), o2 = o2.nextElementSibling;
        return null;
      }
      function i(t3, n3) {
        for (var i2 = t3.shadowRoot; i2; )
          e2(i2, n3), i2 = i2.olderShadowRoot;
      }
      function o(t3, e3) {
        r(t3, e3, []);
      }
      function r(t3, e3, n3) {
        if (t3 = window.wrap(t3), !(n3.indexOf(t3) >= 0)) {
          n3.push(t3);
          for (var i2, o2 = t3.querySelectorAll("link[rel=" + s + "]"), a = 0, u = o2.length; u > a && (i2 = o2[a]); a++)
            i2.import && r(i2.import, e3, n3);
          e3(t3);
        }
      }
      var s = window.HTMLImports ? window.HTMLImports.IMPORT_LINK_TYPE : "none";
      t2.forDocumentTree = o, t2.forSubtree = e2;
    }), window.CustomElements.addModule(function(t2) {
      function e2(t3, e3) {
        return n2(t3, e3) || i(t3, e3);
      }
      function n2(e3, n3) {
        return t2.upgrade(e3, n3) ? true : void (n3 && s(e3));
      }
      function i(t3, e3) {
        b(t3, function(t4) {
          return n2(t4, e3) ? true : void 0;
        });
      }
      function o(t3) {
        w.push(t3), x || (x = true, setTimeout(r));
      }
      function r() {
        x = false;
        for (var t3, e3 = w, n3 = 0, i2 = e3.length; i2 > n3 && (t3 = e3[n3]); n3++)
          t3();
        w = [];
      }
      function s(t3) {
        C ? o(function() {
          a(t3);
        }) : a(t3);
      }
      function a(t3) {
        t3.__upgraded__ && !t3.__attached && (t3.__attached = true, t3.attachedCallback && t3.attachedCallback());
      }
      function u(t3) {
        c(t3), b(t3, function(t4) {
          c(t4);
        });
      }
      function c(t3) {
        C ? o(function() {
          l(t3);
        }) : l(t3);
      }
      function l(t3) {
        t3.__upgraded__ && t3.__attached && (t3.__attached = false, t3.detachedCallback && t3.detachedCallback());
      }
      function h(t3) {
        for (var e3 = t3, n3 = window.wrap(document); e3; ) {
          if (e3 == n3)
            return true;
          e3 = e3.parentNode || e3.nodeType === Node.DOCUMENT_FRAGMENT_NODE && e3.host;
        }
      }
      function p(t3) {
        if (t3.shadowRoot && !t3.shadowRoot.__watched) {
          y.dom && console.log("watching shadow-root for: ", t3.localName);
          for (var e3 = t3.shadowRoot; e3; )
            g(e3), e3 = e3.olderShadowRoot;
        }
      }
      function d(t3, n3) {
        if (y.dom) {
          var i2 = n3[0];
          if (i2 && i2.type === "childList" && i2.addedNodes && i2.addedNodes) {
            for (var o2 = i2.addedNodes[0]; o2 && o2 !== document && !o2.host; )
              o2 = o2.parentNode;
            var r2 = o2 && (o2.URL || o2._URL || o2.host && o2.host.localName) || "";
            r2 = r2.split("/?").shift().split("/").pop();
          }
          console.group("mutations (%d) [%s]", n3.length, r2 || "");
        }
        var s2 = h(t3);
        n3.forEach(function(t4) {
          t4.type === "childList" && (E(t4.addedNodes, function(t5) {
            t5.localName && e2(t5, s2);
          }), E(t4.removedNodes, function(t5) {
            t5.localName && u(t5);
          }));
        }), y.dom && console.groupEnd();
      }
      function f(t3) {
        for (t3 = window.wrap(t3), t3 || (t3 = window.wrap(document)); t3.parentNode; )
          t3 = t3.parentNode;
        var e3 = t3.__observer;
        e3 && (d(t3, e3.takeRecords()), r());
      }
      function g(t3) {
        if (!t3.__observer) {
          var e3 = new MutationObserver(d.bind(this, t3));
          e3.observe(t3, {childList: true, subtree: true}), t3.__observer = e3;
        }
      }
      function m(t3) {
        t3 = window.wrap(t3), y.dom && console.group("upgradeDocument: ", t3.baseURI.split("/").pop());
        var n3 = t3 === window.wrap(document);
        e2(t3, n3), g(t3), y.dom && console.groupEnd();
      }
      function v(t3) {
        A(t3, m);
      }
      var y = t2.flags, b = t2.forSubtree, A = t2.forDocumentTree, C = window.MutationObserver._isPolyfilled && y["throttle-attached"];
      t2.hasPolyfillMutations = C, t2.hasThrottledAttached = C;
      var x = false, w = [], E = Array.prototype.forEach.call.bind(Array.prototype.forEach), S = Element.prototype.createShadowRoot;
      S && (Element.prototype.createShadowRoot = function() {
        var t3 = S.call(this);
        return window.CustomElements.watchShadow(this), t3;
      }), t2.watchShadow = p, t2.upgradeDocumentTree = v, t2.upgradeDocument = m, t2.upgradeSubtree = i, t2.upgradeAll = e2, t2.attached = s, t2.takeRecords = f;
    }), window.CustomElements.addModule(function(t2) {
      function e2(e3, i2) {
        if (e3.localName === "template" && window.HTMLTemplateElement && HTMLTemplateElement.decorate && HTMLTemplateElement.decorate(e3), !e3.__upgraded__ && e3.nodeType === Node.ELEMENT_NODE) {
          var o2 = e3.getAttribute("is"), r2 = t2.getRegisteredDefinition(e3.localName) || t2.getRegisteredDefinition(o2);
          if (r2 && (o2 && r2.tag == e3.localName || !o2 && !r2.extends))
            return n2(e3, r2, i2);
        }
      }
      function n2(e3, n3, o2) {
        return s.upgrade && console.group("upgrade:", e3.localName), n3.is && e3.setAttribute("is", n3.is), i(e3, n3), e3.__upgraded__ = true, r(e3), o2 && t2.attached(e3), t2.upgradeSubtree(e3, o2), s.upgrade && console.groupEnd(), e3;
      }
      function i(t3, e3) {
        Object.__proto__ ? t3.__proto__ = e3.prototype : (o(t3, e3.prototype, e3.native), t3.__proto__ = e3.prototype);
      }
      function o(t3, e3, n3) {
        for (var i2 = {}, o2 = e3; o2 !== n3 && o2 !== HTMLElement.prototype; ) {
          for (var r2, s2 = Object.getOwnPropertyNames(o2), a = 0; r2 = s2[a]; a++)
            i2[r2] || (Object.defineProperty(t3, r2, Object.getOwnPropertyDescriptor(o2, r2)), i2[r2] = 1);
          o2 = Object.getPrototypeOf(o2);
        }
      }
      function r(t3) {
        t3.createdCallback && t3.createdCallback();
      }
      var s = t2.flags;
      t2.upgrade = e2, t2.upgradeWithDefinition = n2, t2.implementPrototype = i;
    }), window.CustomElements.addModule(function(t2) {
      function e2(e3, i2) {
        var u2 = i2 || {};
        if (!e3)
          throw new Error("document.registerElement: first argument `name` must not be empty");
        if (e3.indexOf("-") < 0)
          throw new Error("document.registerElement: first argument ('name') must contain a dash ('-'). Argument provided was '" + String(e3) + "'.");
        if (o(e3))
          throw new Error("Failed to execute 'registerElement' on 'Document': Registration failed for type '" + String(e3) + "'. The type name is invalid.");
        if (c(e3))
          throw new Error("DuplicateDefinitionError: a type with name '" + String(e3) + "' is already registered");
        return u2.prototype || (u2.prototype = Object.create(HTMLElement.prototype)), u2.__name = e3.toLowerCase(), u2.extends && (u2.extends = u2.extends.toLowerCase()), u2.lifecycle = u2.lifecycle || {}, u2.ancestry = r(u2.extends), s(u2), a(u2), n2(u2.prototype), l(u2.__name, u2), u2.ctor = h(u2), u2.ctor.prototype = u2.prototype, u2.prototype.constructor = u2.ctor, t2.ready && m(document), u2.ctor;
      }
      function n2(t3) {
        if (!t3.setAttribute._polyfilled) {
          var e3 = t3.setAttribute;
          t3.setAttribute = function(t4, n4) {
            i.call(this, t4, n4, e3);
          };
          var n3 = t3.removeAttribute;
          t3.removeAttribute = function(t4) {
            i.call(this, t4, null, n3);
          }, t3.setAttribute._polyfilled = true;
        }
      }
      function i(t3, e3, n3) {
        t3 = t3.toLowerCase();
        var i2 = this.getAttribute(t3);
        n3.apply(this, arguments);
        var o2 = this.getAttribute(t3);
        this.attributeChangedCallback && o2 !== i2 && this.attributeChangedCallback(t3, i2, o2);
      }
      function o(t3) {
        for (var e3 = 0; e3 < C.length; e3++)
          if (t3 === C[e3])
            return true;
      }
      function r(t3) {
        var e3 = c(t3);
        return e3 ? r(e3.extends).concat([e3]) : [];
      }
      function s(t3) {
        for (var e3, n3 = t3.extends, i2 = 0; e3 = t3.ancestry[i2]; i2++)
          n3 = e3.is && e3.tag;
        t3.tag = n3 || t3.__name, n3 && (t3.is = t3.__name);
      }
      function a(t3) {
        if (!Object.__proto__) {
          var e3 = HTMLElement.prototype;
          if (t3.is) {
            var n3 = document.createElement(t3.tag);
            e3 = Object.getPrototypeOf(n3);
          }
          for (var i2, o2 = t3.prototype, r2 = false; o2; )
            o2 == e3 && (r2 = true), i2 = Object.getPrototypeOf(o2), i2 && (o2.__proto__ = i2), o2 = i2;
          r2 || console.warn(t3.tag + " prototype not found in prototype chain for " + t3.is), t3.native = e3;
        }
      }
      function u(t3) {
        return y(E(t3.tag), t3);
      }
      function c(t3) {
        return t3 ? x[t3.toLowerCase()] : void 0;
      }
      function l(t3, e3) {
        x[t3] = e3;
      }
      function h(t3) {
        return function() {
          return u(t3);
        };
      }
      function p(t3, e3, n3) {
        return t3 === w ? d(e3, n3) : S(t3, e3);
      }
      function d(t3, e3) {
        t3 && (t3 = t3.toLowerCase()), e3 && (e3 = e3.toLowerCase());
        var n3 = c(e3 || t3);
        if (n3) {
          if (t3 == n3.tag && e3 == n3.is)
            return new n3.ctor();
          if (!e3 && !n3.is)
            return new n3.ctor();
        }
        var i2;
        return e3 ? (i2 = d(t3), i2.setAttribute("is", e3), i2) : (i2 = E(t3), t3.indexOf("-") >= 0 && b(i2, HTMLElement), i2);
      }
      function f(t3, e3) {
        var n3 = t3[e3];
        t3[e3] = function() {
          var t4 = n3.apply(this, arguments);
          return v(t4), t4;
        };
      }
      var g, m = (t2.isIE, t2.upgradeDocumentTree), v = t2.upgradeAll, y = t2.upgradeWithDefinition, b = t2.implementPrototype, A = t2.useNative, C = ["annotation-xml", "color-profile", "font-face", "font-face-src", "font-face-uri", "font-face-format", "font-face-name", "missing-glyph"], x = {}, w = "http://www.w3.org/1999/xhtml", E = document.createElement.bind(document), S = document.createElementNS.bind(document);
      g = Object.__proto__ || A ? function(t3, e3) {
        return t3 instanceof e3;
      } : function(t3, e3) {
        if (t3 instanceof e3)
          return true;
        for (var n3 = t3; n3; ) {
          if (n3 === e3.prototype)
            return true;
          n3 = n3.__proto__;
        }
        return false;
      }, f(Node.prototype, "cloneNode"), f(document, "importNode"), document.registerElement = e2, document.createElement = d, document.createElementNS = p, t2.registry = x, t2.instanceof = g, t2.reservedTagList = C, t2.getRegisteredDefinition = c, document.register = document.registerElement;
    }), function(t2) {
      function e2() {
        r(window.wrap(document)), window.CustomElements.ready = true;
        var t3 = window.requestAnimationFrame || function(t4) {
          setTimeout(t4, 16);
        };
        t3(function() {
          setTimeout(function() {
            window.CustomElements.readyTime = Date.now(), window.HTMLImports && (window.CustomElements.elapsed = window.CustomElements.readyTime - window.HTMLImports.readyTime), document.dispatchEvent(new CustomEvent("WebComponentsReady", {bubbles: true}));
          });
        });
      }
      var n2 = t2.useNative, i = t2.initializeModules;
      if (t2.isIE, n2) {
        var o = function() {
        };
        t2.watchShadow = o, t2.upgrade = o, t2.upgradeAll = o, t2.upgradeDocumentTree = o, t2.upgradeSubtree = o, t2.takeRecords = o, t2.instanceof = function(t3, e3) {
          return t3 instanceof e3;
        };
      } else
        i();
      var r = t2.upgradeDocumentTree, s = t2.upgradeDocument;
      if (window.wrap || (window.ShadowDOMPolyfill ? (window.wrap = window.ShadowDOMPolyfill.wrapIfNeeded, window.unwrap = window.ShadowDOMPolyfill.unwrapIfNeeded) : window.wrap = window.unwrap = function(t3) {
        return t3;
      }), window.HTMLImports && (window.HTMLImports.__importsParsingHook = function(t3) {
        t3.import && s(wrap(t3.import));
      }), document.readyState === "complete" || t2.flags.eager)
        e2();
      else if (document.readyState !== "interactive" || window.attachEvent || window.HTMLImports && !window.HTMLImports.ready) {
        var a = window.HTMLImports && !window.HTMLImports.ready ? "HTMLImportsLoaded" : "DOMContentLoaded";
        window.addEventListener(a, e2);
      } else
        e2();
    }(window.CustomElements));
  }.call(commonjsGlobal), function() {
  }.call(commonjsGlobal), function() {
    var t = this;
    (function() {
      (function() {
        this.Trix = {VERSION: "1.3.1", ZERO_WIDTH_SPACE: "\uFEFF", NON_BREAKING_SPACE: "\xA0", OBJECT_REPLACEMENT_CHARACTER: "\uFFFC", browser: {composesExistingText: /Android.*Chrome/.test(navigator.userAgent), forcesObjectResizing: /Trident.*rv:11/.test(navigator.userAgent), supportsInputEvents: function() {
          var t2, e2, n, i;
          if (typeof InputEvent == "undefined")
            return false;
          for (i = ["data", "getTargetRanges", "inputType"], t2 = 0, e2 = i.length; e2 > t2; t2++)
            if (n = i[t2], !(n in InputEvent.prototype))
              return false;
          return true;
        }()}, config: {}};
      }).call(this);
    }).call(t);
    var e = t.Trix;
    (function() {
      (function() {
        e.BasicObject = function() {
          function t2() {
          }
          var e2, n, i;
          return t2.proxyMethod = function(t3) {
            var i2, o, r, s, a;
            return r = n(t3), i2 = r.name, s = r.toMethod, a = r.toProperty, o = r.optional, this.prototype[i2] = function() {
              var t4, n2;
              return t4 = s != null ? o ? typeof this[s] == "function" ? this[s]() : void 0 : this[s]() : a != null ? this[a] : void 0, o ? (n2 = t4 != null ? t4[i2] : void 0, n2 != null ? e2.call(n2, t4, arguments) : void 0) : (n2 = t4[i2], e2.call(n2, t4, arguments));
            };
          }, n = function(t3) {
            var e3, n2;
            if (!(n2 = t3.match(i)))
              throw new Error("can't parse @proxyMethod expression: " + t3);
            return e3 = {name: n2[4]}, n2[2] != null ? e3.toMethod = n2[1] : e3.toProperty = n2[1], n2[3] != null && (e3.optional = true), e3;
          }, e2 = Function.prototype.apply, i = /^(.+?)(\(\))?(\?)?\.(.+?)$/, t2;
        }();
      }).call(this), function() {
        var t2 = function(t3, e2) {
          function i() {
            this.constructor = t3;
          }
          for (var o in e2)
            n.call(e2, o) && (t3[o] = e2[o]);
          return i.prototype = e2.prototype, t3.prototype = new i(), t3.__super__ = e2.prototype, t3;
        }, n = {}.hasOwnProperty;
        e.Object = function(n2) {
          function i() {
            this.id = ++o;
          }
          var o;
          return t2(i, n2), o = 0, i.fromJSONString = function(t3) {
            return this.fromJSON(JSON.parse(t3));
          }, i.prototype.hasSameConstructorAs = function(t3) {
            return this.constructor === (t3 != null ? t3.constructor : void 0);
          }, i.prototype.isEqualTo = function(t3) {
            return this === t3;
          }, i.prototype.inspect = function() {
            var t3, e2, n3;
            return t3 = function() {
              var t4, i2, o2;
              i2 = (t4 = this.contentsForInspection()) != null ? t4 : {}, o2 = [];
              for (e2 in i2)
                n3 = i2[e2], o2.push(e2 + "=" + n3);
              return o2;
            }.call(this), "#<" + this.constructor.name + ":" + this.id + (t3.length ? " " + t3.join(", ") : "") + ">";
          }, i.prototype.contentsForInspection = function() {
          }, i.prototype.toJSONString = function() {
            return JSON.stringify(this);
          }, i.prototype.toUTF16String = function() {
            return e.UTF16String.box(this);
          }, i.prototype.getCacheKey = function() {
            return this.id.toString();
          }, i;
        }(e.BasicObject);
      }.call(this), function() {
        e.extend = function(t2) {
          var e2, n;
          for (e2 in t2)
            n = t2[e2], this[e2] = n;
          return this;
        };
      }.call(this), function() {
        e.extend({defer: function(t2) {
          return setTimeout(t2, 1);
        }});
      }.call(this), function() {
        var t2, n;
        e.extend({normalizeSpaces: function(t3) {
          return t3.replace(RegExp("" + e.ZERO_WIDTH_SPACE, "g"), "").replace(RegExp("" + e.NON_BREAKING_SPACE, "g"), " ");
        }, normalizeNewlines: function(t3) {
          return t3.replace(/\r\n/g, "\n");
        }, breakableWhitespacePattern: RegExp("[^\\S" + e.NON_BREAKING_SPACE + "]"), squishBreakableWhitespace: function(t3) {
          return t3.replace(RegExp("" + e.breakableWhitespacePattern.source, "g"), " ").replace(/\ {2,}/g, " ");
        }, summarizeStringChange: function(t3, i) {
          var o, r, s, a;
          return t3 = e.UTF16String.box(t3), i = e.UTF16String.box(i), i.length < t3.length ? (r = n(t3, i), a = r[0], o = r[1]) : (s = n(i, t3), o = s[0], a = s[1]), {added: o, removed: a};
        }}), n = function(n2, i) {
          var o, r, s, a, u;
          return n2.isEqualTo(i) ? ["", ""] : (r = t2(n2, i), a = r.utf16String.length, s = a ? (u = r.offset, o = n2.codepoints.slice(0, u).concat(n2.codepoints.slice(u + a)), t2(i, e.UTF16String.fromCodepoints(o))) : t2(i, n2), [r.utf16String.toString(), s.utf16String.toString()]);
        }, t2 = function(t3, e2) {
          var n2, i, o;
          for (n2 = 0, i = t3.length, o = e2.length; i > n2 && t3.charAt(n2).isEqualTo(e2.charAt(n2)); )
            n2++;
          for (; i > n2 + 1 && t3.charAt(i - 1).isEqualTo(e2.charAt(o - 1)); )
            i--, o--;
          return {utf16String: t3.slice(n2, i), offset: n2};
        };
      }.call(this), function() {
        e.extend({copyObject: function(t2) {
          var e2, n, i;
          t2 == null && (t2 = {}), n = {};
          for (e2 in t2)
            i = t2[e2], n[e2] = i;
          return n;
        }, objectsAreEqual: function(t2, e2) {
          var n, i;
          if (t2 == null && (t2 = {}), e2 == null && (e2 = {}), Object.keys(t2).length !== Object.keys(e2).length)
            return false;
          for (n in t2)
            if (i = t2[n], i !== e2[n])
              return false;
          return true;
        }});
      }.call(this), function() {
        var t2 = [].slice;
        e.extend({arraysAreEqual: function(t3, e2) {
          var n, i, o, r;
          if (t3 == null && (t3 = []), e2 == null && (e2 = []), t3.length !== e2.length)
            return false;
          for (i = n = 0, o = t3.length; o > n; i = ++n)
            if (r = t3[i], r !== e2[i])
              return false;
          return true;
        }, arrayStartsWith: function(t3, n) {
          return t3 == null && (t3 = []), n == null && (n = []), e.arraysAreEqual(t3.slice(0, n.length), n);
        }, spliceArray: function() {
          var e2, n, i;
          return n = arguments[0], e2 = 2 <= arguments.length ? t2.call(arguments, 1) : [], i = n.slice(0), i.splice.apply(i, e2), i;
        }, summarizeArrayChange: function(t3, e2) {
          var n, i, o, r, s, a, u, c, l, h, p;
          for (t3 == null && (t3 = []), e2 == null && (e2 = []), n = [], h = [], o = new Set(), r = 0, u = t3.length; u > r; r++)
            p = t3[r], o.add(p);
          for (i = new Set(), s = 0, c = e2.length; c > s; s++)
            p = e2[s], i.add(p), o.has(p) || n.push(p);
          for (a = 0, l = t3.length; l > a; a++)
            p = t3[a], i.has(p) || h.push(p);
          return {added: n, removed: h};
        }});
      }.call(this), function() {
        var t2, n, i, o;
        t2 = null, n = null, o = null, i = null, e.extend({getAllAttributeNames: function() {
          return t2 != null ? t2 : t2 = e.getTextAttributeNames().concat(e.getBlockAttributeNames());
        }, getBlockConfig: function(t3) {
          return e.config.blockAttributes[t3];
        }, getBlockAttributeNames: function() {
          return n != null ? n : n = Object.keys(e.config.blockAttributes);
        }, getTextConfig: function(t3) {
          return e.config.textAttributes[t3];
        }, getTextAttributeNames: function() {
          return o != null ? o : o = Object.keys(e.config.textAttributes);
        }, getListAttributeNames: function() {
          var t3, n2;
          return i != null ? i : i = function() {
            var i2, o2;
            i2 = e.config.blockAttributes, o2 = [];
            for (t3 in i2)
              n2 = i2[t3].listAttribute, n2 != null && o2.push(n2);
            return o2;
          }();
        }});
      }.call(this), function() {
        var t2, n, i, o, r, s = [].indexOf || function(t3) {
          for (var e2 = 0, n2 = this.length; n2 > e2; e2++)
            if (e2 in this && this[e2] === t3)
              return e2;
          return -1;
        };
        t2 = document.documentElement, n = (i = (o = (r = t2.matchesSelector) != null ? r : t2.webkitMatchesSelector) != null ? o : t2.msMatchesSelector) != null ? i : t2.mozMatchesSelector, e.extend({handleEvent: function(n2, i2) {
          var r2, s2, a, u, c, l, h, p, d, f, g;
          return h = i2 != null ? i2 : {}, c = h.onElement, u = h.matchingSelector, g = h.withCallback, a = h.inPhase, l = h.preventDefault, d = h.times, r2 = c != null ? c : t2, p = u, f = a === "capturing", s2 = function(t3) {
            var n3;
            return d != null && --d === 0 && s2.destroy(), n3 = e.findClosestElementFromNode(t3.target, {matchingSelector: p}), n3 != null && (g != null && g.call(n3, t3, n3), l) ? t3.preventDefault() : void 0;
          }, s2.destroy = function() {
            return r2.removeEventListener(n2, s2, f);
          }, r2.addEventListener(n2, s2, f), s2;
        }, handleEventOnce: function(t3, n2) {
          return n2 == null && (n2 = {}), n2.times = 1, e.handleEvent(t3, n2);
        }, triggerEvent: function(n2, i2) {
          var o2, r2, s2, a, u, c, l;
          return l = i2 != null ? i2 : {}, c = l.onElement, r2 = l.bubbles, s2 = l.cancelable, o2 = l.attributes, a = c != null ? c : t2, r2 = r2 !== false, s2 = s2 !== false, u = document.createEvent("Events"), u.initEvent(n2, r2, s2), o2 != null && e.extend.call(u, o2), a.dispatchEvent(u);
        }, elementMatchesSelector: function(t3, e2) {
          return (t3 != null ? t3.nodeType : void 0) === 1 ? n.call(t3, e2) : void 0;
        }, findClosestElementFromNode: function(t3, n2) {
          var i2, o2, r2;
          for (o2 = n2 != null ? n2 : {}, i2 = o2.matchingSelector, r2 = o2.untilNode; t3 != null && t3.nodeType !== Node.ELEMENT_NODE; )
            t3 = t3.parentNode;
          if (t3 != null) {
            if (i2 == null)
              return t3;
            if (t3.closest && r2 == null)
              return t3.closest(i2);
            for (; t3 && t3 !== r2; ) {
              if (e.elementMatchesSelector(t3, i2))
                return t3;
              t3 = t3.parentNode;
            }
          }
        }, findInnerElement: function(t3) {
          for (; t3 != null ? t3.firstElementChild : void 0; )
            t3 = t3.firstElementChild;
          return t3;
        }, innerElementIsActive: function(t3) {
          return document.activeElement !== t3 && e.elementContainsNode(t3, document.activeElement);
        }, elementContainsNode: function(t3, e2) {
          if (t3 && e2)
            for (; e2; ) {
              if (e2 === t3)
                return true;
              e2 = e2.parentNode;
            }
        }, findNodeFromContainerAndOffset: function(t3, e2) {
          var n2;
          if (t3)
            return t3.nodeType === Node.TEXT_NODE ? t3 : e2 === 0 ? (n2 = t3.firstChild) != null ? n2 : t3 : t3.childNodes.item(e2 - 1);
        }, findElementFromContainerAndOffset: function(t3, n2) {
          var i2;
          return i2 = e.findNodeFromContainerAndOffset(t3, n2), e.findClosestElementFromNode(i2);
        }, findChildIndexOfNode: function(t3) {
          var e2;
          if (t3 != null ? t3.parentNode : void 0) {
            for (e2 = 0; t3 = t3.previousSibling; )
              e2++;
            return e2;
          }
        }, removeNode: function(t3) {
          var e2;
          return t3 != null && (e2 = t3.parentNode) != null ? e2.removeChild(t3) : void 0;
        }, walkTree: function(t3, e2) {
          var n2, i2, o2, r2, s2;
          return o2 = e2 != null ? e2 : {}, i2 = o2.onlyNodesOfType, r2 = o2.usingFilter, n2 = o2.expandEntityReferences, s2 = function() {
            switch (i2) {
              case "element":
                return NodeFilter.SHOW_ELEMENT;
              case "text":
                return NodeFilter.SHOW_TEXT;
              case "comment":
                return NodeFilter.SHOW_COMMENT;
              default:
                return NodeFilter.SHOW_ALL;
            }
          }(), document.createTreeWalker(t3, s2, r2 != null ? r2 : null, n2 === true);
        }, tagName: function(t3) {
          var e2;
          return t3 != null && (e2 = t3.tagName) != null ? e2.toLowerCase() : void 0;
        }, makeElement: function(t3, e2) {
          var n2, i2, o2, r2, s2, a, u, c, l, h, p, d, f, g;
          if (e2 == null && (e2 = {}), typeof t3 == "object" ? (e2 = t3, t3 = e2.tagName) : e2 = {attributes: e2}, o2 = document.createElement(t3), e2.editable != null && (e2.attributes == null && (e2.attributes = {}), e2.attributes.contenteditable = e2.editable), e2.attributes) {
            l = e2.attributes;
            for (a in l)
              g = l[a], o2.setAttribute(a, g);
          }
          if (e2.style) {
            h = e2.style;
            for (a in h)
              g = h[a], o2.style[a] = g;
          }
          if (e2.data) {
            p = e2.data;
            for (a in p)
              g = p[a], o2.dataset[a] = g;
          }
          if (e2.className)
            for (d = e2.className.split(" "), r2 = 0, u = d.length; u > r2; r2++)
              i2 = d[r2], o2.classList.add(i2);
          if (e2.textContent && (o2.textContent = e2.textContent), e2.childNodes)
            for (f = [].concat(e2.childNodes), s2 = 0, c = f.length; c > s2; s2++)
              n2 = f[s2], o2.appendChild(n2);
          return o2;
        }, getBlockTagNames: function() {
          var t3, n2;
          return e.blockTagNames != null ? e.blockTagNames : e.blockTagNames = function() {
            var i2, o2;
            i2 = e.config.blockAttributes, o2 = [];
            for (t3 in i2)
              n2 = i2[t3].tagName, n2 && o2.push(n2);
            return o2;
          }();
        }, nodeIsBlockContainer: function(t3) {
          return e.nodeIsBlockStartComment(t3 != null ? t3.firstChild : void 0);
        }, nodeProbablyIsBlockContainer: function(t3) {
          var n2, i2;
          return n2 = e.tagName(t3), s.call(e.getBlockTagNames(), n2) >= 0 && (i2 = e.tagName(t3.firstChild), s.call(e.getBlockTagNames(), i2) < 0);
        }, nodeIsBlockStart: function(t3, n2) {
          var i2;
          return i2 = (n2 != null ? n2 : {strict: true}).strict, i2 ? e.nodeIsBlockStartComment(t3) : e.nodeIsBlockStartComment(t3) || !e.nodeIsBlockStartComment(t3.firstChild) && e.nodeProbablyIsBlockContainer(t3);
        }, nodeIsBlockStartComment: function(t3) {
          return e.nodeIsCommentNode(t3) && (t3 != null ? t3.data : void 0) === "block";
        }, nodeIsCommentNode: function(t3) {
          return (t3 != null ? t3.nodeType : void 0) === Node.COMMENT_NODE;
        }, nodeIsCursorTarget: function(t3, n2) {
          var i2;
          return i2 = (n2 != null ? n2 : {}).name, t3 ? e.nodeIsTextNode(t3) ? t3.data === e.ZERO_WIDTH_SPACE ? i2 ? t3.parentNode.dataset.trixCursorTarget === i2 : true : void 0 : e.nodeIsCursorTarget(t3.firstChild) : void 0;
        }, nodeIsAttachmentElement: function(t3) {
          return e.elementMatchesSelector(t3, e.AttachmentView.attachmentSelector);
        }, nodeIsEmptyTextNode: function(t3) {
          return e.nodeIsTextNode(t3) && (t3 != null ? t3.data : void 0) === "";
        }, nodeIsTextNode: function(t3) {
          return (t3 != null ? t3.nodeType : void 0) === Node.TEXT_NODE;
        }});
      }.call(this), function() {
        var t2, n, i, o, r;
        t2 = e.copyObject, o = e.objectsAreEqual, e.extend({normalizeRange: i = function(t3) {
          var e2;
          if (t3 != null)
            return Array.isArray(t3) || (t3 = [t3, t3]), [n(t3[0]), n((e2 = t3[1]) != null ? e2 : t3[0])];
        }, rangeIsCollapsed: function(t3) {
          var e2, n2, o2;
          if (t3 != null)
            return n2 = i(t3), o2 = n2[0], e2 = n2[1], r(o2, e2);
        }, rangesAreEqual: function(t3, e2) {
          var n2, o2, s, a, u, c;
          if (t3 != null && e2 != null)
            return s = i(t3), o2 = s[0], n2 = s[1], a = i(e2), c = a[0], u = a[1], r(o2, c) && r(n2, u);
        }}), n = function(e2) {
          return typeof e2 == "number" ? e2 : t2(e2);
        }, r = function(t3, e2) {
          return typeof t3 == "number" ? t3 === e2 : o(t3, e2);
        };
      }.call(this), function() {
        var t2, n, i, o, r, s, a;
        e.registerElement = function(t3, e2) {
          var n2, i2;
          return e2 == null && (e2 = {}), t3 = t3.toLowerCase(), e2 = a(e2), i2 = s(e2), (n2 = i2.defaultCSS) && (delete i2.defaultCSS, o(n2, t3)), r(t3, i2);
        }, o = function(t3, e2) {
          var n2;
          return n2 = i(e2), n2.textContent = t3.replace(/%t/g, e2);
        }, i = function(e2) {
          var n2, i2;
          return n2 = document.createElement("style"), n2.setAttribute("type", "text/css"), n2.setAttribute("data-tag-name", e2.toLowerCase()), (i2 = t2()) && n2.setAttribute("nonce", i2), document.head.insertBefore(n2, document.head.firstChild), n2;
        }, t2 = function() {
          var t3;
          return (t3 = n("trix-csp-nonce") || n("csp-nonce")) ? t3.getAttribute("content") : void 0;
        }, n = function(t3) {
          return document.head.querySelector("meta[name=" + t3 + "]");
        }, s = function(t3) {
          var e2, n2, i2;
          n2 = {};
          for (e2 in t3)
            i2 = t3[e2], n2[e2] = typeof i2 == "function" ? {value: i2} : i2;
          return n2;
        }, a = function() {
          var t3;
          return t3 = function(t4) {
            var e2, n2, i2, o2, r2;
            for (e2 = {}, r2 = ["initialize", "connect", "disconnect"], n2 = 0, o2 = r2.length; o2 > n2; n2++)
              i2 = r2[n2], e2[i2] = t4[i2], delete t4[i2];
            return e2;
          }, window.customElements ? function(e2) {
            var n2, i2, o2, r2, s2;
            return s2 = t3(e2), o2 = s2.initialize, n2 = s2.connect, i2 = s2.disconnect, o2 && (r2 = n2, n2 = function() {
              return this.initialized || (this.initialized = true, o2.call(this)), r2 != null ? r2.call(this) : void 0;
            }), n2 && (e2.connectedCallback = n2), i2 && (e2.disconnectedCallback = i2), e2;
          } : function(e2) {
            var n2, i2, o2, r2;
            return r2 = t3(e2), o2 = r2.initialize, n2 = r2.connect, i2 = r2.disconnect, o2 && (e2.createdCallback = o2), n2 && (e2.attachedCallback = n2), i2 && (e2.detachedCallback = i2), e2;
          };
        }(), r = function() {
          return window.customElements ? function(t3, e2) {
            var n2;
            return n2 = function() {
              return typeof Reflect == "object" ? Reflect.construct(HTMLElement, [], n2) : HTMLElement.apply(this);
            }, Object.setPrototypeOf(n2.prototype, HTMLElement.prototype), Object.setPrototypeOf(n2, HTMLElement), Object.defineProperties(n2.prototype, e2), window.customElements.define(t3, n2), n2;
          } : function(t3, e2) {
            var n2, i2;
            return i2 = Object.create(HTMLElement.prototype, e2), n2 = document.registerElement(t3, {prototype: i2}), Object.defineProperty(i2, "constructor", {value: n2}), n2;
          };
        }();
      }.call(this), function() {
        var t2, n;
        e.extend({getDOMSelection: function() {
          var t3;
          return t3 = window.getSelection(), t3.rangeCount > 0 ? t3 : void 0;
        }, getDOMRange: function() {
          var n2, i;
          return (n2 = (i = e.getDOMSelection()) != null ? i.getRangeAt(0) : void 0) && !t2(n2) ? n2 : void 0;
        }, setDOMRange: function(t3) {
          var n2;
          return n2 = window.getSelection(), n2.removeAllRanges(), n2.addRange(t3), e.selectionChangeObserver.update();
        }}), t2 = function(t3) {
          return n(t3.startContainer) || n(t3.endContainer);
        }, n = function(t3) {
          return !Object.getPrototypeOf(t3);
        };
      }.call(this), function() {
        var t2;
        t2 = {"application/x-trix-feature-detection": "test"}, e.extend({dataTransferIsPlainText: function(t3) {
          var e2, n, i;
          return i = t3.getData("text/plain"), n = t3.getData("text/html"), i && n ? (e2 = new DOMParser().parseFromString(n, "text/html").body, e2.textContent === i ? !e2.querySelector("*") : void 0) : i != null ? i.length : void 0;
        }, dataTransferIsWritable: function(e2) {
          var n, i;
          if ((e2 != null ? e2.setData : void 0) != null) {
            for (n in t2)
              if (i = t2[n], !function() {
                try {
                  return e2.setData(n, i), e2.getData(n) === i;
                } catch (t3) {
                }
              }())
                return;
            return true;
          }
        }, keyEventIsKeyboardCommand: function() {
          return /Mac|^iP/.test(navigator.platform) ? function(t3) {
            return t3.metaKey;
          } : function(t3) {
            return t3.ctrlKey;
          };
        }()});
      }.call(this), function() {
        e.extend({RTL_PATTERN: /[\u05BE\u05C0\u05C3\u05D0-\u05EA\u05F0-\u05F4\u061B\u061F\u0621-\u063A\u0640-\u064A\u066D\u0671-\u06B7\u06BA-\u06BE\u06C0-\u06CE\u06D0-\u06D5\u06E5\u06E6\u200F\u202B\u202E\uFB1F-\uFB28\uFB2A-\uFB36\uFB38-\uFB3C\uFB3E\uFB40\uFB41\uFB43\uFB44\uFB46-\uFBB1\uFBD3-\uFD3D\uFD50-\uFD8F\uFD92-\uFDC7\uFDF0-\uFDFB\uFE70-\uFE72\uFE74\uFE76-\uFEFC]/, getDirection: function() {
          var t2, n, i, o;
          return n = e.makeElement("input", {dir: "auto", name: "x", dirName: "x.dir"}), t2 = e.makeElement("form"), t2.appendChild(n), i = function() {
            try {
              return new FormData(t2).has(n.dirName);
            } catch (e2) {
            }
          }(), o = function() {
            try {
              return n.matches(":dir(ltr),:dir(rtl)");
            } catch (t3) {
            }
          }(), i ? function(e2) {
            return n.value = e2, new FormData(t2).get(n.dirName);
          } : o ? function(t3) {
            return n.value = t3, n.matches(":dir(rtl)") ? "rtl" : "ltr";
          } : function(t3) {
            var n2;
            return n2 = t3.trim().charAt(0), e.RTL_PATTERN.test(n2) ? "rtl" : "ltr";
          };
        }()});
      }.call(this), function() {
      }.call(this), function() {
        var t2, n = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var o in e2)
            i.call(e2, o) && (t3[o] = e2[o]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, i = {}.hasOwnProperty;
        t2 = e.arraysAreEqual, e.Hash = function(i2) {
          function o(t3) {
            t3 == null && (t3 = {}), this.values = s(t3), o.__super__.constructor.apply(this, arguments);
          }
          var r, s, a, u, c;
          return n(o, i2), o.fromCommonAttributesOfObjects = function(t3) {
            var e2, n2, i3, o2, s2, a2;
            if (t3 == null && (t3 = []), !t3.length)
              return new this();
            for (e2 = r(t3[0]), i3 = e2.getKeys(), a2 = t3.slice(1), n2 = 0, o2 = a2.length; o2 > n2; n2++)
              s2 = a2[n2], i3 = e2.getKeysCommonToHash(r(s2)), e2 = e2.slice(i3);
            return e2;
          }, o.box = function(t3) {
            return r(t3);
          }, o.prototype.add = function(t3, e2) {
            return this.merge(u(t3, e2));
          }, o.prototype.remove = function(t3) {
            return new e.Hash(s(this.values, t3));
          }, o.prototype.get = function(t3) {
            return this.values[t3];
          }, o.prototype.has = function(t3) {
            return t3 in this.values;
          }, o.prototype.merge = function(t3) {
            return new e.Hash(a(this.values, c(t3)));
          }, o.prototype.slice = function(t3) {
            var n2, i3, o2, r2;
            for (r2 = {}, n2 = 0, o2 = t3.length; o2 > n2; n2++)
              i3 = t3[n2], this.has(i3) && (r2[i3] = this.values[i3]);
            return new e.Hash(r2);
          }, o.prototype.getKeys = function() {
            return Object.keys(this.values);
          }, o.prototype.getKeysCommonToHash = function(t3) {
            var e2, n2, i3, o2, s2;
            for (t3 = r(t3), o2 = this.getKeys(), s2 = [], e2 = 0, i3 = o2.length; i3 > e2; e2++)
              n2 = o2[e2], this.values[n2] === t3.values[n2] && s2.push(n2);
            return s2;
          }, o.prototype.isEqualTo = function(e2) {
            return t2(this.toArray(), r(e2).toArray());
          }, o.prototype.isEmpty = function() {
            return this.getKeys().length === 0;
          }, o.prototype.toArray = function() {
            var t3, e2, n2;
            return (this.array != null ? this.array : this.array = function() {
              var i3;
              e2 = [], i3 = this.values;
              for (t3 in i3)
                n2 = i3[t3], e2.push(t3, n2);
              return e2;
            }.call(this)).slice(0);
          }, o.prototype.toObject = function() {
            return s(this.values);
          }, o.prototype.toJSON = function() {
            return this.toObject();
          }, o.prototype.contentsForInspection = function() {
            return {values: JSON.stringify(this.values)};
          }, u = function(t3, e2) {
            var n2;
            return n2 = {}, n2[t3] = e2, n2;
          }, a = function(t3, e2) {
            var n2, i3, o2;
            i3 = s(t3);
            for (n2 in e2)
              o2 = e2[n2], i3[n2] = o2;
            return i3;
          }, s = function(t3, e2) {
            var n2, i3, o2, r2, s2;
            for (r2 = {}, s2 = Object.keys(t3).sort(), n2 = 0, o2 = s2.length; o2 > n2; n2++)
              i3 = s2[n2], i3 !== e2 && (r2[i3] = t3[i3]);
            return r2;
          }, r = function(t3) {
            return t3 instanceof e.Hash ? t3 : new e.Hash(t3);
          }, c = function(t3) {
            return t3 instanceof e.Hash ? t3.values : t3;
          }, o;
        }(e.Object);
      }.call(this), function() {
        e.ObjectGroup = function() {
          function t2(t3, e2) {
            var n, i;
            this.objects = t3 != null ? t3 : [], i = e2.depth, n = e2.asTree, n && (this.depth = i, this.objects = this.constructor.groupObjects(this.objects, {asTree: n, depth: this.depth + 1}));
          }
          return t2.groupObjects = function(t3, e2) {
            var n, i, o, r, s, a, u, c, l;
            for (t3 == null && (t3 = []), l = e2 != null ? e2 : {}, o = l.depth, n = l.asTree, n && o == null && (o = 0), c = [], s = 0, a = t3.length; a > s; s++) {
              if (u = t3[s], r) {
                if ((typeof u.canBeGrouped == "function" ? u.canBeGrouped(o) : void 0) && (typeof (i = r[r.length - 1]).canBeGroupedWith == "function" ? i.canBeGroupedWith(u, o) : void 0)) {
                  r.push(u);
                  continue;
                }
                c.push(new this(r, {depth: o, asTree: n})), r = null;
              }
              (typeof u.canBeGrouped == "function" ? u.canBeGrouped(o) : void 0) ? r = [u] : c.push(u);
            }
            return r && c.push(new this(r, {depth: o, asTree: n})), c;
          }, t2.prototype.getObjects = function() {
            return this.objects;
          }, t2.prototype.getDepth = function() {
            return this.depth;
          }, t2.prototype.getCacheKey = function() {
            var t3, e2, n, i, o;
            for (e2 = ["objectGroup"], o = this.getObjects(), t3 = 0, n = o.length; n > t3; t3++)
              i = o[t3], e2.push(i.getCacheKey());
            return e2.join("/");
          }, t2;
        }();
      }.call(this), function() {
        var t2 = function(t3, e2) {
          function i() {
            this.constructor = t3;
          }
          for (var o in e2)
            n.call(e2, o) && (t3[o] = e2[o]);
          return i.prototype = e2.prototype, t3.prototype = new i(), t3.__super__ = e2.prototype, t3;
        }, n = {}.hasOwnProperty;
        e.ObjectMap = function(e2) {
          function n2(t3) {
            var e3, n3, i, o, r;
            for (t3 == null && (t3 = []), this.objects = {}, i = 0, o = t3.length; o > i; i++)
              r = t3[i], n3 = JSON.stringify(r), (e3 = this.objects)[n3] == null && (e3[n3] = r);
          }
          return t2(n2, e2), n2.prototype.find = function(t3) {
            var e3;
            return e3 = JSON.stringify(t3), this.objects[e3];
          }, n2;
        }(e.BasicObject);
      }.call(this), function() {
        e.ElementStore = function() {
          function t2(t3) {
            this.reset(t3);
          }
          var e2;
          return t2.prototype.add = function(t3) {
            var n;
            return n = e2(t3), this.elements[n] = t3;
          }, t2.prototype.remove = function(t3) {
            var n, i;
            return n = e2(t3), (i = this.elements[n]) ? (delete this.elements[n], i) : void 0;
          }, t2.prototype.reset = function(t3) {
            var e3, n, i;
            for (t3 == null && (t3 = []), this.elements = {}, n = 0, i = t3.length; i > n; n++)
              e3 = t3[n], this.add(e3);
            return t3;
          }, e2 = function(t3) {
            return t3.dataset.trixStoreKey;
          }, t2;
        }();
      }.call(this), function() {
      }.call(this), function() {
        var t2 = function(t3, e2) {
          function i() {
            this.constructor = t3;
          }
          for (var o in e2)
            n.call(e2, o) && (t3[o] = e2[o]);
          return i.prototype = e2.prototype, t3.prototype = new i(), t3.__super__ = e2.prototype, t3;
        }, n = {}.hasOwnProperty;
        e.Operation = function(e2) {
          function n2() {
            return n2.__super__.constructor.apply(this, arguments);
          }
          return t2(n2, e2), n2.prototype.isPerforming = function() {
            return this.performing === true;
          }, n2.prototype.hasPerformed = function() {
            return this.performed === true;
          }, n2.prototype.hasSucceeded = function() {
            return this.performed && this.succeeded;
          }, n2.prototype.hasFailed = function() {
            return this.performed && !this.succeeded;
          }, n2.prototype.getPromise = function() {
            return this.promise != null ? this.promise : this.promise = new Promise(function(t3) {
              return function(e3, n3) {
                return t3.performing = true, t3.perform(function(i, o) {
                  return t3.succeeded = i, t3.performing = false, t3.performed = true, t3.succeeded ? e3(o) : n3(o);
                });
              };
            }(this));
          }, n2.prototype.perform = function(t3) {
            return t3(false);
          }, n2.prototype.release = function() {
            var t3;
            return (t3 = this.promise) != null && typeof t3.cancel == "function" && t3.cancel(), this.promise = null, this.performing = null, this.performed = null, this.succeeded = null;
          }, n2.proxyMethod("getPromise().then"), n2.proxyMethod("getPromise().catch"), n2;
        }(e.BasicObject);
      }.call(this), function() {
        var t2, n, i, o, r, s = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var i2 in e2)
            a.call(e2, i2) && (t3[i2] = e2[i2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, a = {}.hasOwnProperty;
        e.UTF16String = function(t3) {
          function e2(t4, e3) {
            this.ucs2String = t4, this.codepoints = e3, this.length = this.codepoints.length, this.ucs2Length = this.ucs2String.length;
          }
          return s(e2, t3), e2.box = function(t4) {
            return t4 == null && (t4 = ""), t4 instanceof this ? t4 : this.fromUCS2String(t4 != null ? t4.toString() : void 0);
          }, e2.fromUCS2String = function(t4) {
            return new this(t4, o(t4));
          }, e2.fromCodepoints = function(t4) {
            return new this(r(t4), t4);
          }, e2.prototype.offsetToUCS2Offset = function(t4) {
            return r(this.codepoints.slice(0, Math.max(0, t4))).length;
          }, e2.prototype.offsetFromUCS2Offset = function(t4) {
            return o(this.ucs2String.slice(0, Math.max(0, t4))).length;
          }, e2.prototype.slice = function() {
            var t4;
            return this.constructor.fromCodepoints((t4 = this.codepoints).slice.apply(t4, arguments));
          }, e2.prototype.charAt = function(t4) {
            return this.slice(t4, t4 + 1);
          }, e2.prototype.isEqualTo = function(t4) {
            return this.constructor.box(t4).ucs2String === this.ucs2String;
          }, e2.prototype.toJSON = function() {
            return this.ucs2String;
          }, e2.prototype.getCacheKey = function() {
            return this.ucs2String;
          }, e2.prototype.toString = function() {
            return this.ucs2String;
          }, e2;
        }(e.BasicObject), t2 = (typeof Array.from == "function" ? Array.from("\u{1F47C}").length : void 0) === 1, n = (typeof " ".codePointAt == "function" ? " ".codePointAt(0) : void 0) != null, i = (typeof String.fromCodePoint == "function" ? String.fromCodePoint(32, 128124) : void 0) === " \u{1F47C}", o = t2 && n ? function(t3) {
          return Array.from(t3).map(function(t4) {
            return t4.codePointAt(0);
          });
        } : function(t3) {
          var e2, n2, i2, o2, r2;
          for (o2 = [], e2 = 0, i2 = t3.length; i2 > e2; )
            r2 = t3.charCodeAt(e2++), r2 >= 55296 && 56319 >= r2 && i2 > e2 && (n2 = t3.charCodeAt(e2++), (64512 & n2) === 56320 ? r2 = ((1023 & r2) << 10) + (1023 & n2) + 65536 : e2--), o2.push(r2);
          return o2;
        }, r = i ? function(t3) {
          return String.fromCodePoint.apply(String, t3);
        } : function(t3) {
          var e2, n2, i2;
          return e2 = function() {
            var e3, o2, r2;
            for (r2 = [], e3 = 0, o2 = t3.length; o2 > e3; e3++)
              i2 = t3[e3], n2 = "", i2 > 65535 && (i2 -= 65536, n2 += String.fromCharCode(i2 >>> 10 & 1023 | 55296), i2 = 56320 | 1023 & i2), r2.push(n2 + String.fromCharCode(i2));
            return r2;
          }(), e2.join("");
        };
      }.call(this), function() {
      }.call(this), function() {
      }.call(this), function() {
        e.config.lang = {attachFiles: "Attach Files", bold: "Bold", bullets: "Bullets", byte: "Byte", bytes: "Bytes", captionPlaceholder: "Add a caption\u2026", code: "Code", heading1: "Heading", indent: "Increase Level", italic: "Italic", link: "Link", numbers: "Numbers", outdent: "Decrease Level", quote: "Quote", redo: "Redo", remove: "Remove", strike: "Strikethrough", undo: "Undo", unlink: "Unlink", url: "URL", urlPlaceholder: "Enter a URL\u2026", GB: "GB", KB: "KB", MB: "MB", PB: "PB", TB: "TB"};
      }.call(this), function() {
        e.config.css = {attachment: "attachment", attachmentCaption: "attachment__caption", attachmentCaptionEditor: "attachment__caption-editor", attachmentMetadata: "attachment__metadata", attachmentMetadataContainer: "attachment__metadata-container", attachmentName: "attachment__name", attachmentProgress: "attachment__progress", attachmentSize: "attachment__size", attachmentToolbar: "attachment__toolbar", attachmentGallery: "attachment-gallery"};
      }.call(this), function() {
        var t2;
        e.config.blockAttributes = t2 = {default: {tagName: "div", parse: false}, quote: {tagName: "blockquote", nestable: true}, heading1: {tagName: "h1", terminal: true, breakOnReturn: true, group: false}, code: {tagName: "pre", terminal: true, text: {plaintext: true}}, bulletList: {tagName: "ul", parse: false}, bullet: {tagName: "li", listAttribute: "bulletList", group: false, nestable: true, test: function(n) {
          return e.tagName(n.parentNode) === t2[this.listAttribute].tagName;
        }}, numberList: {tagName: "ol", parse: false}, number: {tagName: "li", listAttribute: "numberList", group: false, nestable: true, test: function(n) {
          return e.tagName(n.parentNode) === t2[this.listAttribute].tagName;
        }}, attachmentGallery: {tagName: "div", exclusive: true, terminal: true, parse: false, group: false}};
      }.call(this), function() {
        var t2, n;
        t2 = e.config.lang, n = [t2.bytes, t2.KB, t2.MB, t2.GB, t2.TB, t2.PB], e.config.fileSize = {prefix: "IEC", precision: 2, formatter: function(e2) {
          var i, o, r, s, a;
          switch (e2) {
            case 0:
              return "0 " + t2.bytes;
            case 1:
              return "1 " + t2.byte;
            default:
              return i = function() {
                switch (this.prefix) {
                  case "SI":
                    return 1e3;
                  case "IEC":
                    return 1024;
                }
              }.call(this), o = Math.floor(Math.log(e2) / Math.log(i)), r = e2 / Math.pow(i, o), s = r.toFixed(this.precision), a = s.replace(/0*$/, "").replace(/\.$/, ""), a + " " + n[o];
          }
        }};
      }.call(this), function() {
        e.config.textAttributes = {bold: {tagName: "strong", inheritable: true, parser: function(t2) {
          var e2;
          return e2 = window.getComputedStyle(t2), e2.fontWeight === "bold" || e2.fontWeight >= 600;
        }}, italic: {tagName: "em", inheritable: true, parser: function(t2) {
          var e2;
          return e2 = window.getComputedStyle(t2), e2.fontStyle === "italic";
        }}, href: {groupTagName: "a", parser: function(t2) {
          var n, i, o;
          return n = e.AttachmentView.attachmentSelector, o = "a:not(" + n + ")", (i = e.findClosestElementFromNode(t2, {matchingSelector: o})) ? i.getAttribute("href") : void 0;
        }}, strike: {tagName: "del", inheritable: true}, frozen: {style: {backgroundColor: "highlight"}}};
      }.call(this), function() {
        var t2, n, i, o, r;
        r = "[data-trix-serialize=false]", o = ["contenteditable", "data-trix-id", "data-trix-store-key", "data-trix-mutable", "data-trix-placeholder", "tabindex"], n = "data-trix-serialized-attributes", i = "[" + n + "]", t2 = new RegExp("<!--block-->", "g"), e.extend({serializers: {"application/json": function(t3) {
          var n2;
          if (t3 instanceof e.Document)
            n2 = t3;
          else {
            if (!(t3 instanceof HTMLElement))
              throw new Error("unserializable object");
            n2 = e.Document.fromHTML(t3.innerHTML);
          }
          return n2.toSerializableDocument().toJSONString();
        }, "text/html": function(s) {
          var a, u, c, l, h, p, d, f, g, m, v, y, b, A, C, x, w;
          if (s instanceof e.Document)
            l = e.DocumentView.render(s);
          else {
            if (!(s instanceof HTMLElement))
              throw new Error("unserializable object");
            l = s.cloneNode(true);
          }
          for (A = l.querySelectorAll(r), h = 0, g = A.length; g > h; h++)
            c = A[h], e.removeNode(c);
          for (p = 0, m = o.length; m > p; p++)
            for (a = o[p], C = l.querySelectorAll("[" + a + "]"), d = 0, v = C.length; v > d; d++)
              c = C[d], c.removeAttribute(a);
          for (x = l.querySelectorAll(i), f = 0, y = x.length; y > f; f++) {
            c = x[f];
            try {
              u = JSON.parse(c.getAttribute(n)), c.removeAttribute(n);
              for (b in u)
                w = u[b], c.setAttribute(b, w);
            } catch (E) {
            }
          }
          return l.innerHTML.replace(t2, "");
        }}, deserializers: {"application/json": function(t3) {
          return e.Document.fromJSONString(t3);
        }, "text/html": function(t3) {
          return e.Document.fromHTML(t3);
        }}, serializeToContentType: function(t3, n2) {
          var i2;
          if (i2 = e.serializers[n2])
            return i2(t3);
          throw new Error("unknown content type: " + n2);
        }, deserializeFromContentType: function(t3, n2) {
          var i2;
          if (i2 = e.deserializers[n2])
            return i2(t3);
          throw new Error("unknown content type: " + n2);
        }});
      }.call(this), function() {
        var t2;
        t2 = e.config.lang, e.config.toolbar = {getDefaultHTML: function() {
          return '<div class="trix-button-row">\n  <span class="trix-button-group trix-button-group--text-tools" data-trix-button-group="text-tools">\n    <button type="button" class="trix-button trix-button--icon trix-button--icon-bold" data-trix-attribute="bold" data-trix-key="b" title="' + t2.bold + '" tabindex="-1">' + t2.bold + '</button>\n    <button type="button" class="trix-button trix-button--icon trix-button--icon-italic" data-trix-attribute="italic" data-trix-key="i" title="' + t2.italic + '" tabindex="-1">' + t2.italic + '</button>\n    <button type="button" class="trix-button trix-button--icon trix-button--icon-strike" data-trix-attribute="strike" title="' + t2.strike + '" tabindex="-1">' + t2.strike + '</button>\n    <button type="button" class="trix-button trix-button--icon trix-button--icon-link" data-trix-attribute="href" data-trix-action="link" data-trix-key="k" title="' + t2.link + '" tabindex="-1">' + t2.link + '</button>\n  </span>\n\n  <span class="trix-button-group trix-button-group--block-tools" data-trix-button-group="block-tools">\n    <button type="button" class="trix-button trix-button--icon trix-button--icon-heading-1" data-trix-attribute="heading1" title="' + t2.heading1 + '" tabindex="-1">' + t2.heading1 + '</button>\n    <button type="button" class="trix-button trix-button--icon trix-button--icon-quote" data-trix-attribute="quote" title="' + t2.quote + '" tabindex="-1">' + t2.quote + '</button>\n    <button type="button" class="trix-button trix-button--icon trix-button--icon-code" data-trix-attribute="code" title="' + t2.code + '" tabindex="-1">' + t2.code + '</button>\n    <button type="button" class="trix-button trix-button--icon trix-button--icon-bullet-list" data-trix-attribute="bullet" title="' + t2.bullets + '" tabindex="-1">' + t2.bullets + '</button>\n    <button type="button" class="trix-button trix-button--icon trix-button--icon-number-list" data-trix-attribute="number" title="' + t2.numbers + '" tabindex="-1">' + t2.numbers + '</button>\n    <button type="button" class="trix-button trix-button--icon trix-button--icon-decrease-nesting-level" data-trix-action="decreaseNestingLevel" title="' + t2.outdent + '" tabindex="-1">' + t2.outdent + '</button>\n    <button type="button" class="trix-button trix-button--icon trix-button--icon-increase-nesting-level" data-trix-action="increaseNestingLevel" title="' + t2.indent + '" tabindex="-1">' + t2.indent + '</button>\n  </span>\n\n  <span class="trix-button-group trix-button-group--file-tools" data-trix-button-group="file-tools">\n    <button type="button" class="trix-button trix-button--icon trix-button--icon-attach" data-trix-action="attachFiles" title="' + t2.attachFiles + '" tabindex="-1">' + t2.attachFiles + '</button>\n  </span>\n\n  <span class="trix-button-group-spacer"></span>\n\n  <span class="trix-button-group trix-button-group--history-tools" data-trix-button-group="history-tools">\n    <button type="button" class="trix-button trix-button--icon trix-button--icon-undo" data-trix-action="undo" data-trix-key="z" title="' + t2.undo + '" tabindex="-1">' + t2.undo + '</button>\n    <button type="button" class="trix-button trix-button--icon trix-button--icon-redo" data-trix-action="redo" data-trix-key="shift+z" title="' + t2.redo + '" tabindex="-1">' + t2.redo + '</button>\n  </span>\n</div>\n\n<div class="trix-dialogs" data-trix-dialogs>\n  <div class="trix-dialog trix-dialog--link" data-trix-dialog="href" data-trix-dialog-attribute="href">\n    <div class="trix-dialog__link-fields">\n      <input type="url" name="href" class="trix-input trix-input--dialog" placeholder="' + t2.urlPlaceholder + '" aria-label="' + t2.url + '" required data-trix-input>\n      <div class="trix-button-group">\n        <input type="button" class="trix-button trix-button--dialog" value="' + t2.link + '" data-trix-method="setAttribute">\n        <input type="button" class="trix-button trix-button--dialog" value="' + t2.unlink + '" data-trix-method="removeAttribute">\n      </div>\n    </div>\n  </div>\n</div>';
        }};
      }.call(this), function() {
        e.config.undoInterval = 5e3;
      }.call(this), function() {
        e.config.attachments = {preview: {presentation: "gallery", caption: {name: true, size: true}}, file: {caption: {size: true}}};
      }.call(this), function() {
        e.config.keyNames = {8: "backspace", 9: "tab", 13: "return", 27: "escape", 37: "left", 39: "right", 46: "delete", 68: "d", 72: "h", 79: "o"};
      }.call(this), function() {
        e.config.input = {level2Enabled: true, getLevel: function() {
          return this.level2Enabled && e.browser.supportsInputEvents ? 2 : 0;
        }, pickFiles: function(t2) {
          var n;
          return n = e.makeElement("input", {type: "file", multiple: true, hidden: true, id: this.fileInputId}), n.addEventListener("change", function() {
            return t2(n.files), e.removeNode(n);
          }), e.removeNode(document.getElementById(this.fileInputId)), document.body.appendChild(n), n.click();
        }, fileInputId: "trix-file-input-" + Date.now().toString(16)};
      }.call(this), function() {
      }.call(this), function() {
        e.registerElement("trix-toolbar", {defaultCSS: "%t {\n  display: block;\n}\n\n%t {\n  white-space: nowrap;\n}\n\n%t [data-trix-dialog] {\n  display: none;\n}\n\n%t [data-trix-dialog][data-trix-active] {\n  display: block;\n}\n\n%t [data-trix-dialog] [data-trix-validate]:invalid {\n  background-color: #ffdddd;\n}", initialize: function() {
          return this.innerHTML === "" ? this.innerHTML = e.config.toolbar.getDefaultHTML() : void 0;
        }});
      }.call(this), function() {
        var t2 = function(t3, e2) {
          function i2() {
            this.constructor = t3;
          }
          for (var o in e2)
            n.call(e2, o) && (t3[o] = e2[o]);
          return i2.prototype = e2.prototype, t3.prototype = new i2(), t3.__super__ = e2.prototype, t3;
        }, n = {}.hasOwnProperty, i = [].indexOf || function(t3) {
          for (var e2 = 0, n2 = this.length; n2 > e2; e2++)
            if (e2 in this && this[e2] === t3)
              return e2;
          return -1;
        };
        e.ObjectView = function(n2) {
          function o(t3, e2) {
            this.object = t3, this.options = e2 != null ? e2 : {}, this.childViews = [], this.rootView = this;
          }
          return t2(o, n2), o.prototype.getNodes = function() {
            var t3, e2, n3, i2, o2;
            for (this.nodes == null && (this.nodes = this.createNodes()), i2 = this.nodes, o2 = [], t3 = 0, e2 = i2.length; e2 > t3; t3++)
              n3 = i2[t3], o2.push(n3.cloneNode(true));
            return o2;
          }, o.prototype.invalidate = function() {
            var t3;
            return this.nodes = null, this.childViews = [], (t3 = this.parentView) != null ? t3.invalidate() : void 0;
          }, o.prototype.invalidateViewForObject = function(t3) {
            var e2;
            return (e2 = this.findViewForObject(t3)) != null ? e2.invalidate() : void 0;
          }, o.prototype.findOrCreateCachedChildView = function(t3, e2) {
            var n3;
            return (n3 = this.getCachedViewForObject(e2)) ? this.recordChildView(n3) : (n3 = this.createChildView.apply(this, arguments), this.cacheViewForObject(n3, e2)), n3;
          }, o.prototype.createChildView = function(t3, n3, i2) {
            var o2;
            return i2 == null && (i2 = {}), n3 instanceof e.ObjectGroup && (i2.viewClass = t3, t3 = e.ObjectGroupView), o2 = new t3(n3, i2), this.recordChildView(o2);
          }, o.prototype.recordChildView = function(t3) {
            return t3.parentView = this, t3.rootView = this.rootView, this.childViews.push(t3), t3;
          }, o.prototype.getAllChildViews = function() {
            var t3, e2, n3, i2, o2;
            for (o2 = [], i2 = this.childViews, e2 = 0, n3 = i2.length; n3 > e2; e2++)
              t3 = i2[e2], o2.push(t3), o2 = o2.concat(t3.getAllChildViews());
            return o2;
          }, o.prototype.findElement = function() {
            return this.findElementForObject(this.object);
          }, o.prototype.findElementForObject = function(t3) {
            var e2;
            return (e2 = t3 != null ? t3.id : void 0) ? this.rootView.element.querySelector("[data-trix-id='" + e2 + "']") : void 0;
          }, o.prototype.findViewForObject = function(t3) {
            var e2, n3, i2, o2;
            for (i2 = this.getAllChildViews(), e2 = 0, n3 = i2.length; n3 > e2; e2++)
              if (o2 = i2[e2], o2.object === t3)
                return o2;
          }, o.prototype.getViewCache = function() {
            return this.rootView !== this ? this.rootView.getViewCache() : this.isViewCachingEnabled() ? this.viewCache != null ? this.viewCache : this.viewCache = {} : void 0;
          }, o.prototype.isViewCachingEnabled = function() {
            return this.shouldCacheViews !== false;
          }, o.prototype.enableViewCaching = function() {
            return this.shouldCacheViews = true;
          }, o.prototype.disableViewCaching = function() {
            return this.shouldCacheViews = false;
          }, o.prototype.getCachedViewForObject = function(t3) {
            var e2;
            return (e2 = this.getViewCache()) != null ? e2[t3.getCacheKey()] : void 0;
          }, o.prototype.cacheViewForObject = function(t3, e2) {
            var n3;
            return (n3 = this.getViewCache()) != null ? n3[e2.getCacheKey()] = t3 : void 0;
          }, o.prototype.garbageCollectCachedViews = function() {
            var t3, e2, n3, o2, r, s;
            if (t3 = this.getViewCache()) {
              s = this.getAllChildViews().concat(this), n3 = function() {
                var t4, e3, n4;
                for (n4 = [], t4 = 0, e3 = s.length; e3 > t4; t4++)
                  r = s[t4], n4.push(r.object.getCacheKey());
                return n4;
              }(), o2 = [];
              for (e2 in t3)
                i.call(n3, e2) < 0 && o2.push(delete t3[e2]);
              return o2;
            }
          }, o;
        }(e.BasicObject);
      }.call(this), function() {
        var t2 = function(t3, e2) {
          function i() {
            this.constructor = t3;
          }
          for (var o in e2)
            n.call(e2, o) && (t3[o] = e2[o]);
          return i.prototype = e2.prototype, t3.prototype = new i(), t3.__super__ = e2.prototype, t3;
        }, n = {}.hasOwnProperty;
        e.ObjectGroupView = function(e2) {
          function n2() {
            n2.__super__.constructor.apply(this, arguments), this.objectGroup = this.object, this.viewClass = this.options.viewClass, delete this.options.viewClass;
          }
          return t2(n2, e2), n2.prototype.getChildViews = function() {
            var t3, e3, n3, i;
            if (!this.childViews.length)
              for (i = this.objectGroup.getObjects(), t3 = 0, e3 = i.length; e3 > t3; t3++)
                n3 = i[t3], this.findOrCreateCachedChildView(this.viewClass, n3, this.options);
            return this.childViews;
          }, n2.prototype.createNodes = function() {
            var t3, e3, n3, i, o, r, s, a, u;
            for (t3 = this.createContainerElement(), s = this.getChildViews(), e3 = 0, i = s.length; i > e3; e3++)
              for (u = s[e3], a = u.getNodes(), n3 = 0, o = a.length; o > n3; n3++)
                r = a[n3], t3.appendChild(r);
            return [t3];
          }, n2.prototype.createContainerElement = function(t3) {
            return t3 == null && (t3 = this.objectGroup.getDepth()), this.getChildViews()[0].createContainerElement(t3);
          }, n2;
        }(e.ObjectView);
      }.call(this), function() {
        var t2 = function(t3, e2) {
          function i() {
            this.constructor = t3;
          }
          for (var o in e2)
            n.call(e2, o) && (t3[o] = e2[o]);
          return i.prototype = e2.prototype, t3.prototype = new i(), t3.__super__ = e2.prototype, t3;
        }, n = {}.hasOwnProperty;
        e.Controller = function(e2) {
          function n2() {
            return n2.__super__.constructor.apply(this, arguments);
          }
          return t2(n2, e2), n2;
        }(e.BasicObject);
      }.call(this), function() {
        var t2, n, i, o, r, s, a = function(t3, e2) {
          return function() {
            return t3.apply(e2, arguments);
          };
        }, u = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var i2 in e2)
            c.call(e2, i2) && (t3[i2] = e2[i2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, c = {}.hasOwnProperty, l = [].indexOf || function(t3) {
          for (var e2 = 0, n2 = this.length; n2 > e2; e2++)
            if (e2 in this && this[e2] === t3)
              return e2;
          return -1;
        };
        t2 = e.findClosestElementFromNode, i = e.nodeIsEmptyTextNode, n = e.nodeIsBlockStartComment, o = e.normalizeSpaces, r = e.summarizeStringChange, s = e.tagName, e.MutationObserver = function(e2) {
          function c2(t3) {
            this.element = t3, this.didMutate = a(this.didMutate, this), this.observer = new window.MutationObserver(this.didMutate), this.start();
          }
          var h, p, d, f;
          return u(c2, e2), p = "data-trix-mutable", d = "[" + p + "]", f = {attributes: true, childList: true, characterData: true, characterDataOldValue: true, subtree: true}, c2.prototype.start = function() {
            return this.reset(), this.observer.observe(this.element, f);
          }, c2.prototype.stop = function() {
            return this.observer.disconnect();
          }, c2.prototype.didMutate = function(t3) {
            var e3, n2;
            return (e3 = this.mutations).push.apply(e3, this.findSignificantMutations(t3)), this.mutations.length ? ((n2 = this.delegate) != null && typeof n2.elementDidMutate == "function" && n2.elementDidMutate(this.getMutationSummary()), this.reset()) : void 0;
          }, c2.prototype.reset = function() {
            return this.mutations = [];
          }, c2.prototype.findSignificantMutations = function(t3) {
            var e3, n2, i2, o2;
            for (o2 = [], e3 = 0, n2 = t3.length; n2 > e3; e3++)
              i2 = t3[e3], this.mutationIsSignificant(i2) && o2.push(i2);
            return o2;
          }, c2.prototype.mutationIsSignificant = function(t3) {
            var e3, n2, i2, o2;
            if (this.nodeIsMutable(t3.target))
              return false;
            for (o2 = this.nodesModifiedByMutation(t3), e3 = 0, n2 = o2.length; n2 > e3; e3++)
              if (i2 = o2[e3], this.nodeIsSignificant(i2))
                return true;
            return false;
          }, c2.prototype.nodeIsSignificant = function(t3) {
            return t3 !== this.element && !this.nodeIsMutable(t3) && !i(t3);
          }, c2.prototype.nodeIsMutable = function(e3) {
            return t2(e3, {matchingSelector: d});
          }, c2.prototype.nodesModifiedByMutation = function(t3) {
            var e3;
            switch (e3 = [], t3.type) {
              case "attributes":
                t3.attributeName !== p && e3.push(t3.target);
                break;
              case "characterData":
                e3.push(t3.target.parentNode), e3.push(t3.target);
                break;
              case "childList":
                e3.push.apply(e3, t3.addedNodes), e3.push.apply(e3, t3.removedNodes);
            }
            return e3;
          }, c2.prototype.getMutationSummary = function() {
            return this.getTextMutationSummary();
          }, c2.prototype.getTextMutationSummary = function() {
            var t3, e3, n2, i2, o2, r2, s2, a2, u2, c3, h2;
            for (a2 = this.getTextChangesFromCharacterData(), n2 = a2.additions, o2 = a2.deletions, h2 = this.getTextChangesFromChildList(), u2 = h2.additions, r2 = 0, s2 = u2.length; s2 > r2; r2++)
              e3 = u2[r2], l.call(n2, e3) < 0 && n2.push(e3);
            return o2.push.apply(o2, h2.deletions), c3 = {}, (t3 = n2.join("")) && (c3.textAdded = t3), (i2 = o2.join("")) && (c3.textDeleted = i2), c3;
          }, c2.prototype.getMutationsByType = function(t3) {
            var e3, n2, i2, o2, r2;
            for (o2 = this.mutations, r2 = [], e3 = 0, n2 = o2.length; n2 > e3; e3++)
              i2 = o2[e3], i2.type === t3 && r2.push(i2);
            return r2;
          }, c2.prototype.getTextChangesFromChildList = function() {
            var t3, e3, i2, r2, s2, a2, u2, c3, l2, p2, d2;
            for (t3 = [], u2 = [], a2 = this.getMutationsByType("childList"), e3 = 0, r2 = a2.length; r2 > e3; e3++)
              s2 = a2[e3], t3.push.apply(t3, s2.addedNodes), u2.push.apply(u2, s2.removedNodes);
            return c3 = t3.length === 0 && u2.length === 1 && n(u2[0]), c3 ? (p2 = [], d2 = ["\n"]) : (p2 = h(t3), d2 = h(u2)), {additions: function() {
              var t4, e4, n2;
              for (n2 = [], i2 = t4 = 0, e4 = p2.length; e4 > t4; i2 = ++t4)
                l2 = p2[i2], l2 !== d2[i2] && n2.push(o(l2));
              return n2;
            }(), deletions: function() {
              var t4, e4, n2;
              for (n2 = [], i2 = t4 = 0, e4 = d2.length; e4 > t4; i2 = ++t4)
                l2 = d2[i2], l2 !== p2[i2] && n2.push(o(l2));
              return n2;
            }()};
          }, c2.prototype.getTextChangesFromCharacterData = function() {
            var t3, e3, n2, i2, s2, a2, u2, c3;
            return e3 = this.getMutationsByType("characterData"), e3.length && (c3 = e3[0], n2 = e3[e3.length - 1], s2 = o(c3.oldValue), i2 = o(n2.target.data), a2 = r(s2, i2), t3 = a2.added, u2 = a2.removed), {additions: t3 ? [t3] : [], deletions: u2 ? [u2] : []};
          }, h = function(t3) {
            var e3, n2, i2, o2;
            for (t3 == null && (t3 = []), o2 = [], e3 = 0, n2 = t3.length; n2 > e3; e3++)
              switch (i2 = t3[e3], i2.nodeType) {
                case Node.TEXT_NODE:
                  o2.push(i2.data);
                  break;
                case Node.ELEMENT_NODE:
                  s(i2) === "br" ? o2.push("\n") : o2.push.apply(o2, h(i2.childNodes));
              }
            return o2;
          }, c2;
        }(e.BasicObject);
      }.call(this), function() {
        var t2 = function(t3, e2) {
          function i() {
            this.constructor = t3;
          }
          for (var o in e2)
            n.call(e2, o) && (t3[o] = e2[o]);
          return i.prototype = e2.prototype, t3.prototype = new i(), t3.__super__ = e2.prototype, t3;
        }, n = {}.hasOwnProperty;
        e.FileVerificationOperation = function(e2) {
          function n2(t3) {
            this.file = t3;
          }
          return t2(n2, e2), n2.prototype.perform = function(t3) {
            var e3;
            return e3 = new FileReader(), e3.onerror = function() {
              return t3(false);
            }, e3.onload = function(n3) {
              return function() {
                e3.onerror = null;
                try {
                  e3.abort();
                } catch (i) {
                }
                return t3(true, n3.file);
              };
            }(this), e3.readAsArrayBuffer(this.file);
          }, n2;
        }(e.Operation);
      }.call(this), function() {
        var t2, n, i = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var i2 in e2)
            o.call(e2, i2) && (t3[i2] = e2[i2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, o = {}.hasOwnProperty;
        t2 = e.handleEvent, n = e.innerElementIsActive, e.InputController = function(o2) {
          function r(n2) {
            var i2;
            this.element = n2, this.mutationObserver = new e.MutationObserver(this.element), this.mutationObserver.delegate = this;
            for (i2 in this.events)
              t2(i2, {onElement: this.element, withCallback: this.handlerFor(i2)});
          }
          return i(r, o2), r.prototype.events = {}, r.prototype.elementDidMutate = function() {
          }, r.prototype.editorWillSyncDocumentView = function() {
            return this.mutationObserver.stop();
          }, r.prototype.editorDidSyncDocumentView = function() {
            return this.mutationObserver.start();
          }, r.prototype.requestRender = function() {
            var t3;
            return (t3 = this.delegate) != null && typeof t3.inputControllerDidRequestRender == "function" ? t3.inputControllerDidRequestRender() : void 0;
          }, r.prototype.requestReparse = function() {
            var t3;
            return (t3 = this.delegate) != null && typeof t3.inputControllerDidRequestReparse == "function" && t3.inputControllerDidRequestReparse(), this.requestRender();
          }, r.prototype.attachFiles = function(t3) {
            var n2, i2;
            return i2 = function() {
              var i3, o3, r2;
              for (r2 = [], i3 = 0, o3 = t3.length; o3 > i3; i3++)
                n2 = t3[i3], r2.push(new e.FileVerificationOperation(n2));
              return r2;
            }(), Promise.all(i2).then(function(t4) {
              return function(e2) {
                return t4.handleInput(function() {
                  var t5, n3;
                  return (t5 = this.delegate) != null && t5.inputControllerWillAttachFiles(), (n3 = this.responder) != null && n3.insertFiles(e2), this.requestRender();
                });
              };
            }(this));
          }, r.prototype.handlerFor = function(t3) {
            return function(e2) {
              return function(i2) {
                return i2.defaultPrevented ? void 0 : e2.handleInput(function() {
                  return n(this.element) ? void 0 : (this.eventName = t3, this.events[t3].call(this, i2));
                });
              };
            }(this);
          }, r.prototype.handleInput = function(t3) {
            var e2, n2;
            try {
              return (e2 = this.delegate) != null && e2.inputControllerWillHandleInput(), t3.call(this);
            } finally {
              (n2 = this.delegate) != null && n2.inputControllerDidHandleInput();
            }
          }, r.prototype.createLinkHTML = function(t3, e2) {
            var n2;
            return n2 = document.createElement("a"), n2.href = t3, n2.textContent = e2 != null ? e2 : t3, n2.outerHTML;
          }, r;
        }(e.BasicObject);
      }.call(this), function() {
        var t2, n, i, o, r, s, a, u, c, l, h, p, d, f = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var i2 in e2)
            g.call(e2, i2) && (t3[i2] = e2[i2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, g = {}.hasOwnProperty, m = [].indexOf || function(t3) {
          for (var e2 = 0, n2 = this.length; n2 > e2; e2++)
            if (e2 in this && this[e2] === t3)
              return e2;
          return -1;
        };
        c = e.makeElement, l = e.objectsAreEqual, d = e.tagName, n = e.browser, a = e.keyEventIsKeyboardCommand, o = e.dataTransferIsWritable, i = e.dataTransferIsPlainText, u = e.config.keyNames, e.Level0InputController = function(n2) {
          function s2() {
            s2.__super__.constructor.apply(this, arguments), this.resetInputSummary();
          }
          var d2;
          return f(s2, n2), d2 = 0, s2.prototype.setInputSummary = function(t3) {
            var e2, n3;
            t3 == null && (t3 = {}), this.inputSummary.eventName = this.eventName;
            for (e2 in t3)
              n3 = t3[e2], this.inputSummary[e2] = n3;
            return this.inputSummary;
          }, s2.prototype.resetInputSummary = function() {
            return this.inputSummary = {};
          }, s2.prototype.reset = function() {
            return this.resetInputSummary(), e.selectionChangeObserver.reset();
          }, s2.prototype.elementDidMutate = function(t3) {
            var e2;
            return this.isComposing() ? (e2 = this.delegate) != null && typeof e2.inputControllerDidAllowUnhandledInput == "function" ? e2.inputControllerDidAllowUnhandledInput() : void 0 : this.handleInput(function() {
              return this.mutationIsSignificant(t3) && (this.mutationIsExpected(t3) ? this.requestRender() : this.requestReparse()), this.reset();
            });
          }, s2.prototype.mutationIsExpected = function(t3) {
            var e2, n3, i2, o2, r2, s3, a2, u2, c2, l2;
            return a2 = t3.textAdded, u2 = t3.textDeleted, this.inputSummary.preferDocument ? true : (e2 = a2 != null ? a2 === this.inputSummary.textAdded : !this.inputSummary.textAdded, n3 = u2 != null ? this.inputSummary.didDelete : !this.inputSummary.didDelete, c2 = (a2 === "\n" || a2 === " \n") && !e2, l2 = u2 === "\n" && !n3, s3 = c2 && !l2 || l2 && !c2, s3 && (o2 = this.getSelectedRange()) && (i2 = c2 ? a2.replace(/\n$/, "").length || -1 : (a2 != null ? a2.length : void 0) || 1, (r2 = this.responder) != null ? r2.positionIsBlockBreak(o2[1] + i2) : void 0) ? true : e2 && n3);
          }, s2.prototype.mutationIsSignificant = function(t3) {
            var e2, n3, i2;
            return i2 = Object.keys(t3).length > 0, e2 = ((n3 = this.compositionInput) != null ? n3.getEndData() : void 0) === "", i2 || !e2;
          }, s2.prototype.events = {keydown: function(t3) {
            var n3, i2, o2, r2, s3, c2, l2, h2, p2;
            if (this.isComposing() || this.resetInputSummary(), this.inputSummary.didInput = true, r2 = u[t3.keyCode]) {
              for (i2 = this.keys, h2 = ["ctrl", "alt", "shift", "meta"], o2 = 0, c2 = h2.length; c2 > o2; o2++)
                l2 = h2[o2], t3[l2 + "Key"] && (l2 === "ctrl" && (l2 = "control"), i2 = i2 != null ? i2[l2] : void 0);
              (i2 != null ? i2[r2] : void 0) != null && (this.setInputSummary({keyName: r2}), e.selectionChangeObserver.reset(), i2[r2].call(this, t3));
            }
            return a(t3) && (n3 = String.fromCharCode(t3.keyCode).toLowerCase()) && (s3 = function() {
              var e2, n4, i3, o3;
              for (i3 = ["alt", "shift"], o3 = [], e2 = 0, n4 = i3.length; n4 > e2; e2++)
                l2 = i3[e2], t3[l2 + "Key"] && o3.push(l2);
              return o3;
            }(), s3.push(n3), (p2 = this.delegate) != null ? p2.inputControllerDidReceiveKeyboardCommand(s3) : void 0) ? t3.preventDefault() : void 0;
          }, keypress: function(t3) {
            var e2, n3, i2;
            if (this.inputSummary.eventName == null && !t3.metaKey && (!t3.ctrlKey || t3.altKey))
              return (i2 = p(t3)) ? ((e2 = this.delegate) != null && e2.inputControllerWillPerformTyping(), (n3 = this.responder) != null && n3.insertString(i2), this.setInputSummary({textAdded: i2, didDelete: this.selectionIsExpanded()})) : void 0;
          }, textInput: function(t3) {
            var e2, n3, i2, o2;
            return e2 = t3.data, o2 = this.inputSummary.textAdded, o2 && o2 !== e2 && o2.toUpperCase() === e2 ? (n3 = this.getSelectedRange(), this.setSelectedRange([n3[0], n3[1] + o2.length]), (i2 = this.responder) != null && i2.insertString(e2), this.setInputSummary({textAdded: e2}), this.setSelectedRange(n3)) : void 0;
          }, dragenter: function(t3) {
            return t3.preventDefault();
          }, dragstart: function(t3) {
            var e2, n3;
            return n3 = t3.target, this.serializeSelectionToDataTransfer(t3.dataTransfer), this.draggedRange = this.getSelectedRange(), (e2 = this.delegate) != null && typeof e2.inputControllerDidStartDrag == "function" ? e2.inputControllerDidStartDrag() : void 0;
          }, dragover: function(t3) {
            var e2, n3;
            return !this.draggedRange && !this.canAcceptDataTransfer(t3.dataTransfer) || (t3.preventDefault(), e2 = {x: t3.clientX, y: t3.clientY}, l(e2, this.draggingPoint)) ? void 0 : (this.draggingPoint = e2, (n3 = this.delegate) != null && typeof n3.inputControllerDidReceiveDragOverPoint == "function" ? n3.inputControllerDidReceiveDragOverPoint(this.draggingPoint) : void 0);
          }, dragend: function() {
            var t3;
            return (t3 = this.delegate) != null && typeof t3.inputControllerDidCancelDrag == "function" && t3.inputControllerDidCancelDrag(), this.draggedRange = null, this.draggingPoint = null;
          }, drop: function(t3) {
            var n3, i2, o2, r2, s3, a2, u2, c2, l2;
            return t3.preventDefault(), o2 = (s3 = t3.dataTransfer) != null ? s3.files : void 0, r2 = {x: t3.clientX, y: t3.clientY}, (a2 = this.responder) != null && a2.setLocationRangeFromPointRange(r2), (o2 != null ? o2.length : void 0) ? this.attachFiles(o2) : this.draggedRange ? ((u2 = this.delegate) != null && u2.inputControllerWillMoveText(), (c2 = this.responder) != null && c2.moveTextFromRange(this.draggedRange), this.draggedRange = null, this.requestRender()) : (i2 = t3.dataTransfer.getData("application/x-trix-document")) && (n3 = e.Document.fromJSONString(i2), (l2 = this.responder) != null && l2.insertDocument(n3), this.requestRender()), this.draggedRange = null, this.draggingPoint = null;
          }, cut: function(t3) {
            var e2, n3;
            return ((e2 = this.responder) != null ? e2.selectionIsExpanded() : void 0) && (this.serializeSelectionToDataTransfer(t3.clipboardData) && t3.preventDefault(), (n3 = this.delegate) != null && n3.inputControllerWillCutText(), this.deleteInDirection("backward"), t3.defaultPrevented) ? this.requestRender() : void 0;
          }, copy: function(t3) {
            var e2;
            return ((e2 = this.responder) != null ? e2.selectionIsExpanded() : void 0) && this.serializeSelectionToDataTransfer(t3.clipboardData) ? t3.preventDefault() : void 0;
          }, paste: function(t3) {
            var n3, o2, s3, a2, u2, c2, l2, p2, f2, g2, v, y, b, A, C, x, w, E, S, R, k, D, L;
            return n3 = (p2 = t3.clipboardData) != null ? p2 : t3.testClipboardData, l2 = {clipboard: n3}, n3 == null || h(t3) ? void this.getPastedHTMLUsingHiddenElement(function(t4) {
              return function(e2) {
                var n4, i2, o3;
                return l2.type = "text/html", l2.html = e2, (n4 = t4.delegate) != null && n4.inputControllerWillPaste(l2), (i2 = t4.responder) != null && i2.insertHTML(l2.html), t4.requestRender(), (o3 = t4.delegate) != null ? o3.inputControllerDidPaste(l2) : void 0;
              };
            }(this)) : ((a2 = n3.getData("URL")) ? (l2.type = "text/html", L = (c2 = n3.getData("public.url-name")) ? e.squishBreakableWhitespace(c2).trim() : a2, l2.html = this.createLinkHTML(a2, L), (f2 = this.delegate) != null && f2.inputControllerWillPaste(l2), this.setInputSummary({textAdded: L, didDelete: this.selectionIsExpanded()}), (C = this.responder) != null && C.insertHTML(l2.html), this.requestRender(), (x = this.delegate) != null && x.inputControllerDidPaste(l2)) : i(n3) ? (l2.type = "text/plain", l2.string = n3.getData("text/plain"), (w = this.delegate) != null && w.inputControllerWillPaste(l2), this.setInputSummary({textAdded: l2.string, didDelete: this.selectionIsExpanded()}), (E = this.responder) != null && E.insertString(l2.string), this.requestRender(), (S = this.delegate) != null && S.inputControllerDidPaste(l2)) : (u2 = n3.getData("text/html")) ? (l2.type = "text/html", l2.html = u2, (R = this.delegate) != null && R.inputControllerWillPaste(l2), (k = this.responder) != null && k.insertHTML(l2.html), this.requestRender(), (D = this.delegate) != null && D.inputControllerDidPaste(l2)) : m.call(n3.types, "Files") >= 0 && (s3 = (g2 = n3.items) != null && (v = g2[0]) != null && typeof v.getAsFile == "function" ? v.getAsFile() : void 0) && (!s3.name && (o2 = r(s3)) && (s3.name = "pasted-file-" + ++d2 + "." + o2), l2.type = "File", l2.file = s3, (y = this.delegate) != null && y.inputControllerWillAttachFiles(), (b = this.responder) != null && b.insertFile(l2.file), this.requestRender(), (A = this.delegate) != null && A.inputControllerDidPaste(l2)), t3.preventDefault());
          }, compositionstart: function(t3) {
            return this.getCompositionInput().start(t3.data);
          }, compositionupdate: function(t3) {
            return this.getCompositionInput().update(t3.data);
          }, compositionend: function(t3) {
            return this.getCompositionInput().end(t3.data);
          }, beforeinput: function() {
            return this.inputSummary.didInput = true;
          }, input: function(t3) {
            return this.inputSummary.didInput = true, t3.stopPropagation();
          }}, s2.prototype.keys = {backspace: function(t3) {
            var e2;
            return (e2 = this.delegate) != null && e2.inputControllerWillPerformTyping(), this.deleteInDirection("backward", t3);
          }, delete: function(t3) {
            var e2;
            return (e2 = this.delegate) != null && e2.inputControllerWillPerformTyping(), this.deleteInDirection("forward", t3);
          }, return: function() {
            var t3, e2;
            return this.setInputSummary({preferDocument: true}), (t3 = this.delegate) != null && t3.inputControllerWillPerformTyping(), (e2 = this.responder) != null ? e2.insertLineBreak() : void 0;
          }, tab: function(t3) {
            var e2, n3;
            return ((e2 = this.responder) != null ? e2.canIncreaseNestingLevel() : void 0) ? ((n3 = this.responder) != null && n3.increaseNestingLevel(), this.requestRender(), t3.preventDefault()) : void 0;
          }, left: function(t3) {
            var e2;
            return this.selectionIsInCursorTarget() ? (t3.preventDefault(), (e2 = this.responder) != null ? e2.moveCursorInDirection("backward") : void 0) : void 0;
          }, right: function(t3) {
            var e2;
            return this.selectionIsInCursorTarget() ? (t3.preventDefault(), (e2 = this.responder) != null ? e2.moveCursorInDirection("forward") : void 0) : void 0;
          }, control: {d: function(t3) {
            var e2;
            return (e2 = this.delegate) != null && e2.inputControllerWillPerformTyping(), this.deleteInDirection("forward", t3);
          }, h: function(t3) {
            var e2;
            return (e2 = this.delegate) != null && e2.inputControllerWillPerformTyping(), this.deleteInDirection("backward", t3);
          }, o: function(t3) {
            var e2, n3;
            return t3.preventDefault(), (e2 = this.delegate) != null && e2.inputControllerWillPerformTyping(), (n3 = this.responder) != null && n3.insertString("\n", {updatePosition: false}), this.requestRender();
          }}, shift: {return: function(t3) {
            var e2, n3;
            return (e2 = this.delegate) != null && e2.inputControllerWillPerformTyping(), (n3 = this.responder) != null && n3.insertString("\n"), this.requestRender(), t3.preventDefault();
          }, tab: function(t3) {
            var e2, n3;
            return ((e2 = this.responder) != null ? e2.canDecreaseNestingLevel() : void 0) ? ((n3 = this.responder) != null && n3.decreaseNestingLevel(), this.requestRender(), t3.preventDefault()) : void 0;
          }, left: function(t3) {
            return this.selectionIsInCursorTarget() ? (t3.preventDefault(), this.expandSelectionInDirection("backward")) : void 0;
          }, right: function(t3) {
            return this.selectionIsInCursorTarget() ? (t3.preventDefault(), this.expandSelectionInDirection("forward")) : void 0;
          }}, alt: {backspace: function() {
            var t3;
            return this.setInputSummary({preferDocument: false}), (t3 = this.delegate) != null ? t3.inputControllerWillPerformTyping() : void 0;
          }}, meta: {backspace: function() {
            var t3;
            return this.setInputSummary({preferDocument: false}), (t3 = this.delegate) != null ? t3.inputControllerWillPerformTyping() : void 0;
          }}}, s2.prototype.getCompositionInput = function() {
            return this.isComposing() ? this.compositionInput : this.compositionInput = new t2(this);
          }, s2.prototype.isComposing = function() {
            return this.compositionInput != null && !this.compositionInput.isEnded();
          }, s2.prototype.deleteInDirection = function(t3, e2) {
            var n3;
            return ((n3 = this.responder) != null ? n3.deleteInDirection(t3) : void 0) !== false ? this.setInputSummary({didDelete: true}) : e2 ? (e2.preventDefault(), this.requestRender()) : void 0;
          }, s2.prototype.serializeSelectionToDataTransfer = function(t3) {
            var n3, i2;
            if (o(t3))
              return n3 = (i2 = this.responder) != null ? i2.getSelectedDocument().toSerializableDocument() : void 0, t3.setData("application/x-trix-document", JSON.stringify(n3)), t3.setData("text/html", e.DocumentView.render(n3).innerHTML), t3.setData("text/plain", n3.toString().replace(/\n$/, "")), true;
          }, s2.prototype.canAcceptDataTransfer = function(t3) {
            var e2, n3, i2, o2, r2, s3;
            for (s3 = {}, o2 = (i2 = t3 != null ? t3.types : void 0) != null ? i2 : [], e2 = 0, n3 = o2.length; n3 > e2; e2++)
              r2 = o2[e2], s3[r2] = true;
            return s3.Files || s3["application/x-trix-document"] || s3["text/html"] || s3["text/plain"];
          }, s2.prototype.getPastedHTMLUsingHiddenElement = function(t3) {
            var n3, i2, o2;
            return i2 = this.getSelectedRange(), o2 = {position: "absolute", left: window.pageXOffset + "px", top: window.pageYOffset + "px", opacity: 0}, n3 = c({style: o2, tagName: "div", editable: true}), document.body.appendChild(n3), n3.focus(), requestAnimationFrame(function(o3) {
              return function() {
                var r2;
                return r2 = n3.innerHTML, e.removeNode(n3), o3.setSelectedRange(i2), t3(r2);
              };
            }(this));
          }, s2.proxyMethod("responder?.getSelectedRange"), s2.proxyMethod("responder?.setSelectedRange"), s2.proxyMethod("responder?.expandSelectionInDirection"), s2.proxyMethod("responder?.selectionIsInCursorTarget"), s2.proxyMethod("responder?.selectionIsExpanded"), s2;
        }(e.InputController), r = function(t3) {
          var e2, n2;
          return (e2 = t3.type) != null && (n2 = e2.match(/\/(\w+)$/)) != null ? n2[1] : void 0;
        }, s = (typeof " ".codePointAt == "function" ? " ".codePointAt(0) : void 0) != null, p = function(t3) {
          var n2;
          return t3.key && s && t3.key.codePointAt(0) === t3.keyCode ? t3.key : (t3.which === null ? n2 = t3.keyCode : t3.which !== 0 && t3.charCode !== 0 && (n2 = t3.charCode), n2 != null && u[n2] !== "escape" ? e.UTF16String.fromCodepoints([n2]).toString() : void 0);
        }, h = function(t3) {
          var e2, n2, i2, o2, r2, s2, a2, u2, c2, l2;
          if (u2 = t3.clipboardData) {
            if (m.call(u2.types, "text/html") >= 0) {
              for (c2 = u2.types, i2 = 0, s2 = c2.length; s2 > i2; i2++)
                if (l2 = c2[i2], e2 = /^CorePasteboardFlavorType/.test(l2), n2 = /^dyn\./.test(l2) && u2.getData(l2), a2 = e2 || n2)
                  return true;
              return false;
            }
            return o2 = m.call(u2.types, "com.apple.webarchive") >= 0, r2 = m.call(u2.types, "com.apple.flat-rtfd") >= 0, o2 || r2;
          }
        }, t2 = function(t3) {
          function e2(t4) {
            var e3;
            this.inputController = t4, e3 = this.inputController, this.responder = e3.responder, this.delegate = e3.delegate, this.inputSummary = e3.inputSummary, this.data = {};
          }
          return f(e2, t3), e2.prototype.start = function(t4) {
            var e3, n2;
            return this.data.start = t4, this.isSignificant() ? (this.inputSummary.eventName === "keypress" && this.inputSummary.textAdded && (e3 = this.responder) != null && e3.deleteInDirection("left"), this.selectionIsExpanded() || (this.insertPlaceholder(), this.requestRender()), this.range = (n2 = this.responder) != null ? n2.getSelectedRange() : void 0) : void 0;
          }, e2.prototype.update = function(t4) {
            var e3;
            return this.data.update = t4, this.isSignificant() && (e3 = this.selectPlaceholder()) ? (this.forgetPlaceholder(), this.range = e3) : void 0;
          }, e2.prototype.end = function(t4) {
            var e3, n2, i2, o2;
            return this.data.end = t4, this.isSignificant() ? (this.forgetPlaceholder(), this.canApplyToDocument() ? (this.setInputSummary({preferDocument: true, didInput: false}), (e3 = this.delegate) != null && e3.inputControllerWillPerformTyping(), (n2 = this.responder) != null && n2.setSelectedRange(this.range), (i2 = this.responder) != null && i2.insertString(this.data.end), (o2 = this.responder) != null ? o2.setSelectedRange(this.range[0] + this.data.end.length) : void 0) : this.data.start != null || this.data.update != null ? (this.requestReparse(), this.inputController.reset()) : void 0) : this.inputController.reset();
          }, e2.prototype.getEndData = function() {
            return this.data.end;
          }, e2.prototype.isEnded = function() {
            return this.getEndData() != null;
          }, e2.prototype.isSignificant = function() {
            return n.composesExistingText ? this.inputSummary.didInput : true;
          }, e2.prototype.canApplyToDocument = function() {
            var t4, e3;
            return ((t4 = this.data.start) != null ? t4.length : void 0) === 0 && ((e3 = this.data.end) != null ? e3.length : void 0) > 0 && this.range != null;
          }, e2.proxyMethod("inputController.setInputSummary"), e2.proxyMethod("inputController.requestRender"), e2.proxyMethod("inputController.requestReparse"), e2.proxyMethod("responder?.selectionIsExpanded"), e2.proxyMethod("responder?.insertPlaceholder"), e2.proxyMethod("responder?.selectPlaceholder"), e2.proxyMethod("responder?.forgetPlaceholder"), e2;
        }(e.BasicObject);
      }.call(this), function() {
        var t2, n, i, o = function(t3, e2) {
          return function() {
            return t3.apply(e2, arguments);
          };
        }, r = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var i2 in e2)
            s.call(e2, i2) && (t3[i2] = e2[i2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, s = {}.hasOwnProperty, a = [].indexOf || function(t3) {
          for (var e2 = 0, n2 = this.length; n2 > e2; e2++)
            if (e2 in this && this[e2] === t3)
              return e2;
          return -1;
        };
        t2 = e.dataTransferIsPlainText, n = e.keyEventIsKeyboardCommand, i = e.objectsAreEqual, e.Level2InputController = function(s2) {
          function u() {
            return this.render = o(this.render, this), u.__super__.constructor.apply(this, arguments);
          }
          var c, l, h, p, d, f;
          return r(u, s2), u.prototype.elementDidMutate = function() {
            var t3;
            return this.scheduledRender ? this.composing && (t3 = this.delegate) != null && typeof t3.inputControllerDidAllowUnhandledInput == "function" ? t3.inputControllerDidAllowUnhandledInput() : void 0 : this.reparse();
          }, u.prototype.scheduleRender = function() {
            return this.scheduledRender != null ? this.scheduledRender : this.scheduledRender = requestAnimationFrame(this.render);
          }, u.prototype.render = function() {
            var t3;
            return cancelAnimationFrame(this.scheduledRender), this.scheduledRender = null, this.composing || (t3 = this.delegate) != null && t3.render(), typeof this.afterRender == "function" && this.afterRender(), this.afterRender = null;
          }, u.prototype.reparse = function() {
            var t3;
            return (t3 = this.delegate) != null ? t3.reparse() : void 0;
          }, u.prototype.events = {keydown: function(t3) {
            var e2, i2, o2, r2;
            if (n(t3)) {
              if (e2 = l(t3), (r2 = this.delegate) != null ? r2.inputControllerDidReceiveKeyboardCommand(e2) : void 0)
                return t3.preventDefault();
            } else if (o2 = t3.key, t3.altKey && (o2 += "+Alt"), t3.shiftKey && (o2 += "+Shift"), i2 = this.keys[o2])
              return this.withEvent(t3, i2);
          }, paste: function(t3) {
            var e2, n2, i2, o2, r2, s3, a2, u2, c2;
            return h(t3) ? (t3.preventDefault(), this.attachFiles(t3.clipboardData.files)) : p(t3) ? (t3.preventDefault(), n2 = {type: "text/plain", string: t3.clipboardData.getData("text/plain")}, (i2 = this.delegate) != null && i2.inputControllerWillPaste(n2), (o2 = this.responder) != null && o2.insertString(n2.string), this.render(), (r2 = this.delegate) != null ? r2.inputControllerDidPaste(n2) : void 0) : (e2 = (s3 = t3.clipboardData) != null ? s3.getData("URL") : void 0) ? (t3.preventDefault(), n2 = {type: "text/html", html: this.createLinkHTML(e2)}, (a2 = this.delegate) != null && a2.inputControllerWillPaste(n2), (u2 = this.responder) != null && u2.insertHTML(n2.html), this.render(), (c2 = this.delegate) != null ? c2.inputControllerDidPaste(n2) : void 0) : void 0;
          }, beforeinput: function(t3) {
            var e2;
            return (e2 = this.inputTypes[t3.inputType]) ? (this.withEvent(t3, e2), this.scheduleRender()) : void 0;
          }, input: function() {
            return e.selectionChangeObserver.reset();
          }, dragstart: function(t3) {
            var e2, n2;
            return ((e2 = this.responder) != null ? e2.selectionContainsAttachments() : void 0) ? (t3.dataTransfer.setData("application/x-trix-dragging", true), this.dragging = {range: (n2 = this.responder) != null ? n2.getSelectedRange() : void 0, point: d(t3)}) : void 0;
          }, dragenter: function(t3) {
            return c(t3) ? t3.preventDefault() : void 0;
          }, dragover: function(t3) {
            var e2, n2;
            if (this.dragging) {
              if (t3.preventDefault(), e2 = d(t3), !i(e2, this.dragging.point))
                return this.dragging.point = e2, (n2 = this.responder) != null ? n2.setLocationRangeFromPointRange(e2) : void 0;
            } else if (c(t3))
              return t3.preventDefault();
          }, drop: function(t3) {
            var e2, n2, i2, o2;
            return this.dragging ? (t3.preventDefault(), (n2 = this.delegate) != null && n2.inputControllerWillMoveText(), (i2 = this.responder) != null && i2.moveTextFromRange(this.dragging.range), this.dragging = null, this.scheduleRender()) : c(t3) ? (t3.preventDefault(), e2 = d(t3), (o2 = this.responder) != null && o2.setLocationRangeFromPointRange(e2), this.attachFiles(t3.dataTransfer.files)) : void 0;
          }, dragend: function() {
            var t3;
            return this.dragging ? ((t3 = this.responder) != null && t3.setSelectedRange(this.dragging.range), this.dragging = null) : void 0;
          }, compositionend: function() {
            return this.composing ? (this.composing = false, this.scheduleRender()) : void 0;
          }}, u.prototype.keys = {ArrowLeft: function() {
            var t3, e2;
            return ((t3 = this.responder) != null ? t3.shouldManageMovingCursorInDirection("backward") : void 0) ? (this.event.preventDefault(), (e2 = this.responder) != null ? e2.moveCursorInDirection("backward") : void 0) : void 0;
          }, ArrowRight: function() {
            var t3, e2;
            return ((t3 = this.responder) != null ? t3.shouldManageMovingCursorInDirection("forward") : void 0) ? (this.event.preventDefault(), (e2 = this.responder) != null ? e2.moveCursorInDirection("forward") : void 0) : void 0;
          }, Backspace: function() {
            var t3, e2, n2;
            return ((t3 = this.responder) != null ? t3.shouldManageDeletingInDirection("backward") : void 0) ? (this.event.preventDefault(), (e2 = this.delegate) != null && e2.inputControllerWillPerformTyping(), (n2 = this.responder) != null && n2.deleteInDirection("backward"), this.render()) : void 0;
          }, Tab: function() {
            var t3, e2;
            return ((t3 = this.responder) != null ? t3.canIncreaseNestingLevel() : void 0) ? (this.event.preventDefault(), (e2 = this.responder) != null && e2.increaseNestingLevel(), this.render()) : void 0;
          }, "Tab+Shift": function() {
            var t3, e2;
            return ((t3 = this.responder) != null ? t3.canDecreaseNestingLevel() : void 0) ? (this.event.preventDefault(), (e2 = this.responder) != null && e2.decreaseNestingLevel(), this.render()) : void 0;
          }}, u.prototype.inputTypes = {deleteByComposition: function() {
            return this.deleteInDirection("backward", {recordUndoEntry: false});
          }, deleteByCut: function() {
            return this.deleteInDirection("backward");
          }, deleteByDrag: function() {
            return this.event.preventDefault(), this.withTargetDOMRange(function() {
              var t3;
              return this.deleteByDragRange = (t3 = this.responder) != null ? t3.getSelectedRange() : void 0;
            });
          }, deleteCompositionText: function() {
            return this.deleteInDirection("backward", {recordUndoEntry: false});
          }, deleteContent: function() {
            return this.deleteInDirection("backward");
          }, deleteContentBackward: function() {
            return this.deleteInDirection("backward");
          }, deleteContentForward: function() {
            return this.deleteInDirection("forward");
          }, deleteEntireSoftLine: function() {
            return this.deleteInDirection("forward");
          }, deleteHardLineBackward: function() {
            return this.deleteInDirection("backward");
          }, deleteHardLineForward: function() {
            return this.deleteInDirection("forward");
          }, deleteSoftLineBackward: function() {
            return this.deleteInDirection("backward");
          }, deleteSoftLineForward: function() {
            return this.deleteInDirection("forward");
          }, deleteWordBackward: function() {
            return this.deleteInDirection("backward");
          }, deleteWordForward: function() {
            return this.deleteInDirection("forward");
          }, formatBackColor: function() {
            return this.activateAttributeIfSupported("backgroundColor", this.event.data);
          }, formatBold: function() {
            return this.toggleAttributeIfSupported("bold");
          }, formatFontColor: function() {
            return this.activateAttributeIfSupported("color", this.event.data);
          }, formatFontName: function() {
            return this.activateAttributeIfSupported("font", this.event.data);
          }, formatIndent: function() {
            var t3;
            return ((t3 = this.responder) != null ? t3.canIncreaseNestingLevel() : void 0) ? this.withTargetDOMRange(function() {
              var t4;
              return (t4 = this.responder) != null ? t4.increaseNestingLevel() : void 0;
            }) : void 0;
          }, formatItalic: function() {
            return this.toggleAttributeIfSupported("italic");
          }, formatJustifyCenter: function() {
            return this.toggleAttributeIfSupported("justifyCenter");
          }, formatJustifyFull: function() {
            return this.toggleAttributeIfSupported("justifyFull");
          }, formatJustifyLeft: function() {
            return this.toggleAttributeIfSupported("justifyLeft");
          }, formatJustifyRight: function() {
            return this.toggleAttributeIfSupported("justifyRight");
          }, formatOutdent: function() {
            var t3;
            return ((t3 = this.responder) != null ? t3.canDecreaseNestingLevel() : void 0) ? this.withTargetDOMRange(function() {
              var t4;
              return (t4 = this.responder) != null ? t4.decreaseNestingLevel() : void 0;
            }) : void 0;
          }, formatRemove: function() {
            return this.withTargetDOMRange(function() {
              var t3, e2, n2, i2;
              i2 = [];
              for (t3 in (e2 = this.responder) != null ? e2.getCurrentAttributes() : void 0)
                i2.push((n2 = this.responder) != null ? n2.removeCurrentAttribute(t3) : void 0);
              return i2;
            });
          }, formatSetBlockTextDirection: function() {
            return this.activateAttributeIfSupported("blockDir", this.event.data);
          }, formatSetInlineTextDirection: function() {
            return this.activateAttributeIfSupported("textDir", this.event.data);
          }, formatStrikeThrough: function() {
            return this.toggleAttributeIfSupported("strike");
          }, formatSubscript: function() {
            return this.toggleAttributeIfSupported("sub");
          }, formatSuperscript: function() {
            return this.toggleAttributeIfSupported("sup");
          }, formatUnderline: function() {
            return this.toggleAttributeIfSupported("underline");
          }, historyRedo: function() {
            var t3;
            return (t3 = this.delegate) != null ? t3.inputControllerWillPerformRedo() : void 0;
          }, historyUndo: function() {
            var t3;
            return (t3 = this.delegate) != null ? t3.inputControllerWillPerformUndo() : void 0;
          }, insertCompositionText: function() {
            return this.composing = true, this.insertString(this.event.data);
          }, insertFromComposition: function() {
            return this.composing = false, this.insertString(this.event.data);
          }, insertFromDrop: function() {
            var t3, e2;
            return (t3 = this.deleteByDragRange) ? (this.deleteByDragRange = null, (e2 = this.delegate) != null && e2.inputControllerWillMoveText(), this.withTargetDOMRange(function() {
              var e3;
              return (e3 = this.responder) != null ? e3.moveTextFromRange(t3) : void 0;
            })) : void 0;
          }, insertFromPaste: function() {
            var n2, i2, o2, r2, s3, a2, u2, c2, l2, h2, p2;
            return n2 = this.event.dataTransfer, s3 = {dataTransfer: n2}, (i2 = n2.getData("URL")) ? (this.event.preventDefault(), s3.type = "text/html", p2 = (r2 = n2.getData("public.url-name")) ? e.squishBreakableWhitespace(r2).trim() : i2, s3.html = this.createLinkHTML(i2, p2), (a2 = this.delegate) != null && a2.inputControllerWillPaste(s3), this.withTargetDOMRange(function() {
              var t3;
              return (t3 = this.responder) != null ? t3.insertHTML(s3.html) : void 0;
            }), this.afterRender = function(t3) {
              return function() {
                var e2;
                return (e2 = t3.delegate) != null ? e2.inputControllerDidPaste(s3) : void 0;
              };
            }(this)) : t2(n2) ? (s3.type = "text/plain", s3.string = n2.getData("text/plain"), (u2 = this.delegate) != null && u2.inputControllerWillPaste(s3), this.withTargetDOMRange(function() {
              var t3;
              return (t3 = this.responder) != null ? t3.insertString(s3.string) : void 0;
            }), this.afterRender = function(t3) {
              return function() {
                var e2;
                return (e2 = t3.delegate) != null ? e2.inputControllerDidPaste(s3) : void 0;
              };
            }(this)) : (o2 = n2.getData("text/html")) ? (this.event.preventDefault(), s3.type = "text/html", s3.html = o2, (c2 = this.delegate) != null && c2.inputControllerWillPaste(s3), this.withTargetDOMRange(function() {
              var t3;
              return (t3 = this.responder) != null ? t3.insertHTML(s3.html) : void 0;
            }), this.afterRender = function(t3) {
              return function() {
                var e2;
                return (e2 = t3.delegate) != null ? e2.inputControllerDidPaste(s3) : void 0;
              };
            }(this)) : ((l2 = n2.files) != null ? l2.length : void 0) ? (s3.type = "File", s3.file = n2.files[0], (h2 = this.delegate) != null && h2.inputControllerWillPaste(s3), this.withTargetDOMRange(function() {
              var t3;
              return (t3 = this.responder) != null ? t3.insertFile(s3.file) : void 0;
            }), this.afterRender = function(t3) {
              return function() {
                var e2;
                return (e2 = t3.delegate) != null ? e2.inputControllerDidPaste(s3) : void 0;
              };
            }(this)) : void 0;
          }, insertFromYank: function() {
            return this.insertString(this.event.data);
          }, insertLineBreak: function() {
            return this.insertString("\n");
          }, insertLink: function() {
            return this.activateAttributeIfSupported("href", this.event.data);
          }, insertOrderedList: function() {
            return this.toggleAttributeIfSupported("number");
          }, insertParagraph: function() {
            var t3;
            return (t3 = this.delegate) != null && t3.inputControllerWillPerformTyping(), this.withTargetDOMRange(function() {
              var t4;
              return (t4 = this.responder) != null ? t4.insertLineBreak() : void 0;
            });
          }, insertReplacementText: function() {
            return this.insertString(this.event.dataTransfer.getData("text/plain"), {updatePosition: false});
          }, insertText: function() {
            var t3, e2;
            return this.insertString((t3 = this.event.data) != null ? t3 : (e2 = this.event.dataTransfer) != null ? e2.getData("text/plain") : void 0);
          }, insertTranspose: function() {
            return this.insertString(this.event.data);
          }, insertUnorderedList: function() {
            return this.toggleAttributeIfSupported("bullet");
          }}, u.prototype.insertString = function(t3, e2) {
            var n2;
            return t3 == null && (t3 = ""), (n2 = this.delegate) != null && n2.inputControllerWillPerformTyping(), this.withTargetDOMRange(function() {
              var n3;
              return (n3 = this.responder) != null ? n3.insertString(t3, e2) : void 0;
            });
          }, u.prototype.toggleAttributeIfSupported = function(t3) {
            var n2;
            return a.call(e.getAllAttributeNames(), t3) >= 0 ? ((n2 = this.delegate) != null && n2.inputControllerWillPerformFormatting(t3), this.withTargetDOMRange(function() {
              var e2;
              return (e2 = this.responder) != null ? e2.toggleCurrentAttribute(t3) : void 0;
            })) : void 0;
          }, u.prototype.activateAttributeIfSupported = function(t3, n2) {
            var i2;
            return a.call(e.getAllAttributeNames(), t3) >= 0 ? ((i2 = this.delegate) != null && i2.inputControllerWillPerformFormatting(t3), this.withTargetDOMRange(function() {
              var e2;
              return (e2 = this.responder) != null ? e2.setCurrentAttribute(t3, n2) : void 0;
            })) : void 0;
          }, u.prototype.deleteInDirection = function(t3, e2) {
            var n2, i2, o2, r2;
            return o2 = (e2 != null ? e2 : {recordUndoEntry: true}).recordUndoEntry, o2 && (r2 = this.delegate) != null && r2.inputControllerWillPerformTyping(), i2 = function(e3) {
              return function() {
                var n3;
                return (n3 = e3.responder) != null ? n3.deleteInDirection(t3) : void 0;
              };
            }(this), (n2 = this.getTargetDOMRange({minLength: 2})) ? this.withTargetDOMRange(n2, i2) : i2();
          }, u.prototype.withTargetDOMRange = function(t3, n2) {
            var i2;
            return typeof t3 == "function" && (n2 = t3, t3 = this.getTargetDOMRange()), t3 ? (i2 = this.responder) != null ? i2.withTargetDOMRange(t3, n2.bind(this)) : void 0 : (e.selectionChangeObserver.reset(), n2.call(this));
          }, u.prototype.getTargetDOMRange = function(t3) {
            var e2, n2, i2, o2;
            return i2 = (t3 != null ? t3 : {minLength: 0}).minLength, (o2 = typeof (e2 = this.event).getTargetRanges == "function" ? e2.getTargetRanges() : void 0) && o2.length && (n2 = f(o2[0]), i2 === 0 || n2.toString().length >= i2) ? n2 : void 0;
          }, f = function(t3) {
            var e2;
            return e2 = document.createRange(), e2.setStart(t3.startContainer, t3.startOffset), e2.setEnd(t3.endContainer, t3.endOffset), e2;
          }, u.prototype.withEvent = function(t3, e2) {
            var n2;
            this.event = t3;
            try {
              n2 = e2.call(this);
            } finally {
              this.event = null;
            }
            return n2;
          }, c = function(t3) {
            var e2, n2;
            return a.call((e2 = (n2 = t3.dataTransfer) != null ? n2.types : void 0) != null ? e2 : [], "Files") >= 0;
          }, h = function(t3) {
            var e2;
            return (e2 = t3.clipboardData) ? a.call(e2.types, "Files") >= 0 && e2.types.length === 1 && e2.files.length >= 1 : void 0;
          }, p = function(t3) {
            var e2;
            return (e2 = t3.clipboardData) ? a.call(e2.types, "text/plain") >= 0 && e2.types.length === 1 : void 0;
          }, l = function(t3) {
            var e2;
            return e2 = [], t3.altKey && e2.push("alt"), t3.shiftKey && e2.push("shift"), e2.push(t3.key), e2;
          }, d = function(t3) {
            return {x: t3.clientX, y: t3.clientY};
          }, u;
        }(e.InputController);
      }.call(this), function() {
        var t2, n, i, o, r, s, a, u, c = function(t3, e2) {
          return function() {
            return t3.apply(e2, arguments);
          };
        }, l = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var i2 in e2)
            h.call(e2, i2) && (t3[i2] = e2[i2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, h = {}.hasOwnProperty;
        n = e.defer, i = e.handleEvent, s = e.makeElement, u = e.tagName, a = e.config, r = a.lang, t2 = a.css, o = a.keyNames, e.AttachmentEditorController = function(a2) {
          function h2(t3, e2, n2, i2) {
            this.attachmentPiece = t3, this.element = e2, this.container = n2, this.options = i2 != null ? i2 : {}, this.didBlurCaption = c(this.didBlurCaption, this), this.didChangeCaption = c(this.didChangeCaption, this), this.didInputCaption = c(this.didInputCaption, this), this.didKeyDownCaption = c(this.didKeyDownCaption, this), this.didClickActionButton = c(this.didClickActionButton, this), this.didClickToolbar = c(this.didClickToolbar, this), this.attachment = this.attachmentPiece.attachment, u(this.element) === "a" && (this.element = this.element.firstChild), this.install();
          }
          var p;
          return l(h2, a2), p = function(t3) {
            return function() {
              var e2;
              return e2 = t3.apply(this, arguments), e2["do"](), this.undos == null && (this.undos = []), this.undos.push(e2.undo);
            };
          }, h2.prototype.install = function() {
            return this.makeElementMutable(), this.addToolbar(), this.attachment.isPreviewable() ? this.installCaptionEditor() : void 0;
          }, h2.prototype.uninstall = function() {
            var t3, e2;
            for (this.savePendingCaption(); e2 = this.undos.pop(); )
              e2();
            return (t3 = this.delegate) != null ? t3.didUninstallAttachmentEditor(this) : void 0;
          }, h2.prototype.savePendingCaption = function() {
            var t3, e2, n2;
            return this.pendingCaption != null ? (t3 = this.pendingCaption, this.pendingCaption = null, t3 ? (e2 = this.delegate) != null && typeof e2.attachmentEditorDidRequestUpdatingAttributesForAttachment == "function" ? e2.attachmentEditorDidRequestUpdatingAttributesForAttachment({caption: t3}, this.attachment) : void 0 : (n2 = this.delegate) != null && typeof n2.attachmentEditorDidRequestRemovingAttributeForAttachment == "function" ? n2.attachmentEditorDidRequestRemovingAttributeForAttachment("caption", this.attachment) : void 0) : void 0;
          }, h2.prototype.makeElementMutable = p(function() {
            return {do: function(t3) {
              return function() {
                return t3.element.dataset.trixMutable = true;
              };
            }(this), undo: function(t3) {
              return function() {
                return delete t3.element.dataset.trixMutable;
              };
            }(this)};
          }), h2.prototype.addToolbar = p(function() {
            var n2;
            return n2 = s({tagName: "div", className: t2.attachmentToolbar, data: {trixMutable: true}, childNodes: s({tagName: "div", className: "trix-button-row", childNodes: s({tagName: "span", className: "trix-button-group trix-button-group--actions", childNodes: s({tagName: "button", className: "trix-button trix-button--remove", textContent: r.remove, attributes: {title: r.remove}, data: {trixAction: "remove"}})})})}), this.attachment.isPreviewable() && n2.appendChild(s({tagName: "div", className: t2.attachmentMetadataContainer, childNodes: s({tagName: "span", className: t2.attachmentMetadata, childNodes: [s({tagName: "span", className: t2.attachmentName, textContent: this.attachment.getFilename(), attributes: {title: this.attachment.getFilename()}}), s({tagName: "span", className: t2.attachmentSize, textContent: this.attachment.getFormattedFilesize()})]})})), i("click", {onElement: n2, withCallback: this.didClickToolbar}), i("click", {onElement: n2, matchingSelector: "[data-trix-action]", withCallback: this.didClickActionButton}), {do: function(t3) {
              return function() {
                return t3.element.appendChild(n2);
              };
            }(this), undo: function() {
              return function() {
                return e.removeNode(n2);
              };
            }()};
          }), h2.prototype.installCaptionEditor = p(function() {
            var o2, a3, u2, c2, l2;
            return c2 = s({tagName: "textarea", className: t2.attachmentCaptionEditor, attributes: {placeholder: r.captionPlaceholder}, data: {trixMutable: true}}), c2.value = this.attachmentPiece.getCaption(), l2 = c2.cloneNode(), l2.classList.add("trix-autoresize-clone"), l2.tabIndex = -1, o2 = function() {
              return l2.value = c2.value, c2.style.height = l2.scrollHeight + "px";
            }, i("input", {onElement: c2, withCallback: o2}), i("input", {onElement: c2, withCallback: this.didInputCaption}), i("keydown", {onElement: c2, withCallback: this.didKeyDownCaption}), i("change", {onElement: c2, withCallback: this.didChangeCaption}), i("blur", {onElement: c2, withCallback: this.didBlurCaption}), u2 = this.element.querySelector("figcaption"), a3 = u2.cloneNode(), {do: function(e2) {
              return function() {
                return u2.style.display = "none", a3.appendChild(c2), a3.appendChild(l2), a3.classList.add(t2.attachmentCaption + "--editing"), u2.parentElement.insertBefore(a3, u2), o2(), e2.options.editCaption ? n(function() {
                  return c2.focus();
                }) : void 0;
              };
            }(this), undo: function() {
              return e.removeNode(a3), u2.style.display = null;
            }};
          }), h2.prototype.didClickToolbar = function(t3) {
            return t3.preventDefault(), t3.stopPropagation();
          }, h2.prototype.didClickActionButton = function(t3) {
            var e2, n2;
            switch (e2 = t3.target.getAttribute("data-trix-action")) {
              case "remove":
                return (n2 = this.delegate) != null ? n2.attachmentEditorDidRequestRemovalOfAttachment(this.attachment) : void 0;
            }
          }, h2.prototype.didKeyDownCaption = function(t3) {
            var e2;
            return o[t3.keyCode] === "return" ? (t3.preventDefault(), this.savePendingCaption(), (e2 = this.delegate) != null && typeof e2.attachmentEditorDidRequestDeselectingAttachment == "function" ? e2.attachmentEditorDidRequestDeselectingAttachment(this.attachment) : void 0) : void 0;
          }, h2.prototype.didInputCaption = function(t3) {
            return this.pendingCaption = t3.target.value.replace(/\s/g, " ").trim();
          }, h2.prototype.didChangeCaption = function() {
            return this.savePendingCaption();
          }, h2.prototype.didBlurCaption = function() {
            return this.savePendingCaption();
          }, h2;
        }(e.BasicObject);
      }.call(this), function() {
        var t2, n, i, o = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var i2 in e2)
            r.call(e2, i2) && (t3[i2] = e2[i2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, r = {}.hasOwnProperty;
        i = e.makeElement, t2 = e.config.css, e.AttachmentView = function(r2) {
          function s() {
            s.__super__.constructor.apply(this, arguments), this.attachment = this.object, this.attachment.uploadProgressDelegate = this, this.attachmentPiece = this.options.piece;
          }
          var a;
          return o(s, r2), s.attachmentSelector = "[data-trix-attachment]", s.prototype.createContentNodes = function() {
            return [];
          }, s.prototype.createNodes = function() {
            var e2, n2, o2, r3, s2, u, c;
            if (e2 = r3 = i({tagName: "figure", className: this.getClassName(), data: this.getData(), editable: false}), (n2 = this.getHref()) && (r3 = i({tagName: "a", editable: false, attributes: {href: n2, tabindex: -1}}), e2.appendChild(r3)), this.attachment.hasContent())
              r3.innerHTML = this.attachment.getContent();
            else
              for (c = this.createContentNodes(), o2 = 0, s2 = c.length; s2 > o2; o2++)
                u = c[o2], r3.appendChild(u);
            return r3.appendChild(this.createCaptionElement()), this.attachment.isPending() && (this.progressElement = i({tagName: "progress", attributes: {class: t2.attachmentProgress, value: this.attachment.getUploadProgress(), max: 100}, data: {trixMutable: true, trixStoreKey: ["progressElement", this.attachment.id].join("/")}}), e2.appendChild(this.progressElement)), [a("left"), e2, a("right")];
          }, s.prototype.createCaptionElement = function() {
            var e2, n2, o2, r3, s2, a2, u;
            return o2 = i({tagName: "figcaption", className: t2.attachmentCaption}), (e2 = this.attachmentPiece.getCaption()) ? (o2.classList.add(t2.attachmentCaption + "--edited"), o2.textContent = e2) : (n2 = this.getCaptionConfig(), n2.name && (r3 = this.attachment.getFilename()), n2.size && (a2 = this.attachment.getFormattedFilesize()), r3 && (s2 = i({tagName: "span", className: t2.attachmentName, textContent: r3}), o2.appendChild(s2)), a2 && (r3 && o2.appendChild(document.createTextNode(" ")), u = i({tagName: "span", className: t2.attachmentSize, textContent: a2}), o2.appendChild(u))), o2;
          }, s.prototype.getClassName = function() {
            var e2, n2;
            return n2 = [t2.attachment, t2.attachment + "--" + this.attachment.getType()], (e2 = this.attachment.getExtension()) && n2.push(t2.attachment + "--" + e2), n2.join(" ");
          }, s.prototype.getData = function() {
            var t3, e2;
            return e2 = {trixAttachment: JSON.stringify(this.attachment), trixContentType: this.attachment.getContentType(), trixId: this.attachment.id}, t3 = this.attachmentPiece.attributes, t3.isEmpty() || (e2.trixAttributes = JSON.stringify(t3)), this.attachment.isPending() && (e2.trixSerialize = false), e2;
          }, s.prototype.getHref = function() {
            return n(this.attachment.getContent(), "a") ? void 0 : this.attachment.getHref();
          }, s.prototype.getCaptionConfig = function() {
            var t3, n2, i2;
            return i2 = this.attachment.getType(), t3 = e.copyObject((n2 = e.config.attachments[i2]) != null ? n2.caption : void 0), i2 === "file" && (t3.name = true), t3;
          }, s.prototype.findProgressElement = function() {
            var t3;
            return (t3 = this.findElement()) != null ? t3.querySelector("progress") : void 0;
          }, a = function(t3) {
            return i({tagName: "span", textContent: e.ZERO_WIDTH_SPACE, data: {trixCursorTarget: t3, trixSerialize: false}});
          }, s.prototype.attachmentDidChangeUploadProgress = function() {
            var t3, e2;
            return e2 = this.attachment.getUploadProgress(), (t3 = this.findProgressElement()) != null ? t3.value = e2 : void 0;
          }, s;
        }(e.ObjectView), n = function(t3, e2) {
          var n2;
          return n2 = i("div"), n2.innerHTML = t3 != null ? t3 : "", n2.querySelector(e2);
        };
      }.call(this), function() {
        var t2, n = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var o in e2)
            i.call(e2, o) && (t3[o] = e2[o]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, i = {}.hasOwnProperty;
        t2 = e.makeElement, e.PreviewableAttachmentView = function(i2) {
          function o() {
            o.__super__.constructor.apply(this, arguments), this.attachment.previewDelegate = this;
          }
          return n(o, i2), o.prototype.createContentNodes = function() {
            return this.image = t2({tagName: "img", attributes: {src: ""}, data: {trixMutable: true}}), this.refresh(this.image), [this.image];
          }, o.prototype.createCaptionElement = function() {
            var t3;
            return t3 = o.__super__.createCaptionElement.apply(this, arguments), t3.textContent || t3.setAttribute("data-trix-placeholder", e.config.lang.captionPlaceholder), t3;
          }, o.prototype.refresh = function(t3) {
            var e2;
            return t3 == null && (t3 = (e2 = this.findElement()) != null ? e2.querySelector("img") : void 0), t3 ? this.updateAttributesForImage(t3) : void 0;
          }, o.prototype.updateAttributesForImage = function(t3) {
            var e2, n2, i3, o2, r, s;
            return r = this.attachment.getURL(), n2 = this.attachment.getPreviewURL(), t3.src = n2 || r, n2 === r ? t3.removeAttribute("data-trix-serialized-attributes") : (i3 = JSON.stringify({src: r}), t3.setAttribute("data-trix-serialized-attributes", i3)), s = this.attachment.getWidth(), e2 = this.attachment.getHeight(), s != null && (t3.width = s), e2 != null && (t3.height = e2), o2 = ["imageElement", this.attachment.id, t3.src, t3.width, t3.height].join("/"), t3.dataset.trixStoreKey = o2;
          }, o.prototype.attachmentDidChangeAttributes = function() {
            return this.refresh(this.image), this.refresh();
          }, o;
        }(e.AttachmentView);
      }.call(this), function() {
        var t2, n, i, o = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var i2 in e2)
            r.call(e2, i2) && (t3[i2] = e2[i2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, r = {}.hasOwnProperty;
        i = e.makeElement, t2 = e.findInnerElement, n = e.getTextConfig, e.PieceView = function(r2) {
          function s() {
            var t3;
            s.__super__.constructor.apply(this, arguments), this.piece = this.object, this.attributes = this.piece.getAttributes(), t3 = this.options, this.textConfig = t3.textConfig, this.context = t3.context, this.piece.attachment ? this.attachment = this.piece.attachment : this.string = this.piece.toString();
          }
          var a;
          return o(s, r2), s.prototype.createNodes = function() {
            var e2, n2, i2, o2, r3, s2;
            if (s2 = this.attachment ? this.createAttachmentNodes() : this.createStringNodes(), e2 = this.createElement()) {
              for (i2 = t2(e2), n2 = 0, o2 = s2.length; o2 > n2; n2++)
                r3 = s2[n2], i2.appendChild(r3);
              s2 = [e2];
            }
            return s2;
          }, s.prototype.createAttachmentNodes = function() {
            var t3, n2;
            return t3 = this.attachment.isPreviewable() ? e.PreviewableAttachmentView : e.AttachmentView, n2 = this.createChildView(t3, this.piece.attachment, {piece: this.piece}), n2.getNodes();
          }, s.prototype.createStringNodes = function() {
            var t3, e2, n2, o2, r3, s2, a2, u, c, l;
            if ((u = this.textConfig) != null ? u.plaintext : void 0)
              return [document.createTextNode(this.string)];
            for (a2 = [], c = this.string.split("\n"), n2 = e2 = 0, o2 = c.length; o2 > e2; n2 = ++e2)
              l = c[n2], n2 > 0 && (t3 = i("br"), a2.push(t3)), (r3 = l.length) && (s2 = document.createTextNode(this.preserveSpaces(l)), a2.push(s2));
            return a2;
          }, s.prototype.createElement = function() {
            var t3, e2, o2, r3, s2, a2, u, c, l;
            c = {}, a2 = this.attributes;
            for (r3 in a2)
              if (l = a2[r3], (t3 = n(r3)) && (t3.tagName && (s2 = i(t3.tagName), o2 ? (o2.appendChild(s2), o2 = s2) : e2 = o2 = s2), t3.styleProperty && (c[t3.styleProperty] = l), t3.style)) {
                u = t3.style;
                for (r3 in u)
                  l = u[r3], c[r3] = l;
              }
            if (Object.keys(c).length) {
              e2 == null && (e2 = i("span"));
              for (r3 in c)
                l = c[r3], e2.style[r3] = l;
            }
            return e2;
          }, s.prototype.createContainerElement = function() {
            var t3, e2, o2, r3, s2;
            r3 = this.attributes;
            for (o2 in r3)
              if (s2 = r3[o2], (e2 = n(o2)) && e2.groupTagName)
                return t3 = {}, t3[o2] = s2, i(e2.groupTagName, t3);
          }, a = e.NON_BREAKING_SPACE, s.prototype.preserveSpaces = function(t3) {
            return this.context.isLast && (t3 = t3.replace(/\ $/, a)), t3 = t3.replace(/(\S)\ {3}(\S)/g, "$1 " + a + " $2").replace(/\ {2}/g, a + " ").replace(/\ {2}/g, " " + a), (this.context.isFirst || this.context.followsWhitespace) && (t3 = t3.replace(/^\ /, a)), t3;
          }, s;
        }(e.ObjectView);
      }.call(this), function() {
        var t2 = function(t3, e2) {
          function i() {
            this.constructor = t3;
          }
          for (var o in e2)
            n.call(e2, o) && (t3[o] = e2[o]);
          return i.prototype = e2.prototype, t3.prototype = new i(), t3.__super__ = e2.prototype, t3;
        }, n = {}.hasOwnProperty;
        e.TextView = function(n2) {
          function i() {
            i.__super__.constructor.apply(this, arguments), this.text = this.object, this.textConfig = this.options.textConfig;
          }
          var o;
          return t2(i, n2), i.prototype.createNodes = function() {
            var t3, n3, i2, r, s, a, u, c, l, h;
            for (a = [], c = e.ObjectGroup.groupObjects(this.getPieces()), r = c.length - 1, i2 = n3 = 0, s = c.length; s > n3; i2 = ++n3)
              u = c[i2], t3 = {}, i2 === 0 && (t3.isFirst = true), i2 === r && (t3.isLast = true), o(l) && (t3.followsWhitespace = true), h = this.findOrCreateCachedChildView(e.PieceView, u, {textConfig: this.textConfig, context: t3}), a.push.apply(a, h.getNodes()), l = u;
            return a;
          }, i.prototype.getPieces = function() {
            var t3, e2, n3, i2, o2;
            for (i2 = this.text.getPieces(), o2 = [], t3 = 0, e2 = i2.length; e2 > t3; t3++)
              n3 = i2[t3], n3.hasAttribute("blockBreak") || o2.push(n3);
            return o2;
          }, o = function(t3) {
            return /\s$/.test(t3 != null ? t3.toString() : void 0);
          }, i;
        }(e.ObjectView);
      }.call(this), function() {
        var t2, n, i, o = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var i2 in e2)
            r.call(e2, i2) && (t3[i2] = e2[i2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, r = {}.hasOwnProperty;
        i = e.makeElement, n = e.getBlockConfig, t2 = e.config.css, e.BlockView = function(r2) {
          function s() {
            s.__super__.constructor.apply(this, arguments), this.block = this.object, this.attributes = this.block.getAttributes();
          }
          return o(s, r2), s.prototype.createNodes = function() {
            var t3, o2, r3, s2, a, u, c, l, h, p, d;
            if (o2 = document.createComment("block"), c = [o2], this.block.isEmpty() ? c.push(i("br")) : (p = (l = n(this.block.getLastAttribute())) != null ? l.text : void 0, d = this.findOrCreateCachedChildView(e.TextView, this.block.text, {textConfig: p}), c.push.apply(c, d.getNodes()), this.shouldAddExtraNewlineElement() && c.push(i("br"))), this.attributes.length)
              return c;
            for (h = e.config.blockAttributes["default"].tagName, this.block.isRTL() && (t3 = {dir: "rtl"}), r3 = i({tagName: h, attributes: t3}), s2 = 0, a = c.length; a > s2; s2++)
              u = c[s2], r3.appendChild(u);
            return [r3];
          }, s.prototype.createContainerElement = function(e2) {
            var o2, r3, s2, a, u;
            return o2 = this.attributes[e2], u = n(o2).tagName, e2 === 0 && this.block.isRTL() && (r3 = {dir: "rtl"}), o2 === "attachmentGallery" && (a = this.block.getBlockBreakPosition(), s2 = t2.attachmentGallery + " " + t2.attachmentGallery + "--" + a), i({tagName: u, className: s2, attributes: r3});
          }, s.prototype.shouldAddExtraNewlineElement = function() {
            return /\n\n$/.test(this.block.toString());
          }, s;
        }(e.ObjectView);
      }.call(this), function() {
        var t2, n, i = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var i2 in e2)
            o.call(e2, i2) && (t3[i2] = e2[i2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, o = {}.hasOwnProperty;
        t2 = e.defer, n = e.makeElement, e.DocumentView = function(o2) {
          function r() {
            r.__super__.constructor.apply(this, arguments), this.element = this.options.element, this.elementStore = new e.ElementStore(), this.setDocument(this.object);
          }
          var s, a, u;
          return i(r, o2), r.render = function(t3) {
            var e2, i2;
            return e2 = n("div"), i2 = new this(t3, {element: e2}), i2.render(), i2.sync(), e2;
          }, r.prototype.setDocument = function(t3) {
            return t3.isEqualTo(this.document) ? void 0 : this.document = this.object = t3;
          }, r.prototype.render = function() {
            var t3, i2, o3, r2, s2, a2, u2;
            if (this.childViews = [], this.shadowElement = n("div"), !this.document.isEmpty()) {
              for (s2 = e.ObjectGroup.groupObjects(this.document.getBlocks(), {asTree: true}), a2 = [], t3 = 0, i2 = s2.length; i2 > t3; t3++)
                r2 = s2[t3], u2 = this.findOrCreateCachedChildView(e.BlockView, r2), a2.push(function() {
                  var t4, e2, n2, i3;
                  for (n2 = u2.getNodes(), i3 = [], t4 = 0, e2 = n2.length; e2 > t4; t4++)
                    o3 = n2[t4], i3.push(this.shadowElement.appendChild(o3));
                  return i3;
                }.call(this));
              return a2;
            }
          }, r.prototype.isSynced = function() {
            return s(this.shadowElement, this.element);
          }, r.prototype.sync = function() {
            var t3;
            for (t3 = this.createDocumentFragmentForSync(); this.element.lastChild; )
              this.element.removeChild(this.element.lastChild);
            return this.element.appendChild(t3), this.didSync();
          }, r.prototype.didSync = function() {
            return this.elementStore.reset(a(this.element)), t2(function(t3) {
              return function() {
                return t3.garbageCollectCachedViews();
              };
            }(this));
          }, r.prototype.createDocumentFragmentForSync = function() {
            var t3, e2, n2, i2, o3, r2, s2, u2, c, l;
            for (e2 = document.createDocumentFragment(), u2 = this.shadowElement.childNodes, n2 = 0, o3 = u2.length; o3 > n2; n2++)
              s2 = u2[n2], e2.appendChild(s2.cloneNode(true));
            for (c = a(e2), i2 = 0, r2 = c.length; r2 > i2; i2++)
              t3 = c[i2], (l = this.elementStore.remove(t3)) && t3.parentNode.replaceChild(l, t3);
            return e2;
          }, a = function(t3) {
            return t3.querySelectorAll("[data-trix-store-key]");
          }, s = function(t3, e2) {
            return u(t3.innerHTML) === u(e2.innerHTML);
          }, u = function(t3) {
            return t3.replace(/&nbsp;/g, " ");
          }, r;
        }(e.ObjectView);
      }.call(this), function() {
        var t2, n, i, o, r, s = function(t3, e2) {
          return function() {
            return t3.apply(e2, arguments);
          };
        }, a = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var i2 in e2)
            u.call(e2, i2) && (t3[i2] = e2[i2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, u = {}.hasOwnProperty;
        i = e.findClosestElementFromNode, o = e.handleEvent, r = e.innerElementIsActive, n = e.defer, t2 = e.AttachmentView.attachmentSelector, e.CompositionController = function(u2) {
          function c(n2, i2) {
            this.element = n2, this.composition = i2, this.didClickAttachment = s(this.didClickAttachment, this), this.didBlur = s(this.didBlur, this), this.didFocus = s(this.didFocus, this), this.documentView = new e.DocumentView(this.composition.document, {element: this.element}), o("focus", {onElement: this.element, withCallback: this.didFocus}), o("blur", {onElement: this.element, withCallback: this.didBlur}), o("click", {onElement: this.element, matchingSelector: "a[contenteditable=false]", preventDefault: true}), o("mousedown", {onElement: this.element, matchingSelector: t2, withCallback: this.didClickAttachment}), o("click", {onElement: this.element, matchingSelector: "a" + t2, preventDefault: true});
          }
          return a(c, u2), c.prototype.didFocus = function() {
            var t3, e2, n2;
            return t3 = function(t4) {
              return function() {
                var e3;
                return t4.focused ? void 0 : (t4.focused = true, (e3 = t4.delegate) != null && typeof e3.compositionControllerDidFocus == "function" ? e3.compositionControllerDidFocus() : void 0);
              };
            }(this), (e2 = (n2 = this.blurPromise) != null ? n2.then(t3) : void 0) != null ? e2 : t3();
          }, c.prototype.didBlur = function() {
            return this.blurPromise = new Promise(function(t3) {
              return function(e2) {
                return n(function() {
                  var n2;
                  return r(t3.element) || (t3.focused = null, (n2 = t3.delegate) != null && typeof n2.compositionControllerDidBlur == "function" && n2.compositionControllerDidBlur()), t3.blurPromise = null, e2();
                });
              };
            }(this));
          }, c.prototype.didClickAttachment = function(t3, e2) {
            var n2, o2, r2;
            return n2 = this.findAttachmentForElement(e2), o2 = i(t3.target, {matchingSelector: "figcaption"}) != null, (r2 = this.delegate) != null && typeof r2.compositionControllerDidSelectAttachment == "function" ? r2.compositionControllerDidSelectAttachment(n2, {editCaption: o2}) : void 0;
          }, c.prototype.getSerializableElement = function() {
            return this.isEditingAttachment() ? this.documentView.shadowElement : this.element;
          }, c.prototype.render = function() {
            var t3, e2, n2;
            return this.revision !== this.composition.revision && (this.documentView.setDocument(this.composition.document), this.documentView.render(), this.revision = this.composition.revision), this.canSyncDocumentView() && !this.documentView.isSynced() && ((t3 = this.delegate) != null && typeof t3.compositionControllerWillSyncDocumentView == "function" && t3.compositionControllerWillSyncDocumentView(), this.documentView.sync(), (e2 = this.delegate) != null && typeof e2.compositionControllerDidSyncDocumentView == "function" && e2.compositionControllerDidSyncDocumentView()), (n2 = this.delegate) != null && typeof n2.compositionControllerDidRender == "function" ? n2.compositionControllerDidRender() : void 0;
          }, c.prototype.rerenderViewForObject = function(t3) {
            return this.invalidateViewForObject(t3), this.render();
          }, c.prototype.invalidateViewForObject = function(t3) {
            return this.documentView.invalidateViewForObject(t3);
          }, c.prototype.isViewCachingEnabled = function() {
            return this.documentView.isViewCachingEnabled();
          }, c.prototype.enableViewCaching = function() {
            return this.documentView.enableViewCaching();
          }, c.prototype.disableViewCaching = function() {
            return this.documentView.disableViewCaching();
          }, c.prototype.refreshViewCache = function() {
            return this.documentView.garbageCollectCachedViews();
          }, c.prototype.isEditingAttachment = function() {
            return this.attachmentEditor != null;
          }, c.prototype.installAttachmentEditorForAttachment = function(t3, n2) {
            var i2, o2, r2;
            if (((r2 = this.attachmentEditor) != null ? r2.attachment : void 0) !== t3 && (o2 = this.documentView.findElementForObject(t3)))
              return this.uninstallAttachmentEditor(), i2 = this.composition.document.getAttachmentPieceForAttachment(t3), this.attachmentEditor = new e.AttachmentEditorController(i2, o2, this.element, n2), this.attachmentEditor.delegate = this;
          }, c.prototype.uninstallAttachmentEditor = function() {
            var t3;
            return (t3 = this.attachmentEditor) != null ? t3.uninstall() : void 0;
          }, c.prototype.didUninstallAttachmentEditor = function() {
            return this.attachmentEditor = null, this.render();
          }, c.prototype.attachmentEditorDidRequestUpdatingAttributesForAttachment = function(t3, e2) {
            var n2;
            return (n2 = this.delegate) != null && typeof n2.compositionControllerWillUpdateAttachment == "function" && n2.compositionControllerWillUpdateAttachment(e2), this.composition.updateAttributesForAttachment(t3, e2);
          }, c.prototype.attachmentEditorDidRequestRemovingAttributeForAttachment = function(t3, e2) {
            var n2;
            return (n2 = this.delegate) != null && typeof n2.compositionControllerWillUpdateAttachment == "function" && n2.compositionControllerWillUpdateAttachment(e2), this.composition.removeAttributeForAttachment(t3, e2);
          }, c.prototype.attachmentEditorDidRequestRemovalOfAttachment = function(t3) {
            var e2;
            return (e2 = this.delegate) != null && typeof e2.compositionControllerDidRequestRemovalOfAttachment == "function" ? e2.compositionControllerDidRequestRemovalOfAttachment(t3) : void 0;
          }, c.prototype.attachmentEditorDidRequestDeselectingAttachment = function(t3) {
            var e2;
            return (e2 = this.delegate) != null && typeof e2.compositionControllerDidRequestDeselectingAttachment == "function" ? e2.compositionControllerDidRequestDeselectingAttachment(t3) : void 0;
          }, c.prototype.canSyncDocumentView = function() {
            return !this.isEditingAttachment();
          }, c.prototype.findAttachmentForElement = function(t3) {
            return this.composition.document.getAttachmentById(parseInt(t3.dataset.trixId, 10));
          }, c;
        }(e.BasicObject);
      }.call(this), function() {
        var t2, n, i, o = function(t3, e2) {
          return function() {
            return t3.apply(e2, arguments);
          };
        }, r = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var i2 in e2)
            s.call(e2, i2) && (t3[i2] = e2[i2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, s = {}.hasOwnProperty;
        n = e.handleEvent, i = e.triggerEvent, t2 = e.findClosestElementFromNode, e.ToolbarController = function(e2) {
          function s2(t3) {
            this.element = t3, this.didKeyDownDialogInput = o(this.didKeyDownDialogInput, this), this.didClickDialogButton = o(this.didClickDialogButton, this), this.didClickAttributeButton = o(this.didClickAttributeButton, this), this.didClickActionButton = o(this.didClickActionButton, this), this.attributes = {}, this.actions = {}, this.resetDialogInputs(), n("mousedown", {onElement: this.element, matchingSelector: a, withCallback: this.didClickActionButton}), n("mousedown", {onElement: this.element, matchingSelector: c, withCallback: this.didClickAttributeButton}), n("click", {onElement: this.element, matchingSelector: v, preventDefault: true}), n("click", {onElement: this.element, matchingSelector: l, withCallback: this.didClickDialogButton}), n("keydown", {onElement: this.element, matchingSelector: h, withCallback: this.didKeyDownDialogInput});
          }
          var a, u, c, l, h, p, d, f, g, m, v;
          return r(s2, e2), c = "[data-trix-attribute]", a = "[data-trix-action]", v = c + ", " + a, p = "[data-trix-dialog]", u = p + "[data-trix-active]", l = p + " [data-trix-method]", h = p + " [data-trix-input]", s2.prototype.didClickActionButton = function(t3, e3) {
            var n2, i2, o2;
            return (i2 = this.delegate) != null && i2.toolbarDidClickButton(), t3.preventDefault(), n2 = d(e3), this.getDialog(n2) ? this.toggleDialog(n2) : (o2 = this.delegate) != null ? o2.toolbarDidInvokeAction(n2) : void 0;
          }, s2.prototype.didClickAttributeButton = function(t3, e3) {
            var n2, i2, o2;
            return (i2 = this.delegate) != null && i2.toolbarDidClickButton(), t3.preventDefault(), n2 = f(e3), this.getDialog(n2) ? this.toggleDialog(n2) : (o2 = this.delegate) != null && o2.toolbarDidToggleAttribute(n2), this.refreshAttributeButtons();
          }, s2.prototype.didClickDialogButton = function(e3, n2) {
            var i2, o2;
            return i2 = t2(n2, {matchingSelector: p}), o2 = n2.getAttribute("data-trix-method"), this[o2].call(this, i2);
          }, s2.prototype.didKeyDownDialogInput = function(t3, e3) {
            var n2, i2;
            return t3.keyCode === 13 && (t3.preventDefault(), n2 = e3.getAttribute("name"), i2 = this.getDialog(n2), this.setAttribute(i2)), t3.keyCode === 27 ? (t3.preventDefault(), this.hideDialog()) : void 0;
          }, s2.prototype.updateActions = function(t3) {
            return this.actions = t3, this.refreshActionButtons();
          }, s2.prototype.refreshActionButtons = function() {
            return this.eachActionButton(function(t3) {
              return function(e3, n2) {
                return e3.disabled = t3.actions[n2] === false;
              };
            }(this));
          }, s2.prototype.eachActionButton = function(t3) {
            var e3, n2, i2, o2, r2;
            for (o2 = this.element.querySelectorAll(a), r2 = [], n2 = 0, i2 = o2.length; i2 > n2; n2++)
              e3 = o2[n2], r2.push(t3(e3, d(e3)));
            return r2;
          }, s2.prototype.updateAttributes = function(t3) {
            return this.attributes = t3, this.refreshAttributeButtons();
          }, s2.prototype.refreshAttributeButtons = function() {
            return this.eachAttributeButton(function(t3) {
              return function(e3, n2) {
                return e3.disabled = t3.attributes[n2] === false, t3.attributes[n2] || t3.dialogIsVisible(n2) ? (e3.setAttribute("data-trix-active", ""), e3.classList.add("trix-active")) : (e3.removeAttribute("data-trix-active"), e3.classList.remove("trix-active"));
              };
            }(this));
          }, s2.prototype.eachAttributeButton = function(t3) {
            var e3, n2, i2, o2, r2;
            for (o2 = this.element.querySelectorAll(c), r2 = [], n2 = 0, i2 = o2.length; i2 > n2; n2++)
              e3 = o2[n2], r2.push(t3(e3, f(e3)));
            return r2;
          }, s2.prototype.applyKeyboardCommand = function(t3) {
            var e3, n2, o2, r2, s3, a2, u2;
            for (s3 = JSON.stringify(t3.sort()), u2 = this.element.querySelectorAll("[data-trix-key]"), r2 = 0, a2 = u2.length; a2 > r2; r2++)
              if (e3 = u2[r2], o2 = e3.getAttribute("data-trix-key").split("+"), n2 = JSON.stringify(o2.sort()), n2 === s3)
                return i("mousedown", {onElement: e3}), true;
            return false;
          }, s2.prototype.dialogIsVisible = function(t3) {
            var e3;
            return (e3 = this.getDialog(t3)) ? e3.hasAttribute("data-trix-active") : void 0;
          }, s2.prototype.toggleDialog = function(t3) {
            return this.dialogIsVisible(t3) ? this.hideDialog() : this.showDialog(t3);
          }, s2.prototype.showDialog = function(t3) {
            var e3, n2, i2, o2, r2, s3, a2, u2, c2, l2;
            for (this.hideDialog(), (a2 = this.delegate) != null && a2.toolbarWillShowDialog(), i2 = this.getDialog(t3), i2.setAttribute("data-trix-active", ""), i2.classList.add("trix-active"), u2 = i2.querySelectorAll("input[disabled]"), o2 = 0, s3 = u2.length; s3 > o2; o2++)
              n2 = u2[o2], n2.removeAttribute("disabled");
            return (e3 = f(i2)) && (r2 = m(i2, t3)) && (r2.value = (c2 = this.attributes[e3]) != null ? c2 : "", r2.select()), (l2 = this.delegate) != null ? l2.toolbarDidShowDialog(t3) : void 0;
          }, s2.prototype.setAttribute = function(t3) {
            var e3, n2, i2;
            return e3 = f(t3), n2 = m(t3, e3), n2.willValidate && !n2.checkValidity() ? (n2.setAttribute("data-trix-validate", ""), n2.classList.add("trix-validate"), n2.focus()) : ((i2 = this.delegate) != null && i2.toolbarDidUpdateAttribute(e3, n2.value), this.hideDialog());
          }, s2.prototype.removeAttribute = function(t3) {
            var e3, n2;
            return e3 = f(t3), (n2 = this.delegate) != null && n2.toolbarDidRemoveAttribute(e3), this.hideDialog();
          }, s2.prototype.hideDialog = function() {
            var t3, e3;
            return (t3 = this.element.querySelector(u)) ? (t3.removeAttribute("data-trix-active"), t3.classList.remove("trix-active"), this.resetDialogInputs(), (e3 = this.delegate) != null ? e3.toolbarDidHideDialog(g(t3)) : void 0) : void 0;
          }, s2.prototype.resetDialogInputs = function() {
            var t3, e3, n2, i2, o2;
            for (i2 = this.element.querySelectorAll(h), o2 = [], t3 = 0, n2 = i2.length; n2 > t3; t3++)
              e3 = i2[t3], e3.setAttribute("disabled", "disabled"), e3.removeAttribute("data-trix-validate"), o2.push(e3.classList.remove("trix-validate"));
            return o2;
          }, s2.prototype.getDialog = function(t3) {
            return this.element.querySelector("[data-trix-dialog=" + t3 + "]");
          }, m = function(t3, e3) {
            return e3 == null && (e3 = f(t3)), t3.querySelector("[data-trix-input][name='" + e3 + "']");
          }, d = function(t3) {
            return t3.getAttribute("data-trix-action");
          }, f = function(t3) {
            var e3;
            return (e3 = t3.getAttribute("data-trix-attribute")) != null ? e3 : t3.getAttribute("data-trix-dialog-attribute");
          }, g = function(t3) {
            return t3.getAttribute("data-trix-dialog");
          }, s2;
        }(e.BasicObject);
      }.call(this), function() {
        var t2 = function(t3, e2) {
          function i() {
            this.constructor = t3;
          }
          for (var o in e2)
            n.call(e2, o) && (t3[o] = e2[o]);
          return i.prototype = e2.prototype, t3.prototype = new i(), t3.__super__ = e2.prototype, t3;
        }, n = {}.hasOwnProperty;
        e.ImagePreloadOperation = function(e2) {
          function n2(t3) {
            this.url = t3;
          }
          return t2(n2, e2), n2.prototype.perform = function(t3) {
            var e3;
            return e3 = new Image(), e3.onload = function(n3) {
              return function() {
                return e3.width = n3.width = e3.naturalWidth, e3.height = n3.height = e3.naturalHeight, t3(true, e3);
              };
            }(this), e3.onerror = function() {
              return t3(false);
            }, e3.src = this.url;
          }, n2;
        }(e.Operation);
      }.call(this), function() {
        var t2 = function(t3, e2) {
          return function() {
            return t3.apply(e2, arguments);
          };
        }, n = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var o in e2)
            i.call(e2, o) && (t3[o] = e2[o]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, i = {}.hasOwnProperty;
        e.Attachment = function(i2) {
          function o(n2) {
            n2 == null && (n2 = {}), this.releaseFile = t2(this.releaseFile, this), o.__super__.constructor.apply(this, arguments), this.attributes = e.Hash.box(n2), this.didChangeAttributes();
          }
          return n(o, i2), o.previewablePattern = /^image(\/(gif|png|jpe?g)|$)/, o.attachmentForFile = function(t3) {
            var e2, n2;
            return n2 = this.attributesForFile(t3), e2 = new this(n2), e2.setFile(t3), e2;
          }, o.attributesForFile = function(t3) {
            return new e.Hash({filename: t3.name, filesize: t3.size, contentType: t3.type});
          }, o.fromJSON = function(t3) {
            return new this(t3);
          }, o.prototype.getAttribute = function(t3) {
            return this.attributes.get(t3);
          }, o.prototype.hasAttribute = function(t3) {
            return this.attributes.has(t3);
          }, o.prototype.getAttributes = function() {
            return this.attributes.toObject();
          }, o.prototype.setAttributes = function(t3) {
            var e2, n2, i3;
            return t3 == null && (t3 = {}), e2 = this.attributes.merge(t3), this.attributes.isEqualTo(e2) ? void 0 : (this.attributes = e2, this.didChangeAttributes(), (n2 = this.previewDelegate) != null && typeof n2.attachmentDidChangeAttributes == "function" && n2.attachmentDidChangeAttributes(this), (i3 = this.delegate) != null && typeof i3.attachmentDidChangeAttributes == "function" ? i3.attachmentDidChangeAttributes(this) : void 0);
          }, o.prototype.didChangeAttributes = function() {
            return this.isPreviewable() ? this.preloadURL() : void 0;
          }, o.prototype.isPending = function() {
            return this.file != null && !(this.getURL() || this.getHref());
          }, o.prototype.isPreviewable = function() {
            return this.attributes.has("previewable") ? this.attributes.get("previewable") : this.constructor.previewablePattern.test(this.getContentType());
          }, o.prototype.getType = function() {
            return this.hasContent() ? "content" : this.isPreviewable() ? "preview" : "file";
          }, o.prototype.getURL = function() {
            return this.attributes.get("url");
          }, o.prototype.getHref = function() {
            return this.attributes.get("href");
          }, o.prototype.getFilename = function() {
            var t3;
            return (t3 = this.attributes.get("filename")) != null ? t3 : "";
          }, o.prototype.getFilesize = function() {
            return this.attributes.get("filesize");
          }, o.prototype.getFormattedFilesize = function() {
            var t3;
            return t3 = this.attributes.get("filesize"), typeof t3 == "number" ? e.config.fileSize.formatter(t3) : "";
          }, o.prototype.getExtension = function() {
            var t3;
            return (t3 = this.getFilename().match(/\.(\w+)$/)) != null ? t3[1].toLowerCase() : void 0;
          }, o.prototype.getContentType = function() {
            return this.attributes.get("contentType");
          }, o.prototype.hasContent = function() {
            return this.attributes.has("content");
          }, o.prototype.getContent = function() {
            return this.attributes.get("content");
          }, o.prototype.getWidth = function() {
            return this.attributes.get("width");
          }, o.prototype.getHeight = function() {
            return this.attributes.get("height");
          }, o.prototype.getFile = function() {
            return this.file;
          }, o.prototype.setFile = function(t3) {
            return this.file = t3, this.isPreviewable() ? this.preloadFile() : void 0;
          }, o.prototype.releaseFile = function() {
            return this.releasePreloadedFile(), this.file = null;
          }, o.prototype.getUploadProgress = function() {
            var t3;
            return (t3 = this.uploadProgress) != null ? t3 : 0;
          }, o.prototype.setUploadProgress = function(t3) {
            var e2;
            return this.uploadProgress !== t3 ? (this.uploadProgress = t3, (e2 = this.uploadProgressDelegate) != null && typeof e2.attachmentDidChangeUploadProgress == "function" ? e2.attachmentDidChangeUploadProgress(this) : void 0) : void 0;
          }, o.prototype.toJSON = function() {
            return this.getAttributes();
          }, o.prototype.getCacheKey = function() {
            return [o.__super__.getCacheKey.apply(this, arguments), this.attributes.getCacheKey(), this.getPreviewURL()].join("/");
          }, o.prototype.getPreviewURL = function() {
            return this.previewURL || this.preloadingURL;
          }, o.prototype.setPreviewURL = function(t3) {
            var e2, n2;
            return t3 !== this.getPreviewURL() ? (this.previewURL = t3, (e2 = this.previewDelegate) != null && typeof e2.attachmentDidChangeAttributes == "function" && e2.attachmentDidChangeAttributes(this), (n2 = this.delegate) != null && typeof n2.attachmentDidChangePreviewURL == "function" ? n2.attachmentDidChangePreviewURL(this) : void 0) : void 0;
          }, o.prototype.preloadURL = function() {
            return this.preload(this.getURL(), this.releaseFile);
          }, o.prototype.preloadFile = function() {
            return this.file ? (this.fileObjectURL = URL.createObjectURL(this.file), this.preload(this.fileObjectURL)) : void 0;
          }, o.prototype.releasePreloadedFile = function() {
            return this.fileObjectURL ? (URL.revokeObjectURL(this.fileObjectURL), this.fileObjectURL = null) : void 0;
          }, o.prototype.preload = function(t3, n2) {
            var i3;
            return t3 && t3 !== this.getPreviewURL() ? (this.preloadingURL = t3, i3 = new e.ImagePreloadOperation(t3), i3.then(function(e2) {
              return function(i4) {
                var o2, r;
                return r = i4.width, o2 = i4.height, e2.getWidth() && e2.getHeight() || e2.setAttributes({width: r, height: o2}), e2.preloadingURL = null, e2.setPreviewURL(t3), typeof n2 == "function" ? n2() : void 0;
              };
            }(this))["catch"](function(t4) {
              return function() {
                return t4.preloadingURL = null, typeof n2 == "function" ? n2() : void 0;
              };
            }(this))) : void 0;
          }, o;
        }(e.Object);
      }.call(this), function() {
        var t2 = function(t3, e2) {
          function i() {
            this.constructor = t3;
          }
          for (var o in e2)
            n.call(e2, o) && (t3[o] = e2[o]);
          return i.prototype = e2.prototype, t3.prototype = new i(), t3.__super__ = e2.prototype, t3;
        }, n = {}.hasOwnProperty;
        e.Piece = function(n2) {
          function i(t3, n3) {
            n3 == null && (n3 = {}), i.__super__.constructor.apply(this, arguments), this.attributes = e.Hash.box(n3);
          }
          return t2(i, n2), i.types = {}, i.registerType = function(t3, e2) {
            return e2.type = t3, this.types[t3] = e2;
          }, i.fromJSON = function(t3) {
            var e2;
            return (e2 = this.types[t3.type]) ? e2.fromJSON(t3) : void 0;
          }, i.prototype.copyWithAttributes = function(t3) {
            return new this.constructor(this.getValue(), t3);
          }, i.prototype.copyWithAdditionalAttributes = function(t3) {
            return this.copyWithAttributes(this.attributes.merge(t3));
          }, i.prototype.copyWithoutAttribute = function(t3) {
            return this.copyWithAttributes(this.attributes.remove(t3));
          }, i.prototype.copy = function() {
            return this.copyWithAttributes(this.attributes);
          }, i.prototype.getAttribute = function(t3) {
            return this.attributes.get(t3);
          }, i.prototype.getAttributesHash = function() {
            return this.attributes;
          }, i.prototype.getAttributes = function() {
            return this.attributes.toObject();
          }, i.prototype.getCommonAttributes = function() {
            var t3, e2, n3;
            return (n3 = pieceList.getPieceAtIndex(0)) ? (t3 = n3.attributes, e2 = t3.getKeys(), pieceList.eachPiece(function(n4) {
              return e2 = t3.getKeysCommonToHash(n4.attributes), t3 = t3.slice(e2);
            }), t3.toObject()) : {};
          }, i.prototype.hasAttribute = function(t3) {
            return this.attributes.has(t3);
          }, i.prototype.hasSameStringValueAsPiece = function(t3) {
            return t3 != null && this.toString() === t3.toString();
          }, i.prototype.hasSameAttributesAsPiece = function(t3) {
            return t3 != null && (this.attributes === t3.attributes || this.attributes.isEqualTo(t3.attributes));
          }, i.prototype.isBlockBreak = function() {
            return false;
          }, i.prototype.isEqualTo = function(t3) {
            return i.__super__.isEqualTo.apply(this, arguments) || this.hasSameConstructorAs(t3) && this.hasSameStringValueAsPiece(t3) && this.hasSameAttributesAsPiece(t3);
          }, i.prototype.isEmpty = function() {
            return this.length === 0;
          }, i.prototype.isSerializable = function() {
            return true;
          }, i.prototype.toJSON = function() {
            return {type: this.constructor.type, attributes: this.getAttributes()};
          }, i.prototype.contentsForInspection = function() {
            return {type: this.constructor.type, attributes: this.attributes.inspect()};
          }, i.prototype.canBeGrouped = function() {
            return this.hasAttribute("href");
          }, i.prototype.canBeGroupedWith = function(t3) {
            return this.getAttribute("href") === t3.getAttribute("href");
          }, i.prototype.getLength = function() {
            return this.length;
          }, i.prototype.canBeConsolidatedWith = function() {
            return false;
          }, i;
        }(e.Object);
      }.call(this), function() {
        var t2 = function(t3, e2) {
          function i() {
            this.constructor = t3;
          }
          for (var o in e2)
            n.call(e2, o) && (t3[o] = e2[o]);
          return i.prototype = e2.prototype, t3.prototype = new i(), t3.__super__ = e2.prototype, t3;
        }, n = {}.hasOwnProperty;
        e.Piece.registerType("attachment", e.AttachmentPiece = function(n2) {
          function i(t3) {
            this.attachment = t3, i.__super__.constructor.apply(this, arguments), this.length = 1, this.ensureAttachmentExclusivelyHasAttribute("href"), this.attachment.hasContent() || this.removeProhibitedAttributes();
          }
          return t2(i, n2), i.fromJSON = function(t3) {
            return new this(e.Attachment.fromJSON(t3.attachment), t3.attributes);
          }, i.permittedAttributes = ["caption", "presentation"], i.prototype.ensureAttachmentExclusivelyHasAttribute = function(t3) {
            return this.hasAttribute(t3) ? (this.attachment.hasAttribute(t3) || this.attachment.setAttributes(this.attributes.slice(t3)), this.attributes = this.attributes.remove(t3)) : void 0;
          }, i.prototype.removeProhibitedAttributes = function() {
            var t3;
            return t3 = this.attributes.slice(this.constructor.permittedAttributes), t3.isEqualTo(this.attributes) ? void 0 : this.attributes = t3;
          }, i.prototype.getValue = function() {
            return this.attachment;
          }, i.prototype.isSerializable = function() {
            return !this.attachment.isPending();
          }, i.prototype.getCaption = function() {
            var t3;
            return (t3 = this.attributes.get("caption")) != null ? t3 : "";
          }, i.prototype.isEqualTo = function(t3) {
            var e2;
            return i.__super__.isEqualTo.apply(this, arguments) && this.attachment.id === (t3 != null && (e2 = t3.attachment) != null ? e2.id : void 0);
          }, i.prototype.toString = function() {
            return e.OBJECT_REPLACEMENT_CHARACTER;
          }, i.prototype.toJSON = function() {
            var t3;
            return t3 = i.__super__.toJSON.apply(this, arguments), t3.attachment = this.attachment, t3;
          }, i.prototype.getCacheKey = function() {
            return [i.__super__.getCacheKey.apply(this, arguments), this.attachment.getCacheKey()].join("/");
          }, i.prototype.toConsole = function() {
            return JSON.stringify(this.toString());
          }, i;
        }(e.Piece));
      }.call(this), function() {
        var t2, n = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var o in e2)
            i.call(e2, o) && (t3[o] = e2[o]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, i = {}.hasOwnProperty;
        t2 = e.normalizeNewlines, e.Piece.registerType("string", e.StringPiece = function(e2) {
          function i2(e3) {
            i2.__super__.constructor.apply(this, arguments), this.string = t2(e3), this.length = this.string.length;
          }
          return n(i2, e2), i2.fromJSON = function(t3) {
            return new this(t3.string, t3.attributes);
          }, i2.prototype.getValue = function() {
            return this.string;
          }, i2.prototype.toString = function() {
            return this.string.toString();
          }, i2.prototype.isBlockBreak = function() {
            return this.toString() === "\n" && this.getAttribute("blockBreak") === true;
          }, i2.prototype.toJSON = function() {
            var t3;
            return t3 = i2.__super__.toJSON.apply(this, arguments), t3.string = this.string, t3;
          }, i2.prototype.canBeConsolidatedWith = function(t3) {
            return t3 != null && this.hasSameConstructorAs(t3) && this.hasSameAttributesAsPiece(t3);
          }, i2.prototype.consolidateWith = function(t3) {
            return new this.constructor(this.toString() + t3.toString(), this.attributes);
          }, i2.prototype.splitAtOffset = function(t3) {
            var e3, n2;
            return t3 === 0 ? (e3 = null, n2 = this) : t3 === this.length ? (e3 = this, n2 = null) : (e3 = new this.constructor(this.string.slice(0, t3), this.attributes), n2 = new this.constructor(this.string.slice(t3), this.attributes)), [e3, n2];
          }, i2.prototype.toConsole = function() {
            var t3;
            return t3 = this.string, t3.length > 15 && (t3 = t3.slice(0, 14) + "\u2026"), JSON.stringify(t3.toString());
          }, i2;
        }(e.Piece));
      }.call(this), function() {
        var t2, n = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var o2 in e2)
            i.call(e2, o2) && (t3[o2] = e2[o2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, i = {}.hasOwnProperty, o = [].slice;
        t2 = e.spliceArray, e.SplittableList = function(e2) {
          function i2(t3) {
            t3 == null && (t3 = []), i2.__super__.constructor.apply(this, arguments), this.objects = t3.slice(0), this.length = this.objects.length;
          }
          var r, s, a;
          return n(i2, e2), i2.box = function(t3) {
            return t3 instanceof this ? t3 : new this(t3);
          }, i2.prototype.indexOf = function(t3) {
            return this.objects.indexOf(t3);
          }, i2.prototype.splice = function() {
            var e3;
            return e3 = 1 <= arguments.length ? o.call(arguments, 0) : [], new this.constructor(t2.apply(null, [this.objects].concat(o.call(e3))));
          }, i2.prototype.eachObject = function(t3) {
            var e3, n2, i3, o2, r2, s2;
            for (r2 = this.objects, s2 = [], n2 = e3 = 0, i3 = r2.length; i3 > e3; n2 = ++e3)
              o2 = r2[n2], s2.push(t3(o2, n2));
            return s2;
          }, i2.prototype.insertObjectAtIndex = function(t3, e3) {
            return this.splice(e3, 0, t3);
          }, i2.prototype.insertSplittableListAtIndex = function(t3, e3) {
            return this.splice.apply(this, [e3, 0].concat(o.call(t3.objects)));
          }, i2.prototype.insertSplittableListAtPosition = function(t3, e3) {
            var n2, i3, o2;
            return o2 = this.splitObjectAtPosition(e3), i3 = o2[0], n2 = o2[1], new this.constructor(i3).insertSplittableListAtIndex(t3, n2);
          }, i2.prototype.editObjectAtIndex = function(t3, e3) {
            return this.replaceObjectAtIndex(e3(this.objects[t3]), t3);
          }, i2.prototype.replaceObjectAtIndex = function(t3, e3) {
            return this.splice(e3, 1, t3);
          }, i2.prototype.removeObjectAtIndex = function(t3) {
            return this.splice(t3, 1);
          }, i2.prototype.getObjectAtIndex = function(t3) {
            return this.objects[t3];
          }, i2.prototype.getSplittableListInRange = function(t3) {
            var e3, n2, i3, o2;
            return i3 = this.splitObjectsAtRange(t3), n2 = i3[0], e3 = i3[1], o2 = i3[2], new this.constructor(n2.slice(e3, o2 + 1));
          }, i2.prototype.selectSplittableList = function(t3) {
            var e3, n2;
            return n2 = function() {
              var n3, i3, o2, r2;
              for (o2 = this.objects, r2 = [], n3 = 0, i3 = o2.length; i3 > n3; n3++)
                e3 = o2[n3], t3(e3) && r2.push(e3);
              return r2;
            }.call(this), new this.constructor(n2);
          }, i2.prototype.removeObjectsInRange = function(t3) {
            var e3, n2, i3, o2;
            return i3 = this.splitObjectsAtRange(t3), n2 = i3[0], e3 = i3[1], o2 = i3[2], new this.constructor(n2).splice(e3, o2 - e3 + 1);
          }, i2.prototype.transformObjectsInRange = function(t3, e3) {
            var n2, i3, o2, r2, s2, a2, u;
            return s2 = this.splitObjectsAtRange(t3), r2 = s2[0], i3 = s2[1], a2 = s2[2], u = function() {
              var t4, s3, u2;
              for (u2 = [], n2 = t4 = 0, s3 = r2.length; s3 > t4; n2 = ++t4)
                o2 = r2[n2], u2.push(n2 >= i3 && a2 >= n2 ? e3(o2) : o2);
              return u2;
            }(), new this.constructor(u);
          }, i2.prototype.splitObjectsAtRange = function(t3) {
            var e3, n2, i3, o2, s2, u;
            return o2 = this.splitObjectAtPosition(a(t3)), n2 = o2[0], e3 = o2[1], i3 = o2[2], s2 = new this.constructor(n2).splitObjectAtPosition(r(t3) + i3), n2 = s2[0], u = s2[1], [n2, e3, u - 1];
          }, i2.prototype.getObjectAtPosition = function(t3) {
            var e3, n2, i3;
            return i3 = this.findIndexAndOffsetAtPosition(t3), e3 = i3.index, n2 = i3.offset, this.objects[e3];
          }, i2.prototype.splitObjectAtPosition = function(t3) {
            var e3, n2, i3, o2, r2, s2, a2, u, c, l;
            return s2 = this.findIndexAndOffsetAtPosition(t3), e3 = s2.index, r2 = s2.offset, o2 = this.objects.slice(0), e3 != null ? r2 === 0 ? (c = e3, l = 0) : (i3 = this.getObjectAtIndex(e3), a2 = i3.splitAtOffset(r2), n2 = a2[0], u = a2[1], o2.splice(e3, 1, n2, u), c = e3 + 1, l = n2.getLength() - r2) : (c = o2.length, l = 0), [o2, c, l];
          }, i2.prototype.consolidate = function() {
            var t3, e3, n2, i3, o2, r2;
            for (i3 = [], o2 = this.objects[0], r2 = this.objects.slice(1), t3 = 0, e3 = r2.length; e3 > t3; t3++)
              n2 = r2[t3], (typeof o2.canBeConsolidatedWith == "function" ? o2.canBeConsolidatedWith(n2) : void 0) ? o2 = o2.consolidateWith(n2) : (i3.push(o2), o2 = n2);
            return o2 != null && i3.push(o2), new this.constructor(i3);
          }, i2.prototype.consolidateFromIndexToIndex = function(t3, e3) {
            var n2, i3, r2;
            return i3 = this.objects.slice(0), r2 = i3.slice(t3, e3 + 1), n2 = new this.constructor(r2).consolidate().toArray(), this.splice.apply(this, [t3, r2.length].concat(o.call(n2)));
          }, i2.prototype.findIndexAndOffsetAtPosition = function(t3) {
            var e3, n2, i3, o2, r2, s2, a2;
            for (e3 = 0, a2 = this.objects, i3 = n2 = 0, o2 = a2.length; o2 > n2; i3 = ++n2) {
              if (s2 = a2[i3], r2 = e3 + s2.getLength(), t3 >= e3 && r2 > t3)
                return {index: i3, offset: t3 - e3};
              e3 = r2;
            }
            return {index: null, offset: null};
          }, i2.prototype.findPositionAtIndexAndOffset = function(t3, e3) {
            var n2, i3, o2, r2, s2, a2;
            for (s2 = 0, a2 = this.objects, n2 = i3 = 0, o2 = a2.length; o2 > i3; n2 = ++i3)
              if (r2 = a2[n2], t3 > n2)
                s2 += r2.getLength();
              else if (n2 === t3) {
                s2 += e3;
                break;
              }
            return s2;
          }, i2.prototype.getEndPosition = function() {
            var t3, e3;
            return this.endPosition != null ? this.endPosition : this.endPosition = function() {
              var n2, i3, o2;
              for (e3 = 0, o2 = this.objects, n2 = 0, i3 = o2.length; i3 > n2; n2++)
                t3 = o2[n2], e3 += t3.getLength();
              return e3;
            }.call(this);
          }, i2.prototype.toString = function() {
            return this.objects.join("");
          }, i2.prototype.toArray = function() {
            return this.objects.slice(0);
          }, i2.prototype.toJSON = function() {
            return this.toArray();
          }, i2.prototype.isEqualTo = function(t3) {
            return i2.__super__.isEqualTo.apply(this, arguments) || s(this.objects, t3 != null ? t3.objects : void 0);
          }, s = function(t3, e3) {
            var n2, i3, o2, r2, s2;
            if (e3 == null && (e3 = []), t3.length !== e3.length)
              return false;
            for (s2 = true, i3 = n2 = 0, o2 = t3.length; o2 > n2; i3 = ++n2)
              r2 = t3[i3], s2 && !r2.isEqualTo(e3[i3]) && (s2 = false);
            return s2;
          }, i2.prototype.contentsForInspection = function() {
            var t3;
            return {objects: "[" + function() {
              var e3, n2, i3, o2;
              for (i3 = this.objects, o2 = [], e3 = 0, n2 = i3.length; n2 > e3; e3++)
                t3 = i3[e3], o2.push(t3.inspect());
              return o2;
            }.call(this).join(", ") + "]"};
          }, a = function(t3) {
            return t3[0];
          }, r = function(t3) {
            return t3[1];
          }, i2;
        }(e.Object);
      }.call(this), function() {
        var t2 = function(t3, e2) {
          function i() {
            this.constructor = t3;
          }
          for (var o in e2)
            n.call(e2, o) && (t3[o] = e2[o]);
          return i.prototype = e2.prototype, t3.prototype = new i(), t3.__super__ = e2.prototype, t3;
        }, n = {}.hasOwnProperty;
        e.Text = function(n2) {
          function i(t3) {
            var n3;
            t3 == null && (t3 = []), i.__super__.constructor.apply(this, arguments), this.pieceList = new e.SplittableList(function() {
              var e2, i2, o;
              for (o = [], e2 = 0, i2 = t3.length; i2 > e2; e2++)
                n3 = t3[e2], n3.isEmpty() || o.push(n3);
              return o;
            }());
          }
          return t2(i, n2), i.textForAttachmentWithAttributes = function(t3, n3) {
            var i2;
            return i2 = new e.AttachmentPiece(t3, n3), new this([i2]);
          }, i.textForStringWithAttributes = function(t3, n3) {
            var i2;
            return i2 = new e.StringPiece(t3, n3), new this([i2]);
          }, i.fromJSON = function(t3) {
            var n3, i2;
            return i2 = function() {
              var i3, o, r;
              for (r = [], i3 = 0, o = t3.length; o > i3; i3++)
                n3 = t3[i3], r.push(e.Piece.fromJSON(n3));
              return r;
            }(), new this(i2);
          }, i.prototype.copy = function() {
            return this.copyWithPieceList(this.pieceList);
          }, i.prototype.copyWithPieceList = function(t3) {
            return new this.constructor(t3.consolidate().toArray());
          }, i.prototype.copyUsingObjectMap = function(t3) {
            var e2, n3;
            return n3 = function() {
              var n4, i2, o, r, s;
              for (o = this.getPieces(), s = [], n4 = 0, i2 = o.length; i2 > n4; n4++)
                e2 = o[n4], s.push((r = t3.find(e2)) != null ? r : e2);
              return s;
            }.call(this), new this.constructor(n3);
          }, i.prototype.appendText = function(t3) {
            return this.insertTextAtPosition(t3, this.getLength());
          }, i.prototype.insertTextAtPosition = function(t3, e2) {
            return this.copyWithPieceList(this.pieceList.insertSplittableListAtPosition(t3.pieceList, e2));
          }, i.prototype.removeTextAtRange = function(t3) {
            return this.copyWithPieceList(this.pieceList.removeObjectsInRange(t3));
          }, i.prototype.replaceTextAtRange = function(t3, e2) {
            return this.removeTextAtRange(e2).insertTextAtPosition(t3, e2[0]);
          }, i.prototype.moveTextFromRangeToPosition = function(t3, e2) {
            var n3, i2;
            if (!(t3[0] <= e2 && e2 <= t3[1]))
              return i2 = this.getTextAtRange(t3), n3 = i2.getLength(), t3[0] < e2 && (e2 -= n3), this.removeTextAtRange(t3).insertTextAtPosition(i2, e2);
          }, i.prototype.addAttributeAtRange = function(t3, e2, n3) {
            var i2;
            return i2 = {}, i2[t3] = e2, this.addAttributesAtRange(i2, n3);
          }, i.prototype.addAttributesAtRange = function(t3, e2) {
            return this.copyWithPieceList(this.pieceList.transformObjectsInRange(e2, function(e3) {
              return e3.copyWithAdditionalAttributes(t3);
            }));
          }, i.prototype.removeAttributeAtRange = function(t3, e2) {
            return this.copyWithPieceList(this.pieceList.transformObjectsInRange(e2, function(e3) {
              return e3.copyWithoutAttribute(t3);
            }));
          }, i.prototype.setAttributesAtRange = function(t3, e2) {
            return this.copyWithPieceList(this.pieceList.transformObjectsInRange(e2, function(e3) {
              return e3.copyWithAttributes(t3);
            }));
          }, i.prototype.getAttributesAtPosition = function(t3) {
            var e2, n3;
            return (e2 = (n3 = this.pieceList.getObjectAtPosition(t3)) != null ? n3.getAttributes() : void 0) != null ? e2 : {};
          }, i.prototype.getCommonAttributes = function() {
            var t3, n3;
            return t3 = function() {
              var t4, e2, i2, o;
              for (i2 = this.pieceList.toArray(), o = [], t4 = 0, e2 = i2.length; e2 > t4; t4++)
                n3 = i2[t4], o.push(n3.getAttributes());
              return o;
            }.call(this), e.Hash.fromCommonAttributesOfObjects(t3).toObject();
          }, i.prototype.getCommonAttributesAtRange = function(t3) {
            var e2;
            return (e2 = this.getTextAtRange(t3).getCommonAttributes()) != null ? e2 : {};
          }, i.prototype.getExpandedRangeForAttributeAtOffset = function(t3, e2) {
            var n3, i2, o;
            for (n3 = o = e2, i2 = this.getLength(); n3 > 0 && this.getCommonAttributesAtRange([n3 - 1, o])[t3]; )
              n3--;
            for (; i2 > o && this.getCommonAttributesAtRange([e2, o + 1])[t3]; )
              o++;
            return [n3, o];
          }, i.prototype.getTextAtRange = function(t3) {
            return this.copyWithPieceList(this.pieceList.getSplittableListInRange(t3));
          }, i.prototype.getStringAtRange = function(t3) {
            return this.pieceList.getSplittableListInRange(t3).toString();
          }, i.prototype.getStringAtPosition = function(t3) {
            return this.getStringAtRange([t3, t3 + 1]);
          }, i.prototype.startsWithString = function(t3) {
            return this.getStringAtRange([0, t3.length]) === t3;
          }, i.prototype.endsWithString = function(t3) {
            var e2;
            return e2 = this.getLength(), this.getStringAtRange([e2 - t3.length, e2]) === t3;
          }, i.prototype.getAttachmentPieces = function() {
            var t3, e2, n3, i2, o;
            for (i2 = this.pieceList.toArray(), o = [], t3 = 0, e2 = i2.length; e2 > t3; t3++)
              n3 = i2[t3], n3.attachment != null && o.push(n3);
            return o;
          }, i.prototype.getAttachments = function() {
            var t3, e2, n3, i2, o;
            for (i2 = this.getAttachmentPieces(), o = [], t3 = 0, e2 = i2.length; e2 > t3; t3++)
              n3 = i2[t3], o.push(n3.attachment);
            return o;
          }, i.prototype.getAttachmentAndPositionById = function(t3) {
            var e2, n3, i2, o, r, s;
            for (o = 0, r = this.pieceList.toArray(), e2 = 0, n3 = r.length; n3 > e2; e2++) {
              if (i2 = r[e2], ((s = i2.attachment) != null ? s.id : void 0) === t3)
                return {attachment: i2.attachment, position: o};
              o += i2.length;
            }
            return {attachment: null, position: null};
          }, i.prototype.getAttachmentById = function(t3) {
            var e2, n3, i2;
            return i2 = this.getAttachmentAndPositionById(t3), e2 = i2.attachment, n3 = i2.position, e2;
          }, i.prototype.getRangeOfAttachment = function(t3) {
            var e2, n3;
            return n3 = this.getAttachmentAndPositionById(t3.id), t3 = n3.attachment, e2 = n3.position, t3 != null ? [e2, e2 + 1] : void 0;
          }, i.prototype.updateAttributesForAttachment = function(t3, e2) {
            var n3;
            return (n3 = this.getRangeOfAttachment(e2)) ? this.addAttributesAtRange(t3, n3) : this;
          }, i.prototype.getLength = function() {
            return this.pieceList.getEndPosition();
          }, i.prototype.isEmpty = function() {
            return this.getLength() === 0;
          }, i.prototype.isEqualTo = function(t3) {
            var e2;
            return i.__super__.isEqualTo.apply(this, arguments) || (t3 != null && (e2 = t3.pieceList) != null ? e2.isEqualTo(this.pieceList) : void 0);
          }, i.prototype.isBlockBreak = function() {
            return this.getLength() === 1 && this.pieceList.getObjectAtIndex(0).isBlockBreak();
          }, i.prototype.eachPiece = function(t3) {
            return this.pieceList.eachObject(t3);
          }, i.prototype.getPieces = function() {
            return this.pieceList.toArray();
          }, i.prototype.getPieceAtPosition = function(t3) {
            return this.pieceList.getObjectAtPosition(t3);
          }, i.prototype.contentsForInspection = function() {
            return {pieceList: this.pieceList.inspect()};
          }, i.prototype.toSerializableText = function() {
            var t3;
            return t3 = this.pieceList.selectSplittableList(function(t4) {
              return t4.isSerializable();
            }), this.copyWithPieceList(t3);
          }, i.prototype.toString = function() {
            return this.pieceList.toString();
          }, i.prototype.toJSON = function() {
            return this.pieceList.toJSON();
          }, i.prototype.toConsole = function() {
            var t3;
            return JSON.stringify(function() {
              var e2, n3, i2, o;
              for (i2 = this.pieceList.toArray(), o = [], e2 = 0, n3 = i2.length; n3 > e2; e2++)
                t3 = i2[e2], o.push(JSON.parse(t3.toConsole()));
              return o;
            }.call(this));
          }, i.prototype.getDirection = function() {
            return e.getDirection(this.toString());
          }, i.prototype.isRTL = function() {
            return this.getDirection() === "rtl";
          }, i;
        }(e.Object);
      }.call(this), function() {
        var t2, n, i, o, r, s = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var i2 in e2)
            a.call(e2, i2) && (t3[i2] = e2[i2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, a = {}.hasOwnProperty, u = [].indexOf || function(t3) {
          for (var e2 = 0, n2 = this.length; n2 > e2; e2++)
            if (e2 in this && this[e2] === t3)
              return e2;
          return -1;
        }, c = [].slice;
        t2 = e.arraysAreEqual, r = e.spliceArray, i = e.getBlockConfig, n = e.getBlockAttributeNames, o = e.getListAttributeNames, e.Block = function(n2) {
          function a2(t3, n3) {
            t3 == null && (t3 = new e.Text()), n3 == null && (n3 = []), a2.__super__.constructor.apply(this, arguments), this.text = h(t3), this.attributes = n3;
          }
          var l, h, p, d, f, g, m, v, y;
          return s(a2, n2), a2.fromJSON = function(t3) {
            var n3;
            return n3 = e.Text.fromJSON(t3.text), new this(n3, t3.attributes);
          }, a2.prototype.isEmpty = function() {
            return this.text.isBlockBreak();
          }, a2.prototype.isEqualTo = function(e2) {
            return a2.__super__.isEqualTo.apply(this, arguments) || this.text.isEqualTo(e2 != null ? e2.text : void 0) && t2(this.attributes, e2 != null ? e2.attributes : void 0);
          }, a2.prototype.copyWithText = function(t3) {
            return new this.constructor(t3, this.attributes);
          }, a2.prototype.copyWithoutText = function() {
            return this.copyWithText(null);
          }, a2.prototype.copyWithAttributes = function(t3) {
            return new this.constructor(this.text, t3);
          }, a2.prototype.copyWithoutAttributes = function() {
            return this.copyWithAttributes(null);
          }, a2.prototype.copyUsingObjectMap = function(t3) {
            var e2;
            return this.copyWithText((e2 = t3.find(this.text)) ? e2 : this.text.copyUsingObjectMap(t3));
          }, a2.prototype.addAttribute = function(t3) {
            var e2;
            return e2 = this.attributes.concat(d(t3)), this.copyWithAttributes(e2);
          }, a2.prototype.removeAttribute = function(t3) {
            var e2, n3;
            return n3 = i(t3).listAttribute, e2 = g(g(this.attributes, t3), n3), this.copyWithAttributes(e2);
          }, a2.prototype.removeLastAttribute = function() {
            return this.removeAttribute(this.getLastAttribute());
          }, a2.prototype.getLastAttribute = function() {
            return f(this.attributes);
          }, a2.prototype.getAttributes = function() {
            return this.attributes.slice(0);
          }, a2.prototype.getAttributeLevel = function() {
            return this.attributes.length;
          }, a2.prototype.getAttributeAtLevel = function(t3) {
            return this.attributes[t3 - 1];
          }, a2.prototype.hasAttribute = function(t3) {
            return u.call(this.attributes, t3) >= 0;
          }, a2.prototype.hasAttributes = function() {
            return this.getAttributeLevel() > 0;
          }, a2.prototype.getLastNestableAttribute = function() {
            return f(this.getNestableAttributes());
          }, a2.prototype.getNestableAttributes = function() {
            var t3, e2, n3, o2, r2;
            for (o2 = this.attributes, r2 = [], e2 = 0, n3 = o2.length; n3 > e2; e2++)
              t3 = o2[e2], i(t3).nestable && r2.push(t3);
            return r2;
          }, a2.prototype.getNestingLevel = function() {
            return this.getNestableAttributes().length;
          }, a2.prototype.decreaseNestingLevel = function() {
            var t3;
            return (t3 = this.getLastNestableAttribute()) ? this.removeAttribute(t3) : this;
          }, a2.prototype.increaseNestingLevel = function() {
            var t3, e2, n3;
            return (t3 = this.getLastNestableAttribute()) ? (n3 = this.attributes.lastIndexOf(t3), e2 = r.apply(null, [this.attributes, n3 + 1, 0].concat(c.call(d(t3)))), this.copyWithAttributes(e2)) : this;
          }, a2.prototype.getListItemAttributes = function() {
            var t3, e2, n3, o2, r2;
            for (o2 = this.attributes, r2 = [], e2 = 0, n3 = o2.length; n3 > e2; e2++)
              t3 = o2[e2], i(t3).listAttribute && r2.push(t3);
            return r2;
          }, a2.prototype.isListItem = function() {
            var t3;
            return (t3 = i(this.getLastAttribute())) != null ? t3.listAttribute : void 0;
          }, a2.prototype.isTerminalBlock = function() {
            var t3;
            return (t3 = i(this.getLastAttribute())) != null ? t3.terminal : void 0;
          }, a2.prototype.breaksOnReturn = function() {
            var t3;
            return (t3 = i(this.getLastAttribute())) != null ? t3.breakOnReturn : void 0;
          }, a2.prototype.findLineBreakInDirectionFromPosition = function(t3, e2) {
            var n3, i2;
            return i2 = this.toString(), n3 = function() {
              switch (t3) {
                case "forward":
                  return i2.indexOf("\n", e2);
                case "backward":
                  return i2.slice(0, e2).lastIndexOf("\n");
              }
            }(), n3 !== -1 ? n3 : void 0;
          }, a2.prototype.contentsForInspection = function() {
            return {text: this.text.inspect(), attributes: this.attributes};
          }, a2.prototype.toString = function() {
            return this.text.toString();
          }, a2.prototype.toJSON = function() {
            return {text: this.text, attributes: this.attributes};
          }, a2.prototype.getDirection = function() {
            return this.text.getDirection();
          }, a2.prototype.isRTL = function() {
            return this.text.isRTL();
          }, a2.prototype.getLength = function() {
            return this.text.getLength();
          }, a2.prototype.canBeConsolidatedWith = function(t3) {
            return !this.hasAttributes() && !t3.hasAttributes() && this.getDirection() === t3.getDirection();
          }, a2.prototype.consolidateWith = function(t3) {
            var n3, i2;
            return n3 = e.Text.textForStringWithAttributes("\n"), i2 = this.getTextWithoutBlockBreak().appendText(n3), this.copyWithText(i2.appendText(t3.text));
          }, a2.prototype.splitAtOffset = function(t3) {
            var e2, n3;
            return t3 === 0 ? (e2 = null, n3 = this) : t3 === this.getLength() ? (e2 = this, n3 = null) : (e2 = this.copyWithText(this.text.getTextAtRange([0, t3])), n3 = this.copyWithText(this.text.getTextAtRange([t3, this.getLength()]))), [e2, n3];
          }, a2.prototype.getBlockBreakPosition = function() {
            return this.text.getLength() - 1;
          }, a2.prototype.getTextWithoutBlockBreak = function() {
            return m(this.text) ? this.text.getTextAtRange([0, this.getBlockBreakPosition()]) : this.text.copy();
          }, a2.prototype.canBeGrouped = function(t3) {
            return this.attributes[t3];
          }, a2.prototype.canBeGroupedWith = function(t3, e2) {
            var n3, r2, s2, a3;
            return s2 = t3.getAttributes(), r2 = s2[e2], n3 = this.attributes[e2], !(n3 !== r2 || i(n3).group === false && (a3 = s2[e2 + 1], u.call(o(), a3) < 0) || this.getDirection() !== t3.getDirection() && !t3.isEmpty());
          }, h = function(t3) {
            return t3 = y(t3), t3 = l(t3);
          }, y = function(t3) {
            var n3, i2, o2, r2, s2, a3;
            return r2 = false, a3 = t3.getPieces(), i2 = 2 <= a3.length ? c.call(a3, 0, n3 = a3.length - 1) : (n3 = 0, []), o2 = a3[n3++], o2 == null ? t3 : (i2 = function() {
              var t4, e2, n4;
              for (n4 = [], t4 = 0, e2 = i2.length; e2 > t4; t4++)
                s2 = i2[t4], s2.isBlockBreak() ? (r2 = true, n4.push(v(s2))) : n4.push(s2);
              return n4;
            }(), r2 ? new e.Text(c.call(i2).concat([o2])) : t3);
          }, p = e.Text.textForStringWithAttributes("\n", {blockBreak: true}), l = function(t3) {
            return m(t3) ? t3 : t3.appendText(p);
          }, m = function(t3) {
            var e2, n3;
            return n3 = t3.getLength(), n3 === 0 ? false : (e2 = t3.getTextAtRange([n3 - 1, n3]), e2.isBlockBreak());
          }, v = function(t3) {
            return t3.copyWithoutAttribute("blockBreak");
          }, d = function(t3) {
            var e2;
            return e2 = i(t3).listAttribute, e2 != null ? [e2, t3] : [t3];
          }, f = function(t3) {
            return t3.slice(-1)[0];
          }, g = function(t3, e2) {
            var n3;
            return n3 = t3.lastIndexOf(e2), n3 === -1 ? t3 : r(t3, n3, 1);
          }, a2;
        }(e.Object);
      }.call(this), function() {
        var t2, n, i, o = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var i2 in e2)
            r.call(e2, i2) && (t3[i2] = e2[i2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, r = {}.hasOwnProperty, s = [].indexOf || function(t3) {
          for (var e2 = 0, n2 = this.length; n2 > e2; e2++)
            if (e2 in this && this[e2] === t3)
              return e2;
          return -1;
        }, a = [].slice;
        n = e.tagName, i = e.walkTree, t2 = e.nodeIsAttachmentElement, e.HTMLSanitizer = function(r2) {
          function u(t3, e2) {
            var n2;
            n2 = e2 != null ? e2 : {}, this.allowedAttributes = n2.allowedAttributes, this.forbiddenProtocols = n2.forbiddenProtocols, this.forbiddenElements = n2.forbiddenElements, this.allowedAttributes == null && (this.allowedAttributes = c), this.forbiddenProtocols == null && (this.forbiddenProtocols = h), this.forbiddenElements == null && (this.forbiddenElements = l), this.body = p(t3);
          }
          var c, l, h, p;
          return o(u, r2), c = "style href src width height class".split(" "), h = "javascript:".split(" "), l = "script iframe".split(" "), u.sanitize = function(t3, e2) {
            var n2;
            return n2 = new this(t3, e2), n2.sanitize(), n2;
          }, u.prototype.sanitize = function() {
            return this.sanitizeElements(), this.normalizeListElementNesting();
          }, u.prototype.getHTML = function() {
            return this.body.innerHTML;
          }, u.prototype.getBody = function() {
            return this.body;
          }, u.prototype.sanitizeElements = function() {
            var t3, n2, o2, r3, s2;
            for (s2 = i(this.body), r3 = []; s2.nextNode(); )
              switch (o2 = s2.currentNode, o2.nodeType) {
                case Node.ELEMENT_NODE:
                  this.elementIsRemovable(o2) ? r3.push(o2) : this.sanitizeElement(o2);
                  break;
                case Node.COMMENT_NODE:
                  r3.push(o2);
              }
            for (t3 = 0, n2 = r3.length; n2 > t3; t3++)
              o2 = r3[t3], e.removeNode(o2);
            return this.body;
          }, u.prototype.sanitizeElement = function(t3) {
            var e2, n2, i2, o2, r3;
            for (t3.hasAttribute("href") && (o2 = t3.protocol, s.call(this.forbiddenProtocols, o2) >= 0 && t3.removeAttribute("href")), r3 = a.call(t3.attributes), e2 = 0, n2 = r3.length; n2 > e2; e2++)
              i2 = r3[e2].name, s.call(this.allowedAttributes, i2) >= 0 || i2.indexOf("data-trix") === 0 || t3.removeAttribute(i2);
            return t3;
          }, u.prototype.normalizeListElementNesting = function() {
            var t3, e2, i2, o2, r3;
            for (r3 = a.call(this.body.querySelectorAll("ul,ol")), t3 = 0, e2 = r3.length; e2 > t3; t3++)
              i2 = r3[t3], (o2 = i2.previousElementSibling) && n(o2) === "li" && o2.appendChild(i2);
            return this.body;
          }, u.prototype.elementIsRemovable = function(t3) {
            return (t3 != null ? t3.nodeType : void 0) === Node.ELEMENT_NODE ? this.elementIsForbidden(t3) || this.elementIsntSerializable(t3) : void 0;
          }, u.prototype.elementIsForbidden = function(t3) {
            var e2;
            return e2 = n(t3), s.call(this.forbiddenElements, e2) >= 0;
          }, u.prototype.elementIsntSerializable = function(e2) {
            return e2.getAttribute("data-trix-serialize") === "false" && !t2(e2);
          }, p = function(t3) {
            var e2, n2, i2, o2, r3;
            for (t3 == null && (t3 = ""), t3 = t3.replace(/<\/html[^>]*>[^]*$/i, "</html>"), e2 = document.implementation.createHTMLDocument(""), e2.documentElement.innerHTML = t3, r3 = e2.head.querySelectorAll("style"), i2 = 0, o2 = r3.length; o2 > i2; i2++)
              n2 = r3[i2], e2.body.appendChild(n2);
            return e2.body;
          }, u;
        }(e.BasicObject);
      }.call(this), function() {
        var t2, n, i, o, r, s, a, u, c, l, h, p = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var i2 in e2)
            d.call(e2, i2) && (t3[i2] = e2[i2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, d = {}.hasOwnProperty, f = [].indexOf || function(t3) {
          for (var e2 = 0, n2 = this.length; n2 > e2; e2++)
            if (e2 in this && this[e2] === t3)
              return e2;
          return -1;
        };
        t2 = e.arraysAreEqual, s = e.makeElement, l = e.tagName, r = e.getBlockTagNames, h = e.walkTree, o = e.findClosestElementFromNode, i = e.elementContainsNode, a = e.nodeIsAttachmentElement, u = e.normalizeSpaces, n = e.breakableWhitespacePattern, c = e.squishBreakableWhitespace, e.HTMLParser = function(d2) {
          function g(t3, e2) {
            this.html = t3, this.referenceElement = (e2 != null ? e2 : {}).referenceElement, this.blocks = [], this.blockElements = [], this.processedElements = [];
          }
          var m, v, y, b, A, C, x, w, E, S, R, k;
          return p(g, d2), g.parse = function(t3, e2) {
            var n2;
            return n2 = new this(t3, e2), n2.parse(), n2;
          }, g.prototype.getDocument = function() {
            return e.Document.fromJSON(this.blocks);
          }, g.prototype.parse = function() {
            var t3, n2;
            try {
              for (this.createHiddenContainer(), t3 = e.HTMLSanitizer.sanitize(this.html).getHTML(), this.containerElement.innerHTML = t3, n2 = h(this.containerElement, {usingFilter: x}); n2.nextNode(); )
                this.processNode(n2.currentNode);
              return this.translateBlockElementMarginsToNewlines();
            } finally {
              this.removeHiddenContainer();
            }
          }, g.prototype.createHiddenContainer = function() {
            return this.referenceElement ? (this.containerElement = this.referenceElement.cloneNode(false), this.containerElement.removeAttribute("id"), this.containerElement.setAttribute("data-trix-internal", ""), this.containerElement.style.display = "none", this.referenceElement.parentNode.insertBefore(this.containerElement, this.referenceElement.nextSibling)) : (this.containerElement = s({tagName: "div", style: {display: "none"}}), document.body.appendChild(this.containerElement));
          }, g.prototype.removeHiddenContainer = function() {
            return e.removeNode(this.containerElement);
          }, x = function(t3) {
            return l(t3) === "style" ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
          }, g.prototype.processNode = function(t3) {
            switch (t3.nodeType) {
              case Node.TEXT_NODE:
                if (!this.isInsignificantTextNode(t3))
                  return this.appendBlockForTextNode(t3), this.processTextNode(t3);
                break;
              case Node.ELEMENT_NODE:
                return this.appendBlockForElement(t3), this.processElement(t3);
            }
          }, g.prototype.appendBlockForTextNode = function(e2) {
            var n2, i2, o2;
            return i2 = e2.parentNode, i2 === this.currentBlockElement && this.isBlockElement(e2.previousSibling) ? this.appendStringWithAttributes("\n") : i2 !== this.containerElement && !this.isBlockElement(i2) || (n2 = this.getBlockAttributes(i2), t2(n2, (o2 = this.currentBlock) != null ? o2.attributes : void 0)) ? void 0 : (this.currentBlock = this.appendBlockForAttributesWithElement(n2, i2), this.currentBlockElement = i2);
          }, g.prototype.appendBlockForElement = function(e2) {
            var n2, o2, r2, s2;
            if (r2 = this.isBlockElement(e2), o2 = i(this.currentBlockElement, e2), r2 && !this.isBlockElement(e2.firstChild)) {
              if ((!this.isInsignificantTextNode(e2.firstChild) || !this.isBlockElement(e2.firstElementChild)) && (n2 = this.getBlockAttributes(e2), e2.firstChild))
                return o2 && t2(n2, this.currentBlock.attributes) ? this.appendStringWithAttributes("\n") : (this.currentBlock = this.appendBlockForAttributesWithElement(n2, e2), this.currentBlockElement = e2);
            } else if (this.currentBlockElement && !o2 && !r2)
              return (s2 = this.findParentBlockElement(e2)) ? this.appendBlockForElement(s2) : (this.currentBlock = this.appendEmptyBlock(), this.currentBlockElement = null);
          }, g.prototype.findParentBlockElement = function(t3) {
            var e2;
            for (e2 = t3.parentElement; e2 && e2 !== this.containerElement; ) {
              if (this.isBlockElement(e2) && f.call(this.blockElements, e2) >= 0)
                return e2;
              e2 = e2.parentElement;
            }
            return null;
          }, g.prototype.processTextNode = function(t3) {
            var e2, n2;
            return n2 = t3.data, v(t3.parentNode) || (n2 = c(n2), R((e2 = t3.previousSibling) != null ? e2.textContent : void 0) && (n2 = A(n2))), this.appendStringWithAttributes(n2, this.getTextAttributes(t3.parentNode));
          }, g.prototype.processElement = function(t3) {
            var e2, n2, i2, o2, r2;
            if (a(t3))
              return e2 = w(t3, "attachment"), Object.keys(e2).length && (o2 = this.getTextAttributes(t3), this.appendAttachmentWithAttributes(e2, o2), t3.innerHTML = ""), this.processedElements.push(t3);
            switch (l(t3)) {
              case "br":
                return this.isExtraBR(t3) || this.isBlockElement(t3.nextSibling) || this.appendStringWithAttributes("\n", this.getTextAttributes(t3)), this.processedElements.push(t3);
              case "img":
                e2 = {url: t3.getAttribute("src"), contentType: "image"}, i2 = b(t3);
                for (n2 in i2)
                  r2 = i2[n2], e2[n2] = r2;
                return this.appendAttachmentWithAttributes(e2, this.getTextAttributes(t3)), this.processedElements.push(t3);
              case "tr":
                if (t3.parentNode.firstChild !== t3)
                  return this.appendStringWithAttributes("\n");
                break;
              case "td":
                if (t3.parentNode.firstChild !== t3)
                  return this.appendStringWithAttributes(" | ");
            }
          }, g.prototype.appendBlockForAttributesWithElement = function(t3, e2) {
            var n2;
            return this.blockElements.push(e2), n2 = m(t3), this.blocks.push(n2), n2;
          }, g.prototype.appendEmptyBlock = function() {
            return this.appendBlockForAttributesWithElement([], null);
          }, g.prototype.appendStringWithAttributes = function(t3, e2) {
            return this.appendPiece(S(t3, e2));
          }, g.prototype.appendAttachmentWithAttributes = function(t3, e2) {
            return this.appendPiece(E(t3, e2));
          }, g.prototype.appendPiece = function(t3) {
            return this.blocks.length === 0 && this.appendEmptyBlock(), this.blocks[this.blocks.length - 1].text.push(t3);
          }, g.prototype.appendStringToTextAtIndex = function(t3, e2) {
            var n2, i2;
            return i2 = this.blocks[e2].text, n2 = i2[i2.length - 1], (n2 != null ? n2.type : void 0) === "string" ? n2.string += t3 : i2.push(S(t3));
          }, g.prototype.prependStringToTextAtIndex = function(t3, e2) {
            var n2, i2;
            return i2 = this.blocks[e2].text, n2 = i2[0], (n2 != null ? n2.type : void 0) === "string" ? n2.string = t3 + n2.string : i2.unshift(S(t3));
          }, S = function(t3, e2) {
            var n2;
            return e2 == null && (e2 = {}), n2 = "string", t3 = u(t3), {string: t3, attributes: e2, type: n2};
          }, E = function(t3, e2) {
            var n2;
            return e2 == null && (e2 = {}), n2 = "attachment", {attachment: t3, attributes: e2, type: n2};
          }, m = function(t3) {
            var e2;
            return t3 == null && (t3 = {}), e2 = [], {text: e2, attributes: t3};
          }, g.prototype.getTextAttributes = function(t3) {
            var n2, i2, r2, s2, u2, c2, l2, h2, p2, d3, f2, g2;
            r2 = {}, p2 = e.config.textAttributes;
            for (n2 in p2)
              if (u2 = p2[n2], u2.tagName && o(t3, {matchingSelector: u2.tagName, untilNode: this.containerElement}))
                r2[n2] = true;
              else if (u2.parser) {
                if (g2 = u2.parser(t3)) {
                  for (i2 = false, d3 = this.findBlockElementAncestors(t3), c2 = 0, h2 = d3.length; h2 > c2; c2++)
                    if (s2 = d3[c2], u2.parser(s2) === g2) {
                      i2 = true;
                      break;
                    }
                  i2 || (r2[n2] = g2);
                }
              } else
                u2.styleProperty && (g2 = t3.style[u2.styleProperty]) && (r2[n2] = g2);
            if (a(t3)) {
              f2 = w(t3, "attributes");
              for (l2 in f2)
                g2 = f2[l2], r2[l2] = g2;
            }
            return r2;
          }, g.prototype.getBlockAttributes = function(t3) {
            var n2, i2, o2, r2;
            for (i2 = []; t3 && t3 !== this.containerElement; ) {
              r2 = e.config.blockAttributes;
              for (n2 in r2)
                o2 = r2[n2], o2.parse !== false && l(t3) === o2.tagName && ((typeof o2.test == "function" ? o2.test(t3) : void 0) || !o2.test) && (i2.push(n2), o2.listAttribute && i2.push(o2.listAttribute));
              t3 = t3.parentNode;
            }
            return i2.reverse();
          }, g.prototype.findBlockElementAncestors = function(t3) {
            var e2, n2;
            for (e2 = []; t3 && t3 !== this.containerElement; )
              n2 = l(t3), f.call(r(), n2) >= 0 && e2.push(t3), t3 = t3.parentNode;
            return e2;
          }, w = function(t3, e2) {
            try {
              return JSON.parse(t3.getAttribute("data-trix-" + e2));
            } catch (n2) {
              return {};
            }
          }, b = function(t3) {
            var e2, n2, i2;
            return i2 = t3.getAttribute("width"), n2 = t3.getAttribute("height"), e2 = {}, i2 && (e2.width = parseInt(i2, 10)), n2 && (e2.height = parseInt(n2, 10)), e2;
          }, g.prototype.isBlockElement = function(t3) {
            var e2;
            if ((t3 != null ? t3.nodeType : void 0) === Node.ELEMENT_NODE && !a(t3) && !o(t3, {matchingSelector: "td", untilNode: this.containerElement}))
              return e2 = l(t3), f.call(r(), e2) >= 0 || window.getComputedStyle(t3).display === "block";
          }, g.prototype.isInsignificantTextNode = function(t3) {
            var e2, n2, i2;
            if ((t3 != null ? t3.nodeType : void 0) === Node.TEXT_NODE && k(t3.data) && (n2 = t3.parentNode, i2 = t3.previousSibling, e2 = t3.nextSibling, (!C(n2.previousSibling) || this.isBlockElement(n2.previousSibling)) && !v(n2)))
              return !i2 || this.isBlockElement(i2) || !e2 || this.isBlockElement(e2);
          }, g.prototype.isExtraBR = function(t3) {
            return l(t3) === "br" && this.isBlockElement(t3.parentNode) && t3.parentNode.lastChild === t3;
          }, v = function(t3) {
            var e2;
            return e2 = window.getComputedStyle(t3).whiteSpace, e2 === "pre" || e2 === "pre-wrap" || e2 === "pre-line";
          }, C = function(t3) {
            return t3 && !R(t3.textContent);
          }, g.prototype.translateBlockElementMarginsToNewlines = function() {
            var t3, e2, n2, i2, o2, r2, s2, a2;
            for (e2 = this.getMarginOfDefaultBlockElement(), s2 = this.blocks, a2 = [], i2 = n2 = 0, o2 = s2.length; o2 > n2; i2 = ++n2)
              t3 = s2[i2], (r2 = this.getMarginOfBlockElementAtIndex(i2)) && (r2.top > 2 * e2.top && this.prependStringToTextAtIndex("\n", i2), a2.push(r2.bottom > 2 * e2.bottom ? this.appendStringToTextAtIndex("\n", i2) : void 0));
            return a2;
          }, g.prototype.getMarginOfBlockElementAtIndex = function(t3) {
            var e2, n2;
            return !(e2 = this.blockElements[t3]) || !e2.textContent || (n2 = l(e2), f.call(r(), n2) >= 0 || f.call(this.processedElements, e2) >= 0) ? void 0 : y(e2);
          }, g.prototype.getMarginOfDefaultBlockElement = function() {
            var t3;
            return t3 = s(e.config.blockAttributes["default"].tagName), this.containerElement.appendChild(t3), y(t3);
          }, y = function(t3) {
            var e2;
            return e2 = window.getComputedStyle(t3), e2.display === "block" ? {top: parseInt(e2.marginTop), bottom: parseInt(e2.marginBottom)} : void 0;
          }, A = function(t3) {
            return t3.replace(RegExp("^" + n.source + "+"), "");
          }, k = function(t3) {
            return RegExp("^" + n.source + "*$").test(t3);
          }, R = function(t3) {
            return /\s$/.test(t3);
          }, g;
        }(e.BasicObject);
      }.call(this), function() {
        var t2, n, i, o, r = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var i2 in e2)
            s.call(e2, i2) && (t3[i2] = e2[i2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, s = {}.hasOwnProperty, a = [].slice, u = [].indexOf || function(t3) {
          for (var e2 = 0, n2 = this.length; n2 > e2; e2++)
            if (e2 in this && this[e2] === t3)
              return e2;
          return -1;
        };
        t2 = e.arraysAreEqual, i = e.normalizeRange, o = e.rangeIsCollapsed, n = e.getBlockConfig, e.Document = function(s2) {
          function c(t3) {
            t3 == null && (t3 = []), c.__super__.constructor.apply(this, arguments), t3.length === 0 && (t3 = [new e.Block()]), this.blockList = e.SplittableList.box(t3);
          }
          var l;
          return r(c, s2), c.fromJSON = function(t3) {
            var n2, i2;
            return i2 = function() {
              var i3, o2, r2;
              for (r2 = [], i3 = 0, o2 = t3.length; o2 > i3; i3++)
                n2 = t3[i3], r2.push(e.Block.fromJSON(n2));
              return r2;
            }(), new this(i2);
          }, c.fromHTML = function(t3, n2) {
            return e.HTMLParser.parse(t3, n2).getDocument();
          }, c.fromString = function(t3, n2) {
            var i2;
            return i2 = e.Text.textForStringWithAttributes(t3, n2), new this([new e.Block(i2)]);
          }, c.prototype.isEmpty = function() {
            var t3;
            return this.blockList.length === 1 && (t3 = this.getBlockAtIndex(0), t3.isEmpty() && !t3.hasAttributes());
          }, c.prototype.copy = function(t3) {
            var e2;
            return t3 == null && (t3 = {}), e2 = t3.consolidateBlocks ? this.blockList.consolidate().toArray() : this.blockList.toArray(), new this.constructor(e2);
          }, c.prototype.copyUsingObjectsFromDocument = function(t3) {
            var n2;
            return n2 = new e.ObjectMap(t3.getObjects()), this.copyUsingObjectMap(n2);
          }, c.prototype.copyUsingObjectMap = function(t3) {
            var e2, n2, i2;
            return n2 = function() {
              var n3, o2, r2, s3;
              for (r2 = this.getBlocks(), s3 = [], n3 = 0, o2 = r2.length; o2 > n3; n3++)
                e2 = r2[n3], s3.push((i2 = t3.find(e2)) ? i2 : e2.copyUsingObjectMap(t3));
              return s3;
            }.call(this), new this.constructor(n2);
          }, c.prototype.copyWithBaseBlockAttributes = function(t3) {
            var e2, n2, i2;
            return t3 == null && (t3 = []), i2 = function() {
              var i3, o2, r2, s3;
              for (r2 = this.getBlocks(), s3 = [], i3 = 0, o2 = r2.length; o2 > i3; i3++)
                n2 = r2[i3], e2 = t3.concat(n2.getAttributes()), s3.push(n2.copyWithAttributes(e2));
              return s3;
            }.call(this), new this.constructor(i2);
          }, c.prototype.replaceBlock = function(t3, e2) {
            var n2;
            return n2 = this.blockList.indexOf(t3), n2 === -1 ? this : new this.constructor(this.blockList.replaceObjectAtIndex(e2, n2));
          }, c.prototype.insertDocumentAtRange = function(t3, e2) {
            var n2, r2, s3, a2, u2, c2, l2;
            return r2 = t3.blockList, u2 = (e2 = i(e2))[0], c2 = this.locationFromPosition(u2), s3 = c2.index, a2 = c2.offset, l2 = this, n2 = this.getBlockAtPosition(u2), o(e2) && n2.isEmpty() && !n2.hasAttributes() ? l2 = new this.constructor(l2.blockList.removeObjectAtIndex(s3)) : n2.getBlockBreakPosition() === a2 && u2++, l2 = l2.removeTextAtRange(e2), new this.constructor(l2.blockList.insertSplittableListAtPosition(r2, u2));
          }, c.prototype.mergeDocumentAtRange = function(e2, n2) {
            var o2, r2, s3, a2, u2, c2, l2, h, p, d, f, g;
            return f = (n2 = i(n2))[0], d = this.locationFromPosition(f), r2 = this.getBlockAtIndex(d.index).getAttributes(), o2 = e2.getBaseBlockAttributes(), g = r2.slice(-o2.length), t2(o2, g) ? (l2 = r2.slice(0, -o2.length), c2 = e2.copyWithBaseBlockAttributes(l2)) : c2 = e2.copy({consolidateBlocks: true}).copyWithBaseBlockAttributes(r2), s3 = c2.getBlockCount(), a2 = c2.getBlockAtIndex(0), t2(r2, a2.getAttributes()) ? (u2 = a2.getTextWithoutBlockBreak(), p = this.insertTextAtRange(u2, n2), s3 > 1 && (c2 = new this.constructor(c2.getBlocks().slice(1)), h = f + u2.getLength(), p = p.insertDocumentAtRange(c2, h))) : p = this.insertDocumentAtRange(c2, n2), p;
          }, c.prototype.insertTextAtRange = function(t3, e2) {
            var n2, o2, r2, s3, a2;
            return a2 = (e2 = i(e2))[0], s3 = this.locationFromPosition(a2), o2 = s3.index, r2 = s3.offset, n2 = this.removeTextAtRange(e2), new this.constructor(n2.blockList.editObjectAtIndex(o2, function(e3) {
              return e3.copyWithText(e3.text.insertTextAtPosition(t3, r2));
            }));
          }, c.prototype.removeTextAtRange = function(t3) {
            var e2, n2, r2, s3, a2, u2, c2, l2, h, p, d, f, g, m, v, y, b, A, C, x, w;
            return p = t3 = i(t3), l2 = p[0], A = p[1], o(t3) ? this : (d = this.locationRangeFromRange(t3), u2 = d[0], y = d[1], a2 = u2.index, c2 = u2.offset, s3 = this.getBlockAtIndex(a2), v = y.index, b = y.offset, m = this.getBlockAtIndex(v), f = A - l2 === 1 && s3.getBlockBreakPosition() === c2 && m.getBlockBreakPosition() !== b && m.text.getStringAtPosition(b) === "\n", f ? r2 = this.blockList.editObjectAtIndex(v, function(t4) {
              return t4.copyWithText(t4.text.removeTextAtRange([b, b + 1]));
            }) : (h = s3.text.getTextAtRange([0, c2]), C = m.text.getTextAtRange([b, m.getLength()]), x = h.appendText(C), g = a2 !== v && c2 === 0, w = g && s3.getAttributeLevel() >= m.getAttributeLevel(), n2 = w ? m.copyWithText(x) : s3.copyWithText(x), e2 = v + 1 - a2, r2 = this.blockList.splice(a2, e2, n2)), new this.constructor(r2));
          }, c.prototype.moveTextFromRangeToPosition = function(t3, e2) {
            var n2, o2, r2, s3, u2, c2, l2, h, p, d;
            return c2 = t3 = i(t3), p = c2[0], r2 = c2[1], e2 >= p && r2 >= e2 ? this : (o2 = this.getDocumentAtRange(t3), h = this.removeTextAtRange(t3), u2 = e2 > p, u2 && (e2 -= o2.getLength()), l2 = o2.getBlocks(), s3 = l2[0], n2 = 2 <= l2.length ? a.call(l2, 1) : [], n2.length === 0 ? (d = s3.getTextWithoutBlockBreak(), u2 && (e2 += 1)) : d = s3.text, h = h.insertTextAtRange(d, e2), n2.length === 0 ? h : (o2 = new this.constructor(n2), e2 += d.getLength(), h.insertDocumentAtRange(o2, e2)));
          }, c.prototype.addAttributeAtRange = function(t3, e2, i2) {
            var o2;
            return o2 = this.blockList, this.eachBlockAtRange(i2, function(i3, r2, s3) {
              return o2 = o2.editObjectAtIndex(s3, function() {
                return n(t3) ? i3.addAttribute(t3, e2) : r2[0] === r2[1] ? i3 : i3.copyWithText(i3.text.addAttributeAtRange(t3, e2, r2));
              });
            }), new this.constructor(o2);
          }, c.prototype.addAttribute = function(t3, e2) {
            var n2;
            return n2 = this.blockList, this.eachBlock(function(i2, o2) {
              return n2 = n2.editObjectAtIndex(o2, function() {
                return i2.addAttribute(t3, e2);
              });
            }), new this.constructor(n2);
          }, c.prototype.removeAttributeAtRange = function(t3, e2) {
            var i2;
            return i2 = this.blockList, this.eachBlockAtRange(e2, function(e3, o2, r2) {
              return n(t3) ? i2 = i2.editObjectAtIndex(r2, function() {
                return e3.removeAttribute(t3);
              }) : o2[0] !== o2[1] ? i2 = i2.editObjectAtIndex(r2, function() {
                return e3.copyWithText(e3.text.removeAttributeAtRange(t3, o2));
              }) : void 0;
            }), new this.constructor(i2);
          }, c.prototype.updateAttributesForAttachment = function(t3, e2) {
            var n2, i2, o2, r2;
            return o2 = (i2 = this.getRangeOfAttachment(e2))[0], n2 = this.locationFromPosition(o2).index, r2 = this.getTextAtIndex(n2), new this.constructor(this.blockList.editObjectAtIndex(n2, function(n3) {
              return n3.copyWithText(r2.updateAttributesForAttachment(t3, e2));
            }));
          }, c.prototype.removeAttributeForAttachment = function(t3, e2) {
            var n2;
            return n2 = this.getRangeOfAttachment(e2), this.removeAttributeAtRange(t3, n2);
          }, c.prototype.insertBlockBreakAtRange = function(t3) {
            var n2, o2, r2, s3;
            return s3 = (t3 = i(t3))[0], r2 = this.locationFromPosition(s3).offset, o2 = this.removeTextAtRange(t3), r2 === 0 && (n2 = [new e.Block()]), new this.constructor(o2.blockList.insertSplittableListAtPosition(new e.SplittableList(n2), s3));
          }, c.prototype.applyBlockAttributeAtRange = function(t3, e2, i2) {
            var o2, r2, s3, a2;
            return s3 = this.expandRangeToLineBreaksAndSplitBlocks(i2), r2 = s3.document, i2 = s3.range, o2 = n(t3), o2.listAttribute ? (r2 = r2.removeLastListAttributeAtRange(i2, {exceptAttributeName: t3}), a2 = r2.convertLineBreaksToBlockBreaksInRange(i2), r2 = a2.document, i2 = a2.range) : r2 = o2.exclusive ? r2.removeBlockAttributesAtRange(i2) : o2.terminal ? r2.removeLastTerminalAttributeAtRange(i2) : r2.consolidateBlocksAtRange(i2), r2.addAttributeAtRange(t3, e2, i2);
          }, c.prototype.removeLastListAttributeAtRange = function(t3, e2) {
            var i2;
            return e2 == null && (e2 = {}), i2 = this.blockList, this.eachBlockAtRange(t3, function(t4, o2, r2) {
              var s3;
              if ((s3 = t4.getLastAttribute()) && n(s3).listAttribute && s3 !== e2.exceptAttributeName)
                return i2 = i2.editObjectAtIndex(r2, function() {
                  return t4.removeAttribute(s3);
                });
            }), new this.constructor(i2);
          }, c.prototype.removeLastTerminalAttributeAtRange = function(t3) {
            var e2;
            return e2 = this.blockList, this.eachBlockAtRange(t3, function(t4, i2, o2) {
              var r2;
              if ((r2 = t4.getLastAttribute()) && n(r2).terminal)
                return e2 = e2.editObjectAtIndex(o2, function() {
                  return t4.removeAttribute(r2);
                });
            }), new this.constructor(e2);
          }, c.prototype.removeBlockAttributesAtRange = function(t3) {
            var e2;
            return e2 = this.blockList, this.eachBlockAtRange(t3, function(t4, n2, i2) {
              return t4.hasAttributes() ? e2 = e2.editObjectAtIndex(i2, function() {
                return t4.copyWithoutAttributes();
              }) : void 0;
            }), new this.constructor(e2);
          }, c.prototype.expandRangeToLineBreaksAndSplitBlocks = function(t3) {
            var e2, n2, o2, r2, s3, a2, u2, c2, l2;
            return a2 = t3 = i(t3), l2 = a2[0], r2 = a2[1], c2 = this.locationFromPosition(l2), o2 = this.locationFromPosition(r2), e2 = this, u2 = e2.getBlockAtIndex(c2.index), (c2.offset = u2.findLineBreakInDirectionFromPosition("backward", c2.offset)) != null && (s3 = e2.positionFromLocation(c2), e2 = e2.insertBlockBreakAtRange([s3, s3 + 1]), o2.index += 1, o2.offset -= e2.getBlockAtIndex(c2.index).getLength(), c2.index += 1), c2.offset = 0, o2.offset === 0 && o2.index > c2.index ? (o2.index -= 1, o2.offset = e2.getBlockAtIndex(o2.index).getBlockBreakPosition()) : (n2 = e2.getBlockAtIndex(o2.index), n2.text.getStringAtRange([o2.offset - 1, o2.offset]) === "\n" ? o2.offset -= 1 : o2.offset = n2.findLineBreakInDirectionFromPosition("forward", o2.offset), o2.offset !== n2.getBlockBreakPosition() && (s3 = e2.positionFromLocation(o2), e2 = e2.insertBlockBreakAtRange([s3, s3 + 1]))), l2 = e2.positionFromLocation(c2), r2 = e2.positionFromLocation(o2), t3 = i([l2, r2]), {document: e2, range: t3};
          }, c.prototype.convertLineBreaksToBlockBreaksInRange = function(t3) {
            var e2, n2, o2;
            return n2 = (t3 = i(t3))[0], o2 = this.getStringAtRange(t3).slice(0, -1), e2 = this, o2.replace(/.*?\n/g, function(t4) {
              return n2 += t4.length, e2 = e2.insertBlockBreakAtRange([n2 - 1, n2]);
            }), {document: e2, range: t3};
          }, c.prototype.consolidateBlocksAtRange = function(t3) {
            var e2, n2, o2, r2, s3;
            return o2 = t3 = i(t3), s3 = o2[0], n2 = o2[1], r2 = this.locationFromPosition(s3).index, e2 = this.locationFromPosition(n2).index, new this.constructor(this.blockList.consolidateFromIndexToIndex(r2, e2));
          }, c.prototype.getDocumentAtRange = function(t3) {
            var e2;
            return t3 = i(t3), e2 = this.blockList.getSplittableListInRange(t3).toArray(), new this.constructor(e2);
          }, c.prototype.getStringAtRange = function(t3) {
            var e2, n2, o2;
            return o2 = t3 = i(t3), n2 = o2[o2.length - 1], n2 !== this.getLength() && (e2 = -1), this.getDocumentAtRange(t3).toString().slice(0, e2);
          }, c.prototype.getBlockAtIndex = function(t3) {
            return this.blockList.getObjectAtIndex(t3);
          }, c.prototype.getBlockAtPosition = function(t3) {
            var e2;
            return e2 = this.locationFromPosition(t3).index, this.getBlockAtIndex(e2);
          }, c.prototype.getTextAtIndex = function(t3) {
            var e2;
            return (e2 = this.getBlockAtIndex(t3)) != null ? e2.text : void 0;
          }, c.prototype.getTextAtPosition = function(t3) {
            var e2;
            return e2 = this.locationFromPosition(t3).index, this.getTextAtIndex(e2);
          }, c.prototype.getPieceAtPosition = function(t3) {
            var e2, n2, i2;
            return i2 = this.locationFromPosition(t3), e2 = i2.index, n2 = i2.offset, this.getTextAtIndex(e2).getPieceAtPosition(n2);
          }, c.prototype.getCharacterAtPosition = function(t3) {
            var e2, n2, i2;
            return i2 = this.locationFromPosition(t3), e2 = i2.index, n2 = i2.offset, this.getTextAtIndex(e2).getStringAtRange([n2, n2 + 1]);
          }, c.prototype.getLength = function() {
            return this.blockList.getEndPosition();
          }, c.prototype.getBlocks = function() {
            return this.blockList.toArray();
          }, c.prototype.getBlockCount = function() {
            return this.blockList.length;
          }, c.prototype.getEditCount = function() {
            return this.editCount;
          }, c.prototype.eachBlock = function(t3) {
            return this.blockList.eachObject(t3);
          }, c.prototype.eachBlockAtRange = function(t3, e2) {
            var n2, o2, r2, s3, a2, u2, c2, l2, h, p, d, f;
            if (u2 = t3 = i(t3), d = u2[0], r2 = u2[1], p = this.locationFromPosition(d), o2 = this.locationFromPosition(r2), p.index === o2.index)
              return n2 = this.getBlockAtIndex(p.index), f = [p.offset, o2.offset], e2(n2, f, p.index);
            for (h = [], a2 = s3 = c2 = p.index, l2 = o2.index; l2 >= c2 ? l2 >= s3 : s3 >= l2; a2 = l2 >= c2 ? ++s3 : --s3)
              (n2 = this.getBlockAtIndex(a2)) ? (f = function() {
                switch (a2) {
                  case p.index:
                    return [p.offset, n2.text.getLength()];
                  case o2.index:
                    return [0, o2.offset];
                  default:
                    return [0, n2.text.getLength()];
                }
              }(), h.push(e2(n2, f, a2))) : h.push(void 0);
            return h;
          }, c.prototype.getCommonAttributesAtRange = function(t3) {
            var n2, r2, s3;
            return r2 = (t3 = i(t3))[0], o(t3) ? this.getCommonAttributesAtPosition(r2) : (s3 = [], n2 = [], this.eachBlockAtRange(t3, function(t4, e2) {
              return e2[0] !== e2[1] ? (s3.push(t4.text.getCommonAttributesAtRange(e2)), n2.push(l(t4))) : void 0;
            }), e.Hash.fromCommonAttributesOfObjects(s3).merge(e.Hash.fromCommonAttributesOfObjects(n2)).toObject());
          }, c.prototype.getCommonAttributesAtPosition = function(t3) {
            var n2, i2, o2, r2, s3, a2, c2, h, p, d;
            if (p = this.locationFromPosition(t3), s3 = p.index, h = p.offset, o2 = this.getBlockAtIndex(s3), !o2)
              return {};
            r2 = l(o2), n2 = o2.text.getAttributesAtPosition(h), i2 = o2.text.getAttributesAtPosition(h - 1), a2 = function() {
              var t4, n3;
              t4 = e.config.textAttributes, n3 = [];
              for (c2 in t4)
                d = t4[c2], d.inheritable && n3.push(c2);
              return n3;
            }();
            for (c2 in i2)
              d = i2[c2], (d === n2[c2] || u.call(a2, c2) >= 0) && (r2[c2] = d);
            return r2;
          }, c.prototype.getRangeOfCommonAttributeAtPosition = function(t3, e2) {
            var n2, o2, r2, s3, a2, u2, c2, l2, h;
            return a2 = this.locationFromPosition(e2), r2 = a2.index, s3 = a2.offset, h = this.getTextAtIndex(r2), u2 = h.getExpandedRangeForAttributeAtOffset(t3, s3), l2 = u2[0], o2 = u2[1], c2 = this.positionFromLocation({index: r2, offset: l2}), n2 = this.positionFromLocation({index: r2, offset: o2}), i([c2, n2]);
          }, c.prototype.getBaseBlockAttributes = function() {
            var t3, e2, n2, i2, o2, r2, s3;
            for (t3 = this.getBlockAtIndex(0).getAttributes(), n2 = i2 = 1, s3 = this.getBlockCount(); s3 >= 1 ? s3 > i2 : i2 > s3; n2 = s3 >= 1 ? ++i2 : --i2)
              e2 = this.getBlockAtIndex(n2).getAttributes(), r2 = Math.min(t3.length, e2.length), t3 = function() {
                var n3, i3, s4;
                for (s4 = [], o2 = n3 = 0, i3 = r2; (i3 >= 0 ? i3 > n3 : n3 > i3) && e2[o2] === t3[o2]; o2 = i3 >= 0 ? ++n3 : --n3)
                  s4.push(e2[o2]);
                return s4;
              }();
            return t3;
          }, l = function(t3) {
            var e2, n2;
            return n2 = {}, (e2 = t3.getLastAttribute()) && (n2[e2] = true), n2;
          }, c.prototype.getAttachmentById = function(t3) {
            var e2, n2, i2, o2;
            for (o2 = this.getAttachments(), n2 = 0, i2 = o2.length; i2 > n2; n2++)
              if (e2 = o2[n2], e2.id === t3)
                return e2;
          }, c.prototype.getAttachmentPieces = function() {
            var t3;
            return t3 = [], this.blockList.eachObject(function(e2) {
              var n2;
              return n2 = e2.text, t3 = t3.concat(n2.getAttachmentPieces());
            }), t3;
          }, c.prototype.getAttachments = function() {
            var t3, e2, n2, i2, o2;
            for (i2 = this.getAttachmentPieces(), o2 = [], t3 = 0, e2 = i2.length; e2 > t3; t3++)
              n2 = i2[t3], o2.push(n2.attachment);
            return o2;
          }, c.prototype.getRangeOfAttachment = function(t3) {
            var e2, n2, o2, r2, s3, a2, u2;
            for (r2 = 0, s3 = this.blockList.toArray(), n2 = e2 = 0, o2 = s3.length; o2 > e2; n2 = ++e2) {
              if (a2 = s3[n2].text, u2 = a2.getRangeOfAttachment(t3))
                return i([r2 + u2[0], r2 + u2[1]]);
              r2 += a2.getLength();
            }
          }, c.prototype.getLocationRangeOfAttachment = function(t3) {
            var e2;
            return e2 = this.getRangeOfAttachment(t3), this.locationRangeFromRange(e2);
          }, c.prototype.getAttachmentPieceForAttachment = function(t3) {
            var e2, n2, i2, o2;
            for (o2 = this.getAttachmentPieces(), e2 = 0, n2 = o2.length; n2 > e2; e2++)
              if (i2 = o2[e2], i2.attachment === t3)
                return i2;
          }, c.prototype.findRangesForBlockAttribute = function(t3) {
            var e2, n2, i2, o2, r2, s3, a2;
            for (r2 = 0, s3 = [], a2 = this.getBlocks(), n2 = 0, i2 = a2.length; i2 > n2; n2++)
              e2 = a2[n2], o2 = e2.getLength(), e2.hasAttribute(t3) && s3.push([r2, r2 + o2]), r2 += o2;
            return s3;
          }, c.prototype.findRangesForTextAttribute = function(t3, e2) {
            var n2, i2, o2, r2, s3, a2, u2, c2, l2, h;
            for (h = (e2 != null ? e2 : {}).withValue, a2 = 0, u2 = [], c2 = [], r2 = function(e3) {
              return h != null ? e3.getAttribute(t3) === h : e3.hasAttribute(t3);
            }, l2 = this.getPieces(), n2 = 0, i2 = l2.length; i2 > n2; n2++)
              s3 = l2[n2], o2 = s3.getLength(), r2(s3) && (u2[1] === a2 ? u2[1] = a2 + o2 : c2.push(u2 = [a2, a2 + o2])), a2 += o2;
            return c2;
          }, c.prototype.locationFromPosition = function(t3) {
            var e2, n2;
            return n2 = this.blockList.findIndexAndOffsetAtPosition(Math.max(0, t3)), n2.index != null ? n2 : (e2 = this.getBlocks(), {index: e2.length - 1, offset: e2[e2.length - 1].getLength()});
          }, c.prototype.positionFromLocation = function(t3) {
            return this.blockList.findPositionAtIndexAndOffset(t3.index, t3.offset);
          }, c.prototype.locationRangeFromPosition = function(t3) {
            return i(this.locationFromPosition(t3));
          }, c.prototype.locationRangeFromRange = function(t3) {
            var e2, n2, o2, r2;
            if (t3 = i(t3))
              return r2 = t3[0], n2 = t3[1], o2 = this.locationFromPosition(r2), e2 = this.locationFromPosition(n2), i([o2, e2]);
          }, c.prototype.rangeFromLocationRange = function(t3) {
            var e2, n2;
            return t3 = i(t3), e2 = this.positionFromLocation(t3[0]), o(t3) || (n2 = this.positionFromLocation(t3[1])), i([e2, n2]);
          }, c.prototype.isEqualTo = function(t3) {
            return this.blockList.isEqualTo(t3 != null ? t3.blockList : void 0);
          }, c.prototype.getTexts = function() {
            var t3, e2, n2, i2, o2;
            for (i2 = this.getBlocks(), o2 = [], e2 = 0, n2 = i2.length; n2 > e2; e2++)
              t3 = i2[e2], o2.push(t3.text);
            return o2;
          }, c.prototype.getPieces = function() {
            var t3, e2, n2, i2, o2;
            for (n2 = [], i2 = this.getTexts(), t3 = 0, e2 = i2.length; e2 > t3; t3++)
              o2 = i2[t3], n2.push.apply(n2, o2.getPieces());
            return n2;
          }, c.prototype.getObjects = function() {
            return this.getBlocks().concat(this.getTexts()).concat(this.getPieces());
          }, c.prototype.toSerializableDocument = function() {
            var t3;
            return t3 = [], this.blockList.eachObject(function(e2) {
              return t3.push(e2.copyWithText(e2.text.toSerializableText()));
            }), new this.constructor(t3);
          }, c.prototype.toString = function() {
            return this.blockList.toString();
          }, c.prototype.toJSON = function() {
            return this.blockList.toJSON();
          }, c.prototype.toConsole = function() {
            var t3;
            return JSON.stringify(function() {
              var e2, n2, i2, o2;
              for (i2 = this.blockList.toArray(), o2 = [], e2 = 0, n2 = i2.length; n2 > e2; e2++)
                t3 = i2[e2], o2.push(JSON.parse(t3.text.toConsole()));
              return o2;
            }.call(this));
          }, c;
        }(e.Object);
      }.call(this), function() {
        e.LineBreakInsertion = function() {
          function t2(t3) {
            var e2;
            this.composition = t3, this.document = this.composition.document, e2 = this.composition.getSelectedRange(), this.startPosition = e2[0], this.endPosition = e2[1], this.startLocation = this.document.locationFromPosition(this.startPosition), this.endLocation = this.document.locationFromPosition(this.endPosition), this.block = this.document.getBlockAtIndex(this.endLocation.index), this.breaksOnReturn = this.block.breaksOnReturn(), this.previousCharacter = this.block.text.getStringAtPosition(this.endLocation.offset - 1), this.nextCharacter = this.block.text.getStringAtPosition(this.endLocation.offset);
          }
          return t2.prototype.shouldInsertBlockBreak = function() {
            return this.block.hasAttributes() && this.block.isListItem() && !this.block.isEmpty() ? this.startLocation.offset !== 0 : this.breaksOnReturn && this.nextCharacter !== "\n";
          }, t2.prototype.shouldBreakFormattedBlock = function() {
            return this.block.hasAttributes() && !this.block.isListItem() && (this.breaksOnReturn && this.nextCharacter === "\n" || this.previousCharacter === "\n");
          }, t2.prototype.shouldDecreaseListLevel = function() {
            return this.block.hasAttributes() && this.block.isListItem() && this.block.isEmpty();
          }, t2.prototype.shouldPrependListItem = function() {
            return this.block.isListItem() && this.startLocation.offset === 0 && !this.block.isEmpty();
          }, t2.prototype.shouldRemoveLastBlockAttribute = function() {
            return this.block.hasAttributes() && !this.block.isListItem() && this.block.isEmpty();
          }, t2;
        }();
      }.call(this), function() {
        var t2, n, i, o, r, s, a, u, c, l, h = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var i2 in e2)
            p.call(e2, i2) && (t3[i2] = e2[i2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, p = {}.hasOwnProperty;
        s = e.normalizeRange, c = e.rangesAreEqual, u = e.rangeIsCollapsed, a = e.objectsAreEqual, t2 = e.arrayStartsWith, l = e.summarizeArrayChange, i = e.getAllAttributeNames, o = e.getBlockConfig, r = e.getTextConfig, n = e.extend, e.Composition = function(p2) {
          function d() {
            this.document = new e.Document(), this.attachments = [], this.currentAttributes = {}, this.revision = 0;
          }
          var f;
          return h(d, p2), d.prototype.setDocument = function(t3) {
            var e2;
            return t3.isEqualTo(this.document) ? void 0 : (this.document = t3, this.refreshAttachments(), this.revision++, (e2 = this.delegate) != null && typeof e2.compositionDidChangeDocument == "function" ? e2.compositionDidChangeDocument(t3) : void 0);
          }, d.prototype.getSnapshot = function() {
            return {document: this.document, selectedRange: this.getSelectedRange()};
          }, d.prototype.loadSnapshot = function(t3) {
            var n2, i2, o2, r2;
            return n2 = t3.document, r2 = t3.selectedRange, (i2 = this.delegate) != null && typeof i2.compositionWillLoadSnapshot == "function" && i2.compositionWillLoadSnapshot(), this.setDocument(n2 != null ? n2 : new e.Document()), this.setSelection(r2 != null ? r2 : [0, 0]), (o2 = this.delegate) != null && typeof o2.compositionDidLoadSnapshot == "function" ? o2.compositionDidLoadSnapshot() : void 0;
          }, d.prototype.insertText = function(t3, e2) {
            var n2, i2, o2, r2;
            return r2 = (e2 != null ? e2 : {updatePosition: true}).updatePosition, i2 = this.getSelectedRange(), this.setDocument(this.document.insertTextAtRange(t3, i2)), o2 = i2[0], n2 = o2 + t3.getLength(), r2 && this.setSelection(n2), this.notifyDelegateOfInsertionAtRange([o2, n2]);
          }, d.prototype.insertBlock = function(t3) {
            var n2;
            return t3 == null && (t3 = new e.Block()), n2 = new e.Document([t3]), this.insertDocument(n2);
          }, d.prototype.insertDocument = function(t3) {
            var n2, i2, o2;
            return t3 == null && (t3 = new e.Document()), i2 = this.getSelectedRange(), this.setDocument(this.document.insertDocumentAtRange(t3, i2)), o2 = i2[0], n2 = o2 + t3.getLength(), this.setSelection(n2), this.notifyDelegateOfInsertionAtRange([o2, n2]);
          }, d.prototype.insertString = function(t3, n2) {
            var i2, o2;
            return i2 = this.getCurrentTextAttributes(), o2 = e.Text.textForStringWithAttributes(t3, i2), this.insertText(o2, n2);
          }, d.prototype.insertBlockBreak = function() {
            var t3, e2, n2;
            return e2 = this.getSelectedRange(), this.setDocument(this.document.insertBlockBreakAtRange(e2)), n2 = e2[0], t3 = n2 + 1, this.setSelection(t3), this.notifyDelegateOfInsertionAtRange([n2, t3]);
          }, d.prototype.insertLineBreak = function() {
            var t3, n2;
            return n2 = new e.LineBreakInsertion(this), n2.shouldDecreaseListLevel() ? (this.decreaseListLevel(), this.setSelection(n2.startPosition)) : n2.shouldPrependListItem() ? (t3 = new e.Document([n2.block.copyWithoutText()]), this.insertDocument(t3)) : n2.shouldInsertBlockBreak() ? this.insertBlockBreak() : n2.shouldRemoveLastBlockAttribute() ? this.removeLastBlockAttribute() : n2.shouldBreakFormattedBlock() ? this.breakFormattedBlock(n2) : this.insertString("\n");
          }, d.prototype.insertHTML = function(t3) {
            var n2, i2, o2, r2;
            return n2 = e.Document.fromHTML(t3), o2 = this.getSelectedRange(), this.setDocument(this.document.mergeDocumentAtRange(n2, o2)), r2 = o2[0], i2 = r2 + n2.getLength() - 1, this.setSelection(i2), this.notifyDelegateOfInsertionAtRange([r2, i2]);
          }, d.prototype.replaceHTML = function(t3) {
            var n2, i2, o2;
            return n2 = e.Document.fromHTML(t3).copyUsingObjectsFromDocument(this.document), i2 = this.getLocationRange({strict: false}), o2 = this.document.rangeFromLocationRange(i2), this.setDocument(n2), this.setSelection(o2);
          }, d.prototype.insertFile = function(t3) {
            return this.insertFiles([t3]);
          }, d.prototype.insertFiles = function(t3) {
            var n2, i2, o2, r2, s2, a2;
            for (i2 = [], r2 = 0, s2 = t3.length; s2 > r2; r2++)
              o2 = t3[r2], ((a2 = this.delegate) != null ? a2.compositionShouldAcceptFile(o2) : void 0) && (n2 = e.Attachment.attachmentForFile(o2), i2.push(n2));
            return this.insertAttachments(i2);
          }, d.prototype.insertAttachment = function(t3) {
            return this.insertAttachments([t3]);
          }, d.prototype.insertAttachments = function(t3) {
            var n2, i2, o2, r2, s2, a2, u2, c2, l2;
            for (c2 = new e.Text(), r2 = 0, s2 = t3.length; s2 > r2; r2++)
              n2 = t3[r2], l2 = n2.getType(), a2 = (u2 = e.config.attachments[l2]) != null ? u2.presentation : void 0, o2 = this.getCurrentTextAttributes(), a2 && (o2.presentation = a2), i2 = e.Text.textForAttachmentWithAttributes(n2, o2), c2 = c2.appendText(i2);
            return this.insertText(c2);
          }, d.prototype.shouldManageDeletingInDirection = function(t3) {
            var e2;
            if (e2 = this.getLocationRange(), u(e2)) {
              if (t3 === "backward" && e2[0].offset === 0)
                return true;
              if (this.shouldManageMovingCursorInDirection(t3))
                return true;
            } else if (e2[0].index !== e2[1].index)
              return true;
            return false;
          }, d.prototype.deleteInDirection = function(t3, e2) {
            var n2, i2, o2, r2, s2, a2, c2, l2;
            return r2 = (e2 != null ? e2 : {}).length, s2 = this.getLocationRange(), a2 = this.getSelectedRange(), c2 = u(a2), c2 ? o2 = t3 === "backward" && s2[0].offset === 0 : l2 = s2[0].index !== s2[1].index, o2 && this.canDecreaseBlockAttributeLevel() && (i2 = this.getBlock(), i2.isListItem() ? this.decreaseListLevel() : this.decreaseBlockAttributeLevel(), this.setSelection(a2[0]), i2.isEmpty()) ? false : (c2 && (a2 = this.getExpandedRangeInDirection(t3, {length: r2}), t3 === "backward" && (n2 = this.getAttachmentAtRange(a2))), n2 ? (this.editAttachment(n2), false) : (this.setDocument(this.document.removeTextAtRange(a2)), this.setSelection(a2[0]), o2 || l2 ? false : void 0));
          }, d.prototype.moveTextFromRange = function(t3) {
            var e2;
            return e2 = this.getSelectedRange()[0], this.setDocument(this.document.moveTextFromRangeToPosition(t3, e2)), this.setSelection(e2);
          }, d.prototype.removeAttachment = function(t3) {
            var e2;
            return (e2 = this.document.getRangeOfAttachment(t3)) ? (this.stopEditingAttachment(), this.setDocument(this.document.removeTextAtRange(e2)), this.setSelection(e2[0])) : void 0;
          }, d.prototype.removeLastBlockAttribute = function() {
            var t3, e2, n2, i2;
            return n2 = this.getSelectedRange(), i2 = n2[0], e2 = n2[1], t3 = this.document.getBlockAtPosition(e2), this.removeCurrentAttribute(t3.getLastAttribute()), this.setSelection(i2);
          }, f = " ", d.prototype.insertPlaceholder = function() {
            return this.placeholderPosition = this.getPosition(), this.insertString(f);
          }, d.prototype.selectPlaceholder = function() {
            return this.placeholderPosition != null ? (this.setSelectedRange([this.placeholderPosition, this.placeholderPosition + f.length]), this.getSelectedRange()) : void 0;
          }, d.prototype.forgetPlaceholder = function() {
            return this.placeholderPosition = null;
          }, d.prototype.hasCurrentAttribute = function(t3) {
            var e2;
            return e2 = this.currentAttributes[t3], e2 != null && e2 !== false;
          }, d.prototype.toggleCurrentAttribute = function(t3) {
            var e2;
            return (e2 = !this.currentAttributes[t3]) ? this.setCurrentAttribute(t3, e2) : this.removeCurrentAttribute(t3);
          }, d.prototype.canSetCurrentAttribute = function(t3) {
            return o(t3) ? this.canSetCurrentBlockAttribute(t3) : this.canSetCurrentTextAttribute(t3);
          }, d.prototype.canSetCurrentTextAttribute = function() {
            var t3, e2, n2, i2, o2;
            if (e2 = this.getSelectedDocument()) {
              for (o2 = e2.getAttachments(), n2 = 0, i2 = o2.length; i2 > n2; n2++)
                if (t3 = o2[n2], !t3.hasContent())
                  return false;
              return true;
            }
          }, d.prototype.canSetCurrentBlockAttribute = function() {
            var t3;
            if (t3 = this.getBlock())
              return !t3.isTerminalBlock();
          }, d.prototype.setCurrentAttribute = function(t3, e2) {
            return o(t3) ? this.setBlockAttribute(t3, e2) : (this.setTextAttribute(t3, e2), this.currentAttributes[t3] = e2, this.notifyDelegateOfCurrentAttributesChange());
          }, d.prototype.setTextAttribute = function(t3, n2) {
            var i2, o2, r2, s2;
            if (o2 = this.getSelectedRange())
              return r2 = o2[0], i2 = o2[1], r2 !== i2 ? this.setDocument(this.document.addAttributeAtRange(t3, n2, o2)) : t3 === "href" ? (s2 = e.Text.textForStringWithAttributes(n2, {href: n2}), this.insertText(s2)) : void 0;
          }, d.prototype.setBlockAttribute = function(t3, e2) {
            var n2, i2;
            if (i2 = this.getSelectedRange())
              return this.canSetCurrentAttribute(t3) ? (n2 = this.getBlock(), this.setDocument(this.document.applyBlockAttributeAtRange(t3, e2, i2)), this.setSelection(i2)) : void 0;
          }, d.prototype.removeCurrentAttribute = function(t3) {
            return o(t3) ? (this.removeBlockAttribute(t3), this.updateCurrentAttributes()) : (this.removeTextAttribute(t3), delete this.currentAttributes[t3], this.notifyDelegateOfCurrentAttributesChange());
          }, d.prototype.removeTextAttribute = function(t3) {
            var e2;
            if (e2 = this.getSelectedRange())
              return this.setDocument(this.document.removeAttributeAtRange(t3, e2));
          }, d.prototype.removeBlockAttribute = function(t3) {
            var e2;
            if (e2 = this.getSelectedRange())
              return this.setDocument(this.document.removeAttributeAtRange(t3, e2));
          }, d.prototype.canDecreaseNestingLevel = function() {
            var t3;
            return ((t3 = this.getBlock()) != null ? t3.getNestingLevel() : void 0) > 0;
          }, d.prototype.canIncreaseNestingLevel = function() {
            var e2, n2, i2;
            if (e2 = this.getBlock())
              return ((i2 = o(e2.getLastNestableAttribute())) != null ? i2.listAttribute : 0) ? (n2 = this.getPreviousBlock()) ? t2(n2.getListItemAttributes(), e2.getListItemAttributes()) : void 0 : e2.getNestingLevel() > 0;
          }, d.prototype.decreaseNestingLevel = function() {
            var t3;
            if (t3 = this.getBlock())
              return this.setDocument(this.document.replaceBlock(t3, t3.decreaseNestingLevel()));
          }, d.prototype.increaseNestingLevel = function() {
            var t3;
            if (t3 = this.getBlock())
              return this.setDocument(this.document.replaceBlock(t3, t3.increaseNestingLevel()));
          }, d.prototype.canDecreaseBlockAttributeLevel = function() {
            var t3;
            return ((t3 = this.getBlock()) != null ? t3.getAttributeLevel() : void 0) > 0;
          }, d.prototype.decreaseBlockAttributeLevel = function() {
            var t3, e2;
            return (t3 = (e2 = this.getBlock()) != null ? e2.getLastAttribute() : void 0) ? this.removeCurrentAttribute(t3) : void 0;
          }, d.prototype.decreaseListLevel = function() {
            var t3, e2, n2, i2, o2, r2;
            for (r2 = this.getSelectedRange()[0], o2 = this.document.locationFromPosition(r2).index, n2 = o2, t3 = this.getBlock().getAttributeLevel(); (e2 = this.document.getBlockAtIndex(n2 + 1)) && e2.isListItem() && e2.getAttributeLevel() > t3; )
              n2++;
            return r2 = this.document.positionFromLocation({index: o2, offset: 0}), i2 = this.document.positionFromLocation({index: n2, offset: 0}), this.setDocument(this.document.removeLastListAttributeAtRange([r2, i2]));
          }, d.prototype.updateCurrentAttributes = function() {
            var t3, e2, n2, o2, r2, s2;
            if (s2 = this.getSelectedRange({ignoreLock: true})) {
              for (e2 = this.document.getCommonAttributesAtRange(s2), r2 = i(), n2 = 0, o2 = r2.length; o2 > n2; n2++)
                t3 = r2[n2], e2[t3] || this.canSetCurrentAttribute(t3) || (e2[t3] = false);
              if (!a(e2, this.currentAttributes))
                return this.currentAttributes = e2, this.notifyDelegateOfCurrentAttributesChange();
            }
          }, d.prototype.getCurrentAttributes = function() {
            return n.call({}, this.currentAttributes);
          }, d.prototype.getCurrentTextAttributes = function() {
            var t3, e2, n2, i2;
            t3 = {}, n2 = this.currentAttributes;
            for (e2 in n2)
              i2 = n2[e2], i2 !== false && r(e2) && (t3[e2] = i2);
            return t3;
          }, d.prototype.freezeSelection = function() {
            return this.setCurrentAttribute("frozen", true);
          }, d.prototype.thawSelection = function() {
            return this.removeCurrentAttribute("frozen");
          }, d.prototype.hasFrozenSelection = function() {
            return this.hasCurrentAttribute("frozen");
          }, d.proxyMethod("getSelectionManager().getPointRange"), d.proxyMethod("getSelectionManager().setLocationRangeFromPointRange"), d.proxyMethod("getSelectionManager().createLocationRangeFromDOMRange"), d.proxyMethod("getSelectionManager().locationIsCursorTarget"), d.proxyMethod("getSelectionManager().selectionIsExpanded"), d.proxyMethod("delegate?.getSelectionManager"), d.prototype.setSelection = function(t3) {
            var e2, n2;
            return e2 = this.document.locationRangeFromRange(t3), (n2 = this.delegate) != null ? n2.compositionDidRequestChangingSelectionToLocationRange(e2) : void 0;
          }, d.prototype.getSelectedRange = function() {
            var t3;
            return (t3 = this.getLocationRange()) ? this.document.rangeFromLocationRange(t3) : void 0;
          }, d.prototype.setSelectedRange = function(t3) {
            var e2;
            return e2 = this.document.locationRangeFromRange(t3), this.getSelectionManager().setLocationRange(e2);
          }, d.prototype.getPosition = function() {
            var t3;
            return (t3 = this.getLocationRange()) ? this.document.positionFromLocation(t3[0]) : void 0;
          }, d.prototype.getLocationRange = function(t3) {
            var e2, n2;
            return (e2 = (n2 = this.targetLocationRange) != null ? n2 : this.getSelectionManager().getLocationRange(t3)) != null ? e2 : s({index: 0, offset: 0});
          }, d.prototype.withTargetLocationRange = function(t3, e2) {
            var n2;
            this.targetLocationRange = t3;
            try {
              n2 = e2();
            } finally {
              this.targetLocationRange = null;
            }
            return n2;
          }, d.prototype.withTargetRange = function(t3, e2) {
            var n2;
            return n2 = this.document.locationRangeFromRange(t3), this.withTargetLocationRange(n2, e2);
          }, d.prototype.withTargetDOMRange = function(t3, e2) {
            var n2;
            return n2 = this.createLocationRangeFromDOMRange(t3, {strict: false}), this.withTargetLocationRange(n2, e2);
          }, d.prototype.getExpandedRangeInDirection = function(t3, e2) {
            var n2, i2, o2, r2;
            return i2 = (e2 != null ? e2 : {}).length, o2 = this.getSelectedRange(), r2 = o2[0], n2 = o2[1], t3 === "backward" ? i2 ? r2 -= i2 : r2 = this.translateUTF16PositionFromOffset(r2, -1) : i2 ? n2 += i2 : n2 = this.translateUTF16PositionFromOffset(n2, 1), s([r2, n2]);
          }, d.prototype.shouldManageMovingCursorInDirection = function(t3) {
            var e2;
            return this.editingAttachment ? true : (e2 = this.getExpandedRangeInDirection(t3), this.getAttachmentAtRange(e2) != null);
          }, d.prototype.moveCursorInDirection = function(t3) {
            var e2, n2, i2, o2;
            return this.editingAttachment ? i2 = this.document.getRangeOfAttachment(this.editingAttachment) : (o2 = this.getSelectedRange(), i2 = this.getExpandedRangeInDirection(t3), n2 = !c(o2, i2)), this.setSelectedRange(t3 === "backward" ? i2[0] : i2[1]), n2 && (e2 = this.getAttachmentAtRange(i2)) ? this.editAttachment(e2) : void 0;
          }, d.prototype.expandSelectionInDirection = function(t3, e2) {
            var n2, i2;
            return n2 = (e2 != null ? e2 : {}).length, i2 = this.getExpandedRangeInDirection(t3, {length: n2}), this.setSelectedRange(i2);
          }, d.prototype.expandSelectionForEditing = function() {
            return this.hasCurrentAttribute("href") ? this.expandSelectionAroundCommonAttribute("href") : void 0;
          }, d.prototype.expandSelectionAroundCommonAttribute = function(t3) {
            var e2, n2;
            return e2 = this.getPosition(), n2 = this.document.getRangeOfCommonAttributeAtPosition(t3, e2), this.setSelectedRange(n2);
          }, d.prototype.selectionContainsAttachments = function() {
            var t3;
            return ((t3 = this.getSelectedAttachments()) != null ? t3.length : void 0) > 0;
          }, d.prototype.selectionIsInCursorTarget = function() {
            return this.editingAttachment || this.positionIsCursorTarget(this.getPosition());
          }, d.prototype.positionIsCursorTarget = function(t3) {
            var e2;
            return (e2 = this.document.locationFromPosition(t3)) ? this.locationIsCursorTarget(e2) : void 0;
          }, d.prototype.positionIsBlockBreak = function(t3) {
            var e2;
            return (e2 = this.document.getPieceAtPosition(t3)) != null ? e2.isBlockBreak() : void 0;
          }, d.prototype.getSelectedDocument = function() {
            var t3;
            return (t3 = this.getSelectedRange()) ? this.document.getDocumentAtRange(t3) : void 0;
          }, d.prototype.getSelectedAttachments = function() {
            var t3;
            return (t3 = this.getSelectedDocument()) != null ? t3.getAttachments() : void 0;
          }, d.prototype.getAttachments = function() {
            return this.attachments.slice(0);
          }, d.prototype.refreshAttachments = function() {
            var t3, e2, n2, i2, o2, r2, s2, a2, u2, c2, h2, p3;
            for (n2 = this.document.getAttachments(), a2 = l(this.attachments, n2), t3 = a2.added, h2 = a2.removed, this.attachments = n2, i2 = 0, r2 = h2.length; r2 > i2; i2++)
              e2 = h2[i2], e2.delegate = null, (u2 = this.delegate) != null && typeof u2.compositionDidRemoveAttachment == "function" && u2.compositionDidRemoveAttachment(e2);
            for (p3 = [], o2 = 0, s2 = t3.length; s2 > o2; o2++)
              e2 = t3[o2], e2.delegate = this, p3.push((c2 = this.delegate) != null && typeof c2.compositionDidAddAttachment == "function" ? c2.compositionDidAddAttachment(e2) : void 0);
            return p3;
          }, d.prototype.attachmentDidChangeAttributes = function(t3) {
            var e2;
            return this.revision++, (e2 = this.delegate) != null && typeof e2.compositionDidEditAttachment == "function" ? e2.compositionDidEditAttachment(t3) : void 0;
          }, d.prototype.attachmentDidChangePreviewURL = function(t3) {
            var e2;
            return this.revision++, (e2 = this.delegate) != null && typeof e2.compositionDidChangeAttachmentPreviewURL == "function" ? e2.compositionDidChangeAttachmentPreviewURL(t3) : void 0;
          }, d.prototype.editAttachment = function(t3, e2) {
            var n2;
            if (t3 !== this.editingAttachment)
              return this.stopEditingAttachment(), this.editingAttachment = t3, (n2 = this.delegate) != null && typeof n2.compositionDidStartEditingAttachment == "function" ? n2.compositionDidStartEditingAttachment(this.editingAttachment, e2) : void 0;
          }, d.prototype.stopEditingAttachment = function() {
            var t3;
            if (this.editingAttachment)
              return (t3 = this.delegate) != null && typeof t3.compositionDidStopEditingAttachment == "function" && t3.compositionDidStopEditingAttachment(this.editingAttachment), this.editingAttachment = null;
          }, d.prototype.updateAttributesForAttachment = function(t3, e2) {
            return this.setDocument(this.document.updateAttributesForAttachment(t3, e2));
          }, d.prototype.removeAttributeForAttachment = function(t3, e2) {
            return this.setDocument(this.document.removeAttributeForAttachment(t3, e2));
          }, d.prototype.breakFormattedBlock = function(t3) {
            var n2, i2, o2, r2, s2;
            return i2 = t3.document, n2 = t3.block, r2 = t3.startPosition, s2 = [r2 - 1, r2], n2.getBlockBreakPosition() === t3.startLocation.offset ? (n2.breaksOnReturn() && t3.nextCharacter === "\n" ? r2 += 1 : i2 = i2.removeTextAtRange(s2), s2 = [r2, r2]) : t3.nextCharacter === "\n" ? t3.previousCharacter === "\n" ? s2 = [r2 - 1, r2 + 1] : (s2 = [r2, r2 + 1], r2 += 1) : t3.startLocation.offset - 1 !== 0 && (r2 += 1), o2 = new e.Document([n2.removeLastAttribute().copyWithoutText()]), this.setDocument(i2.insertDocumentAtRange(o2, s2)), this.setSelection(r2);
          }, d.prototype.getPreviousBlock = function() {
            var t3, e2;
            return (e2 = this.getLocationRange()) && (t3 = e2[0].index, t3 > 0) ? this.document.getBlockAtIndex(t3 - 1) : void 0;
          }, d.prototype.getBlock = function() {
            var t3;
            return (t3 = this.getLocationRange()) ? this.document.getBlockAtIndex(t3[0].index) : void 0;
          }, d.prototype.getAttachmentAtRange = function(t3) {
            var n2;
            return n2 = this.document.getDocumentAtRange(t3), n2.toString() === e.OBJECT_REPLACEMENT_CHARACTER + "\n" ? n2.getAttachments()[0] : void 0;
          }, d.prototype.notifyDelegateOfCurrentAttributesChange = function() {
            var t3;
            return (t3 = this.delegate) != null && typeof t3.compositionDidChangeCurrentAttributes == "function" ? t3.compositionDidChangeCurrentAttributes(this.currentAttributes) : void 0;
          }, d.prototype.notifyDelegateOfInsertionAtRange = function(t3) {
            var e2;
            return (e2 = this.delegate) != null && typeof e2.compositionDidPerformInsertionAtRange == "function" ? e2.compositionDidPerformInsertionAtRange(t3) : void 0;
          }, d.prototype.translateUTF16PositionFromOffset = function(t3, e2) {
            var n2, i2;
            return i2 = this.document.toUTF16String(), n2 = i2.offsetFromUCS2Offset(t3), i2.offsetToUCS2Offset(n2 + e2);
          }, d;
        }(e.BasicObject);
      }.call(this), function() {
        var t2 = function(t3, e2) {
          function i() {
            this.constructor = t3;
          }
          for (var o in e2)
            n.call(e2, o) && (t3[o] = e2[o]);
          return i.prototype = e2.prototype, t3.prototype = new i(), t3.__super__ = e2.prototype, t3;
        }, n = {}.hasOwnProperty;
        e.UndoManager = function(e2) {
          function n2(t3) {
            this.composition = t3, this.undoEntries = [], this.redoEntries = [];
          }
          var i;
          return t2(n2, e2), n2.prototype.recordUndoEntry = function(t3, e3) {
            var n3, o, r, s, a;
            return s = e3 != null ? e3 : {}, o = s.context, n3 = s.consolidatable, r = this.undoEntries.slice(-1)[0], n3 && i(r, t3, o) ? void 0 : (a = this.createEntry({description: t3, context: o}), this.undoEntries.push(a), this.redoEntries = []);
          }, n2.prototype.undo = function() {
            var t3, e3;
            return (e3 = this.undoEntries.pop()) ? (t3 = this.createEntry(e3), this.redoEntries.push(t3), this.composition.loadSnapshot(e3.snapshot)) : void 0;
          }, n2.prototype.redo = function() {
            var t3, e3;
            return (t3 = this.redoEntries.pop()) ? (e3 = this.createEntry(t3), this.undoEntries.push(e3), this.composition.loadSnapshot(t3.snapshot)) : void 0;
          }, n2.prototype.canUndo = function() {
            return this.undoEntries.length > 0;
          }, n2.prototype.canRedo = function() {
            return this.redoEntries.length > 0;
          }, n2.prototype.createEntry = function(t3) {
            var e3, n3, i2;
            return i2 = t3 != null ? t3 : {}, n3 = i2.description, e3 = i2.context, {description: n3 != null ? n3.toString() : void 0, context: JSON.stringify(e3), snapshot: this.composition.getSnapshot()};
          }, i = function(t3, e3, n3) {
            return (t3 != null ? t3.description : void 0) === (e3 != null ? e3.toString() : void 0) && (t3 != null ? t3.context : void 0) === JSON.stringify(n3);
          }, n2;
        }(e.BasicObject);
      }.call(this), function() {
        var t2;
        e.attachmentGalleryFilter = function(e2) {
          var n;
          return n = new t2(e2), n.perform(), n.getSnapshot();
        }, t2 = function() {
          function t3(t4) {
            this.document = t4.document, this.selectedRange = t4.selectedRange;
          }
          var e2, n, i;
          return e2 = "attachmentGallery", n = "presentation", i = "gallery", t3.prototype.perform = function() {
            return this.removeBlockAttribute(), this.applyBlockAttribute();
          }, t3.prototype.getSnapshot = function() {
            return {document: this.document, selectedRange: this.selectedRange};
          }, t3.prototype.removeBlockAttribute = function() {
            var t4, n2, i2, o, r;
            for (o = this.findRangesOfBlocks(), r = [], t4 = 0, n2 = o.length; n2 > t4; t4++)
              i2 = o[t4], r.push(this.document = this.document.removeAttributeAtRange(e2, i2));
            return r;
          }, t3.prototype.applyBlockAttribute = function() {
            var t4, n2, i2, o, r, s;
            for (i2 = 0, r = this.findRangesOfPieces(), s = [], t4 = 0, n2 = r.length; n2 > t4; t4++)
              o = r[t4], o[1] - o[0] > 1 && (o[0] += i2, o[1] += i2, this.document.getCharacterAtPosition(o[1]) !== "\n" && (this.document = this.document.insertBlockBreakAtRange(o[1]), o[1] < this.selectedRange[1] && this.moveSelectedRangeForward(), o[1]++, i2++), o[0] !== 0 && this.document.getCharacterAtPosition(o[0] - 1) !== "\n" && (this.document = this.document.insertBlockBreakAtRange(o[0]), o[0] < this.selectedRange[0] && this.moveSelectedRangeForward(), o[0]++, i2++), s.push(this.document = this.document.applyBlockAttributeAtRange(e2, true, o)));
            return s;
          }, t3.prototype.findRangesOfBlocks = function() {
            return this.document.findRangesForBlockAttribute(e2);
          }, t3.prototype.findRangesOfPieces = function() {
            return this.document.findRangesForTextAttribute(n, {withValue: i});
          }, t3.prototype.moveSelectedRangeForward = function() {
            return this.selectedRange[0] += 1, this.selectedRange[1] += 1;
          }, t3;
        }();
      }.call(this), function() {
        var t2 = function(t3, e2) {
          return function() {
            return t3.apply(e2, arguments);
          };
        };
        e.Editor = function() {
          function n(n2, o, r) {
            this.composition = n2, this.selectionManager = o, this.element = r, this.insertFiles = t2(this.insertFiles, this), this.undoManager = new e.UndoManager(this.composition), this.filters = i.slice(0);
          }
          var i;
          return i = [e.attachmentGalleryFilter], n.prototype.loadDocument = function(t3) {
            return this.loadSnapshot({document: t3, selectedRange: [0, 0]});
          }, n.prototype.loadHTML = function(t3) {
            return t3 == null && (t3 = ""), this.loadDocument(e.Document.fromHTML(t3, {referenceElement: this.element}));
          }, n.prototype.loadJSON = function(t3) {
            var n2, i2;
            return n2 = t3.document, i2 = t3.selectedRange, n2 = e.Document.fromJSON(n2), this.loadSnapshot({document: n2, selectedRange: i2});
          }, n.prototype.loadSnapshot = function(t3) {
            return this.undoManager = new e.UndoManager(this.composition), this.composition.loadSnapshot(t3);
          }, n.prototype.getDocument = function() {
            return this.composition.document;
          }, n.prototype.getSelectedDocument = function() {
            return this.composition.getSelectedDocument();
          }, n.prototype.getSnapshot = function() {
            return this.composition.getSnapshot();
          }, n.prototype.toJSON = function() {
            return this.getSnapshot();
          }, n.prototype.deleteInDirection = function(t3) {
            return this.composition.deleteInDirection(t3);
          }, n.prototype.insertAttachment = function(t3) {
            return this.composition.insertAttachment(t3);
          }, n.prototype.insertAttachments = function(t3) {
            return this.composition.insertAttachments(t3);
          }, n.prototype.insertDocument = function(t3) {
            return this.composition.insertDocument(t3);
          }, n.prototype.insertFile = function(t3) {
            return this.composition.insertFile(t3);
          }, n.prototype.insertFiles = function(t3) {
            return this.composition.insertFiles(t3);
          }, n.prototype.insertHTML = function(t3) {
            return this.composition.insertHTML(t3);
          }, n.prototype.insertString = function(t3) {
            return this.composition.insertString(t3);
          }, n.prototype.insertText = function(t3) {
            return this.composition.insertText(t3);
          }, n.prototype.insertLineBreak = function() {
            return this.composition.insertLineBreak();
          }, n.prototype.getSelectedRange = function() {
            return this.composition.getSelectedRange();
          }, n.prototype.getPosition = function() {
            return this.composition.getPosition();
          }, n.prototype.getClientRectAtPosition = function(t3) {
            var e2;
            return e2 = this.getDocument().locationRangeFromRange([t3, t3 + 1]), this.selectionManager.getClientRectAtLocationRange(e2);
          }, n.prototype.expandSelectionInDirection = function(t3) {
            return this.composition.expandSelectionInDirection(t3);
          }, n.prototype.moveCursorInDirection = function(t3) {
            return this.composition.moveCursorInDirection(t3);
          }, n.prototype.setSelectedRange = function(t3) {
            return this.composition.setSelectedRange(t3);
          }, n.prototype.activateAttribute = function(t3, e2) {
            return e2 == null && (e2 = true), this.composition.setCurrentAttribute(t3, e2);
          }, n.prototype.attributeIsActive = function(t3) {
            return this.composition.hasCurrentAttribute(t3);
          }, n.prototype.canActivateAttribute = function(t3) {
            return this.composition.canSetCurrentAttribute(t3);
          }, n.prototype.deactivateAttribute = function(t3) {
            return this.composition.removeCurrentAttribute(t3);
          }, n.prototype.canDecreaseNestingLevel = function() {
            return this.composition.canDecreaseNestingLevel();
          }, n.prototype.canIncreaseNestingLevel = function() {
            return this.composition.canIncreaseNestingLevel();
          }, n.prototype.decreaseNestingLevel = function() {
            return this.canDecreaseNestingLevel() ? this.composition.decreaseNestingLevel() : void 0;
          }, n.prototype.increaseNestingLevel = function() {
            return this.canIncreaseNestingLevel() ? this.composition.increaseNestingLevel() : void 0;
          }, n.prototype.canRedo = function() {
            return this.undoManager.canRedo();
          }, n.prototype.canUndo = function() {
            return this.undoManager.canUndo();
          }, n.prototype.recordUndoEntry = function(t3, e2) {
            var n2, i2, o;
            return o = e2 != null ? e2 : {}, i2 = o.context, n2 = o.consolidatable, this.undoManager.recordUndoEntry(t3, {context: i2, consolidatable: n2});
          }, n.prototype.redo = function() {
            return this.canRedo() ? this.undoManager.redo() : void 0;
          }, n.prototype.undo = function() {
            return this.canUndo() ? this.undoManager.undo() : void 0;
          }, n;
        }();
      }.call(this), function() {
        var t2 = function(t3, e2) {
          function i() {
            this.constructor = t3;
          }
          for (var o in e2)
            n.call(e2, o) && (t3[o] = e2[o]);
          return i.prototype = e2.prototype, t3.prototype = new i(), t3.__super__ = e2.prototype, t3;
        }, n = {}.hasOwnProperty;
        e.ManagedAttachment = function(e2) {
          function n2(t3, e3) {
            var n3;
            this.attachmentManager = t3, this.attachment = e3, n3 = this.attachment, this.id = n3.id, this.file = n3.file;
          }
          return t2(n2, e2), n2.prototype.remove = function() {
            return this.attachmentManager.requestRemovalOfAttachment(this.attachment);
          }, n2.proxyMethod("attachment.getAttribute"), n2.proxyMethod("attachment.hasAttribute"), n2.proxyMethod("attachment.setAttribute"), n2.proxyMethod("attachment.getAttributes"), n2.proxyMethod("attachment.setAttributes"), n2.proxyMethod("attachment.isPending"), n2.proxyMethod("attachment.isPreviewable"), n2.proxyMethod("attachment.getURL"), n2.proxyMethod("attachment.getHref"), n2.proxyMethod("attachment.getFilename"), n2.proxyMethod("attachment.getFilesize"), n2.proxyMethod("attachment.getFormattedFilesize"), n2.proxyMethod("attachment.getExtension"), n2.proxyMethod("attachment.getContentType"), n2.proxyMethod("attachment.getFile"), n2.proxyMethod("attachment.setFile"), n2.proxyMethod("attachment.releaseFile"), n2.proxyMethod("attachment.getUploadProgress"), n2.proxyMethod("attachment.setUploadProgress"), n2;
        }(e.BasicObject);
      }.call(this), function() {
        var t2 = function(t3, e2) {
          function i() {
            this.constructor = t3;
          }
          for (var o in e2)
            n.call(e2, o) && (t3[o] = e2[o]);
          return i.prototype = e2.prototype, t3.prototype = new i(), t3.__super__ = e2.prototype, t3;
        }, n = {}.hasOwnProperty;
        e.AttachmentManager = function(n2) {
          function i(t3) {
            var e2, n3, i2;
            for (t3 == null && (t3 = []), this.managedAttachments = {}, n3 = 0, i2 = t3.length; i2 > n3; n3++)
              e2 = t3[n3], this.manageAttachment(e2);
          }
          return t2(i, n2), i.prototype.getAttachments = function() {
            var t3, e2, n3, i2;
            n3 = this.managedAttachments, i2 = [];
            for (e2 in n3)
              t3 = n3[e2], i2.push(t3);
            return i2;
          }, i.prototype.manageAttachment = function(t3) {
            var n3, i2;
            return (n3 = this.managedAttachments)[i2 = t3.id] != null ? n3[i2] : n3[i2] = new e.ManagedAttachment(this, t3);
          }, i.prototype.attachmentIsManaged = function(t3) {
            return t3.id in this.managedAttachments;
          }, i.prototype.requestRemovalOfAttachment = function(t3) {
            var e2;
            return this.attachmentIsManaged(t3) && (e2 = this.delegate) != null && typeof e2.attachmentManagerDidRequestRemovalOfAttachment == "function" ? e2.attachmentManagerDidRequestRemovalOfAttachment(t3) : void 0;
          }, i.prototype.unmanageAttachment = function(t3) {
            var e2;
            return e2 = this.managedAttachments[t3.id], delete this.managedAttachments[t3.id], e2;
          }, i;
        }(e.BasicObject);
      }.call(this), function() {
        var t2, n, i, o, r, s, a, u, c, l, h;
        t2 = e.elementContainsNode, n = e.findChildIndexOfNode, r = e.nodeIsBlockStart, s = e.nodeIsBlockStartComment, o = e.nodeIsBlockContainer, a = e.nodeIsCursorTarget, u = e.nodeIsEmptyTextNode, c = e.nodeIsTextNode, i = e.nodeIsAttachmentElement, l = e.tagName, h = e.walkTree, e.LocationMapper = function() {
          function e2(t3) {
            this.element = t3;
          }
          var p, d, f, g;
          return e2.prototype.findLocationFromContainerAndOffset = function(e3, i2, o2) {
            var s2, u2, l2, p2, g2, m, v;
            for (m = (o2 != null ? o2 : {strict: true}).strict, u2 = 0, l2 = false, p2 = {index: 0, offset: 0}, (s2 = this.findAttachmentElementParentForNode(e3)) && (e3 = s2.parentNode, i2 = n(s2)), v = h(this.element, {usingFilter: f}); v.nextNode(); ) {
              if (g2 = v.currentNode, g2 === e3 && c(e3)) {
                a(g2) || (p2.offset += i2);
                break;
              }
              if (g2.parentNode === e3) {
                if (u2++ === i2)
                  break;
              } else if (!t2(e3, g2) && u2 > 0)
                break;
              r(g2, {strict: m}) ? (l2 && p2.index++, p2.offset = 0, l2 = true) : p2.offset += d(g2);
            }
            return p2;
          }, e2.prototype.findContainerAndOffsetFromLocation = function(t3) {
            var e3, i2, s2, u2, l2;
            if (t3.index === 0 && t3.offset === 0) {
              for (e3 = this.element, u2 = 0; e3.firstChild; )
                if (e3 = e3.firstChild, o(e3)) {
                  u2 = 1;
                  break;
                }
              return [e3, u2];
            }
            if (l2 = this.findNodeAndOffsetFromLocation(t3), i2 = l2[0], s2 = l2[1], i2) {
              if (c(i2))
                d(i2) === 0 ? (e3 = i2.parentNode.parentNode, u2 = n(i2.parentNode), a(i2, {name: "right"}) && u2++) : (e3 = i2, u2 = t3.offset - s2);
              else {
                if (e3 = i2.parentNode, !r(i2.previousSibling) && !o(e3))
                  for (; i2 === e3.lastChild && (i2 = e3, e3 = e3.parentNode, !o(e3)); )
                    ;
                u2 = n(i2), t3.offset !== 0 && u2++;
              }
              return [e3, u2];
            }
          }, e2.prototype.findNodeAndOffsetFromLocation = function(t3) {
            var e3, n2, i2, o2, r2, s2, u2, l2;
            for (u2 = 0, l2 = this.getSignificantNodesForIndex(t3.index), n2 = 0, i2 = l2.length; i2 > n2; n2++) {
              if (e3 = l2[n2], o2 = d(e3), t3.offset <= u2 + o2)
                if (c(e3)) {
                  if (r2 = e3, s2 = u2, t3.offset === s2 && a(r2))
                    break;
                } else
                  r2 || (r2 = e3, s2 = u2);
              if (u2 += o2, u2 > t3.offset)
                break;
            }
            return [r2, s2];
          }, e2.prototype.findAttachmentElementParentForNode = function(t3) {
            for (; t3 && t3 !== this.element; ) {
              if (i(t3))
                return t3;
              t3 = t3.parentNode;
            }
          }, e2.prototype.getSignificantNodesForIndex = function(t3) {
            var e3, n2, i2, o2, r2;
            for (i2 = [], r2 = h(this.element, {usingFilter: p}), o2 = false; r2.nextNode(); )
              if (n2 = r2.currentNode, s(n2)) {
                if (typeof e3 != "undefined" && e3 !== null ? e3++ : e3 = 0, e3 === t3)
                  o2 = true;
                else if (o2)
                  break;
              } else
                o2 && i2.push(n2);
            return i2;
          }, d = function(t3) {
            var e3;
            return t3.nodeType === Node.TEXT_NODE ? a(t3) ? 0 : (e3 = t3.textContent, e3.length) : l(t3) === "br" || i(t3) ? 1 : 0;
          }, p = function(t3) {
            return g(t3) === NodeFilter.FILTER_ACCEPT ? f(t3) : NodeFilter.FILTER_REJECT;
          }, g = function(t3) {
            return u(t3) ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
          }, f = function(t3) {
            return i(t3.parentNode) ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
          }, e2;
        }();
      }.call(this), function() {
        var t2, n, i = [].slice;
        t2 = e.getDOMRange, n = e.setDOMRange, e.PointMapper = function() {
          function e2() {
          }
          return e2.prototype.createDOMRangeFromPoint = function(e3) {
            var i2, o, r, s, a, u, c, l;
            if (c = e3.x, l = e3.y, document.caretPositionFromPoint)
              return a = document.caretPositionFromPoint(c, l), r = a.offsetNode, o = a.offset, i2 = document.createRange(), i2.setStart(r, o), i2;
            if (document.caretRangeFromPoint)
              return document.caretRangeFromPoint(c, l);
            if (document.body.createTextRange) {
              s = t2();
              try {
                u = document.body.createTextRange(), u.moveToPoint(c, l), u.select();
              } catch (h) {
              }
              return i2 = t2(), n(s), i2;
            }
          }, e2.prototype.getClientRectsForDOMRange = function(t3) {
            var e3, n2, o;
            return n2 = i.call(t3.getClientRects()), o = n2[0], e3 = n2[n2.length - 1], [o, e3];
          }, e2;
        }();
      }.call(this), function() {
        var t2, n = function(t3, e2) {
          return function() {
            return t3.apply(e2, arguments);
          };
        }, i = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var i2 in e2)
            o.call(e2, i2) && (t3[i2] = e2[i2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, o = {}.hasOwnProperty, r = [].indexOf || function(t3) {
          for (var e2 = 0, n2 = this.length; n2 > e2; e2++)
            if (e2 in this && this[e2] === t3)
              return e2;
          return -1;
        };
        t2 = e.getDOMRange, e.SelectionChangeObserver = function(e2) {
          function o2() {
            this.run = n(this.run, this), this.update = n(this.update, this), this.selectionManagers = [];
          }
          var s;
          return i(o2, e2), o2.prototype.start = function() {
            return this.started ? void 0 : (this.started = true, "onselectionchange" in document ? document.addEventListener("selectionchange", this.update, true) : this.run());
          }, o2.prototype.stop = function() {
            return this.started ? (this.started = false, document.removeEventListener("selectionchange", this.update, true)) : void 0;
          }, o2.prototype.registerSelectionManager = function(t3) {
            return r.call(this.selectionManagers, t3) < 0 ? (this.selectionManagers.push(t3), this.start()) : void 0;
          }, o2.prototype.unregisterSelectionManager = function(t3) {
            var e3;
            return this.selectionManagers = function() {
              var n2, i2, o3, r2;
              for (o3 = this.selectionManagers, r2 = [], n2 = 0, i2 = o3.length; i2 > n2; n2++)
                e3 = o3[n2], e3 !== t3 && r2.push(e3);
              return r2;
            }.call(this), this.selectionManagers.length === 0 ? this.stop() : void 0;
          }, o2.prototype.notifySelectionManagersOfSelectionChange = function() {
            var t3, e3, n2, i2, o3;
            for (n2 = this.selectionManagers, i2 = [], t3 = 0, e3 = n2.length; e3 > t3; t3++)
              o3 = n2[t3], i2.push(o3.selectionDidChange());
            return i2;
          }, o2.prototype.update = function() {
            var e3;
            return e3 = t2(), s(e3, this.domRange) ? void 0 : (this.domRange = e3, this.notifySelectionManagersOfSelectionChange());
          }, o2.prototype.reset = function() {
            return this.domRange = null, this.update();
          }, o2.prototype.run = function() {
            return this.started ? (this.update(), requestAnimationFrame(this.run)) : void 0;
          }, s = function(t3, e3) {
            return (t3 != null ? t3.startContainer : void 0) === (e3 != null ? e3.startContainer : void 0) && (t3 != null ? t3.startOffset : void 0) === (e3 != null ? e3.startOffset : void 0) && (t3 != null ? t3.endContainer : void 0) === (e3 != null ? e3.endContainer : void 0) && (t3 != null ? t3.endOffset : void 0) === (e3 != null ? e3.endOffset : void 0);
          }, o2;
        }(e.BasicObject), e.selectionChangeObserver == null && (e.selectionChangeObserver = new e.SelectionChangeObserver());
      }.call(this), function() {
        var t2, n, i, o, r, s, a, u, c, l, h = function(t3, e2) {
          return function() {
            return t3.apply(e2, arguments);
          };
        }, p = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var i2 in e2)
            d.call(e2, i2) && (t3[i2] = e2[i2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, d = {}.hasOwnProperty;
        i = e.getDOMSelection, n = e.getDOMRange, l = e.setDOMRange, t2 = e.elementContainsNode, s = e.nodeIsCursorTarget, r = e.innerElementIsActive, o = e.handleEvent, a = e.normalizeRange, u = e.rangeIsCollapsed, c = e.rangesAreEqual, e.SelectionManager = function(d2) {
          function f(t3) {
            this.element = t3, this.selectionDidChange = h(this.selectionDidChange, this), this.didMouseDown = h(this.didMouseDown, this), this.locationMapper = new e.LocationMapper(this.element), this.pointMapper = new e.PointMapper(), this.lockCount = 0, o("mousedown", {onElement: this.element, withCallback: this.didMouseDown});
          }
          return p(f, d2), f.prototype.getLocationRange = function(t3) {
            var e2, i2;
            return t3 == null && (t3 = {}), e2 = t3.strict === false ? this.createLocationRangeFromDOMRange(n(), {strict: false}) : t3.ignoreLock ? this.currentLocationRange : (i2 = this.lockedLocationRange) != null ? i2 : this.currentLocationRange;
          }, f.prototype.setLocationRange = function(t3) {
            var e2;
            if (!this.lockedLocationRange)
              return t3 = a(t3), (e2 = this.createDOMRangeFromLocationRange(t3)) ? (l(e2), this.updateCurrentLocationRange(t3)) : void 0;
          }, f.prototype.setLocationRangeFromPointRange = function(t3) {
            var e2, n2;
            return t3 = a(t3), n2 = this.getLocationAtPoint(t3[0]), e2 = this.getLocationAtPoint(t3[1]), this.setLocationRange([n2, e2]);
          }, f.prototype.getClientRectAtLocationRange = function(t3) {
            var e2;
            return (e2 = this.createDOMRangeFromLocationRange(t3)) ? this.getClientRectsForDOMRange(e2)[1] : void 0;
          }, f.prototype.locationIsCursorTarget = function(t3) {
            var e2, n2, i2;
            return i2 = this.findNodeAndOffsetFromLocation(t3), e2 = i2[0], n2 = i2[1], s(e2);
          }, f.prototype.lock = function() {
            return this.lockCount++ === 0 ? (this.updateCurrentLocationRange(), this.lockedLocationRange = this.getLocationRange()) : void 0;
          }, f.prototype.unlock = function() {
            var t3;
            return --this.lockCount === 0 && (t3 = this.lockedLocationRange, this.lockedLocationRange = null, t3 != null) ? this.setLocationRange(t3) : void 0;
          }, f.prototype.clearSelection = function() {
            var t3;
            return (t3 = i()) != null ? t3.removeAllRanges() : void 0;
          }, f.prototype.selectionIsCollapsed = function() {
            var t3;
            return ((t3 = n()) != null ? t3.collapsed : void 0) === true;
          }, f.prototype.selectionIsExpanded = function() {
            return !this.selectionIsCollapsed();
          }, f.prototype.createLocationRangeFromDOMRange = function(t3, e2) {
            var n2, i2;
            if (t3 != null && this.domRangeWithinElement(t3) && (i2 = this.findLocationFromContainerAndOffset(t3.startContainer, t3.startOffset, e2)))
              return t3.collapsed || (n2 = this.findLocationFromContainerAndOffset(t3.endContainer, t3.endOffset, e2)), a([i2, n2]);
          }, f.proxyMethod("locationMapper.findLocationFromContainerAndOffset"), f.proxyMethod("locationMapper.findContainerAndOffsetFromLocation"), f.proxyMethod("locationMapper.findNodeAndOffsetFromLocation"), f.proxyMethod("pointMapper.createDOMRangeFromPoint"), f.proxyMethod("pointMapper.getClientRectsForDOMRange"), f.prototype.didMouseDown = function() {
            return this.pauseTemporarily();
          }, f.prototype.pauseTemporarily = function() {
            var e2, n2, i2, r2;
            return this.paused = true, n2 = function(e3) {
              return function() {
                var n3, o2, s2;
                for (e3.paused = false, clearTimeout(r2), o2 = 0, s2 = i2.length; s2 > o2; o2++)
                  n3 = i2[o2], n3.destroy();
                return t2(document, e3.element) ? e3.selectionDidChange() : void 0;
              };
            }(this), r2 = setTimeout(n2, 200), i2 = function() {
              var t3, i3, r3, s2;
              for (r3 = ["mousemove", "keydown"], s2 = [], t3 = 0, i3 = r3.length; i3 > t3; t3++)
                e2 = r3[t3], s2.push(o(e2, {onElement: document, withCallback: n2}));
              return s2;
            }();
          }, f.prototype.selectionDidChange = function() {
            return this.paused || r(this.element) ? void 0 : this.updateCurrentLocationRange();
          }, f.prototype.updateCurrentLocationRange = function(t3) {
            var e2;
            return (t3 != null ? t3 : t3 = this.createLocationRangeFromDOMRange(n())) && !c(t3, this.currentLocationRange) ? (this.currentLocationRange = t3, (e2 = this.delegate) != null && typeof e2.locationRangeDidChange == "function" ? e2.locationRangeDidChange(this.currentLocationRange.slice(0)) : void 0) : void 0;
          }, f.prototype.createDOMRangeFromLocationRange = function(t3) {
            var e2, n2, i2, o2;
            return i2 = this.findContainerAndOffsetFromLocation(t3[0]), n2 = u(t3) ? i2 : (o2 = this.findContainerAndOffsetFromLocation(t3[1])) != null ? o2 : i2, i2 != null && n2 != null ? (e2 = document.createRange(), e2.setStart.apply(e2, i2), e2.setEnd.apply(e2, n2), e2) : void 0;
          }, f.prototype.getLocationAtPoint = function(t3) {
            var e2, n2;
            return (e2 = this.createDOMRangeFromPoint(t3)) && (n2 = this.createLocationRangeFromDOMRange(e2)) != null ? n2[0] : void 0;
          }, f.prototype.domRangeWithinElement = function(e2) {
            return e2.collapsed ? t2(this.element, e2.startContainer) : t2(this.element, e2.startContainer) && t2(this.element, e2.endContainer);
          }, f;
        }(e.BasicObject);
      }.call(this), function() {
        var t2, n, i, o, r = function(t3, e2) {
          function n2() {
            this.constructor = t3;
          }
          for (var i2 in e2)
            s.call(e2, i2) && (t3[i2] = e2[i2]);
          return n2.prototype = e2.prototype, t3.prototype = new n2(), t3.__super__ = e2.prototype, t3;
        }, s = {}.hasOwnProperty, a = [].slice;
        i = e.rangeIsCollapsed, o = e.rangesAreEqual, n = e.objectsAreEqual, t2 = e.getBlockConfig, e.EditorController = function(s2) {
          function u(t3) {
            var n2, i2;
            this.editorElement = t3.editorElement, n2 = t3.document, i2 = t3.html, this.selectionManager = new e.SelectionManager(this.editorElement), this.selectionManager.delegate = this, this.composition = new e.Composition(), this.composition.delegate = this, this.attachmentManager = new e.AttachmentManager(this.composition.getAttachments()), this.attachmentManager.delegate = this, this.inputController = new e["Level" + e.config.input.getLevel() + "InputController"](this.editorElement), this.inputController.delegate = this, this.inputController.responder = this.composition, this.compositionController = new e.CompositionController(this.editorElement, this.composition), this.compositionController.delegate = this, this.toolbarController = new e.ToolbarController(this.editorElement.toolbarElement), this.toolbarController.delegate = this, this.editor = new e.Editor(this.composition, this.selectionManager, this.editorElement), n2 != null ? this.editor.loadDocument(n2) : this.editor.loadHTML(i2);
          }
          var c;
          return r(u, s2), u.prototype.registerSelectionManager = function() {
            return e.selectionChangeObserver.registerSelectionManager(this.selectionManager);
          }, u.prototype.unregisterSelectionManager = function() {
            return e.selectionChangeObserver.unregisterSelectionManager(this.selectionManager);
          }, u.prototype.render = function() {
            return this.compositionController.render();
          }, u.prototype.reparse = function() {
            return this.composition.replaceHTML(this.editorElement.innerHTML);
          }, u.prototype.compositionDidChangeDocument = function() {
            return this.notifyEditorElement("document-change"), this.handlingInput ? void 0 : this.render();
          }, u.prototype.compositionDidChangeCurrentAttributes = function(t3) {
            return this.currentAttributes = t3, this.toolbarController.updateAttributes(this.currentAttributes), this.updateCurrentActions(), this.notifyEditorElement("attributes-change", {attributes: this.currentAttributes});
          }, u.prototype.compositionDidPerformInsertionAtRange = function(t3) {
            return this.pasting ? this.pastedRange = t3 : void 0;
          }, u.prototype.compositionShouldAcceptFile = function(t3) {
            return this.notifyEditorElement("file-accept", {file: t3});
          }, u.prototype.compositionDidAddAttachment = function(t3) {
            var e2;
            return e2 = this.attachmentManager.manageAttachment(t3), this.notifyEditorElement("attachment-add", {attachment: e2});
          }, u.prototype.compositionDidEditAttachment = function(t3) {
            var e2;
            return this.compositionController.rerenderViewForObject(t3), e2 = this.attachmentManager.manageAttachment(t3), this.notifyEditorElement("attachment-edit", {attachment: e2}), this.notifyEditorElement("change");
          }, u.prototype.compositionDidChangeAttachmentPreviewURL = function(t3) {
            return this.compositionController.invalidateViewForObject(t3), this.notifyEditorElement("change");
          }, u.prototype.compositionDidRemoveAttachment = function(t3) {
            var e2;
            return e2 = this.attachmentManager.unmanageAttachment(t3), this.notifyEditorElement("attachment-remove", {attachment: e2});
          }, u.prototype.compositionDidStartEditingAttachment = function(t3, e2) {
            return this.attachmentLocationRange = this.composition.document.getLocationRangeOfAttachment(t3), this.compositionController.installAttachmentEditorForAttachment(t3, e2), this.selectionManager.setLocationRange(this.attachmentLocationRange);
          }, u.prototype.compositionDidStopEditingAttachment = function() {
            return this.compositionController.uninstallAttachmentEditor(), this.attachmentLocationRange = null;
          }, u.prototype.compositionDidRequestChangingSelectionToLocationRange = function(t3) {
            return !this.loadingSnapshot || this.isFocused() ? (this.requestedLocationRange = t3, this.compositionRevisionWhenLocationRangeRequested = this.composition.revision, this.handlingInput ? void 0 : this.render()) : void 0;
          }, u.prototype.compositionWillLoadSnapshot = function() {
            return this.loadingSnapshot = true;
          }, u.prototype.compositionDidLoadSnapshot = function() {
            return this.compositionController.refreshViewCache(), this.render(), this.loadingSnapshot = false;
          }, u.prototype.getSelectionManager = function() {
            return this.selectionManager;
          }, u.proxyMethod("getSelectionManager().setLocationRange"), u.proxyMethod("getSelectionManager().getLocationRange"), u.prototype.attachmentManagerDidRequestRemovalOfAttachment = function(t3) {
            return this.removeAttachment(t3);
          }, u.prototype.compositionControllerWillSyncDocumentView = function() {
            return this.inputController.editorWillSyncDocumentView(), this.selectionManager.lock(), this.selectionManager.clearSelection();
          }, u.prototype.compositionControllerDidSyncDocumentView = function() {
            return this.inputController.editorDidSyncDocumentView(), this.selectionManager.unlock(), this.updateCurrentActions(), this.notifyEditorElement("sync");
          }, u.prototype.compositionControllerDidRender = function() {
            return this.requestedLocationRange != null && (this.compositionRevisionWhenLocationRangeRequested === this.composition.revision && this.selectionManager.setLocationRange(this.requestedLocationRange), this.requestedLocationRange = null, this.compositionRevisionWhenLocationRangeRequested = null), this.renderedCompositionRevision !== this.composition.revision && (this.runEditorFilters(), this.composition.updateCurrentAttributes(), this.notifyEditorElement("render")), this.renderedCompositionRevision = this.composition.revision;
          }, u.prototype.compositionControllerDidFocus = function() {
            return this.isFocusedInvisibly() && this.setLocationRange({index: 0, offset: 0}), this.toolbarController.hideDialog(), this.notifyEditorElement("focus");
          }, u.prototype.compositionControllerDidBlur = function() {
            return this.notifyEditorElement("blur");
          }, u.prototype.compositionControllerDidSelectAttachment = function(t3, e2) {
            return this.toolbarController.hideDialog(), this.composition.editAttachment(t3, e2);
          }, u.prototype.compositionControllerDidRequestDeselectingAttachment = function(t3) {
            var e2, n2;
            return e2 = (n2 = this.attachmentLocationRange) != null ? n2 : this.composition.document.getLocationRangeOfAttachment(t3), this.selectionManager.setLocationRange(e2[1]);
          }, u.prototype.compositionControllerWillUpdateAttachment = function(t3) {
            return this.editor.recordUndoEntry("Edit Attachment", {context: t3.id, consolidatable: true});
          }, u.prototype.compositionControllerDidRequestRemovalOfAttachment = function(t3) {
            return this.removeAttachment(t3);
          }, u.prototype.inputControllerWillHandleInput = function() {
            return this.handlingInput = true, this.requestedRender = false;
          }, u.prototype.inputControllerDidRequestRender = function() {
            return this.requestedRender = true;
          }, u.prototype.inputControllerDidHandleInput = function() {
            return this.handlingInput = false, this.requestedRender ? (this.requestedRender = false, this.render()) : void 0;
          }, u.prototype.inputControllerDidAllowUnhandledInput = function() {
            return this.notifyEditorElement("change");
          }, u.prototype.inputControllerDidRequestReparse = function() {
            return this.reparse();
          }, u.prototype.inputControllerWillPerformTyping = function() {
            return this.recordTypingUndoEntry();
          }, u.prototype.inputControllerWillPerformFormatting = function(t3) {
            return this.recordFormattingUndoEntry(t3);
          }, u.prototype.inputControllerWillCutText = function() {
            return this.editor.recordUndoEntry("Cut");
          }, u.prototype.inputControllerWillPaste = function(t3) {
            return this.editor.recordUndoEntry("Paste"), this.pasting = true, this.notifyEditorElement("before-paste", {paste: t3});
          }, u.prototype.inputControllerDidPaste = function(t3) {
            return t3.range = this.pastedRange, this.pastedRange = null, this.pasting = null, this.notifyEditorElement("paste", {paste: t3});
          }, u.prototype.inputControllerWillMoveText = function() {
            return this.editor.recordUndoEntry("Move");
          }, u.prototype.inputControllerWillAttachFiles = function() {
            return this.editor.recordUndoEntry("Drop Files");
          }, u.prototype.inputControllerWillPerformUndo = function() {
            return this.editor.undo();
          }, u.prototype.inputControllerWillPerformRedo = function() {
            return this.editor.redo();
          }, u.prototype.inputControllerDidReceiveKeyboardCommand = function(t3) {
            return this.toolbarController.applyKeyboardCommand(t3);
          }, u.prototype.inputControllerDidStartDrag = function() {
            return this.locationRangeBeforeDrag = this.selectionManager.getLocationRange();
          }, u.prototype.inputControllerDidReceiveDragOverPoint = function(t3) {
            return this.selectionManager.setLocationRangeFromPointRange(t3);
          }, u.prototype.inputControllerDidCancelDrag = function() {
            return this.selectionManager.setLocationRange(this.locationRangeBeforeDrag), this.locationRangeBeforeDrag = null;
          }, u.prototype.locationRangeDidChange = function(t3) {
            return this.composition.updateCurrentAttributes(), this.updateCurrentActions(), this.attachmentLocationRange && !o(this.attachmentLocationRange, t3) && this.composition.stopEditingAttachment(), this.notifyEditorElement("selection-change");
          }, u.prototype.toolbarDidClickButton = function() {
            return this.getLocationRange() ? void 0 : this.setLocationRange({index: 0, offset: 0});
          }, u.prototype.toolbarDidInvokeAction = function(t3) {
            return this.invokeAction(t3);
          }, u.prototype.toolbarDidToggleAttribute = function(t3) {
            return this.recordFormattingUndoEntry(t3), this.composition.toggleCurrentAttribute(t3), this.render(), this.selectionFrozen ? void 0 : this.editorElement.focus();
          }, u.prototype.toolbarDidUpdateAttribute = function(t3, e2) {
            return this.recordFormattingUndoEntry(t3), this.composition.setCurrentAttribute(t3, e2), this.render(), this.selectionFrozen ? void 0 : this.editorElement.focus();
          }, u.prototype.toolbarDidRemoveAttribute = function(t3) {
            return this.recordFormattingUndoEntry(t3), this.composition.removeCurrentAttribute(t3), this.render(), this.selectionFrozen ? void 0 : this.editorElement.focus();
          }, u.prototype.toolbarWillShowDialog = function() {
            return this.composition.expandSelectionForEditing(), this.freezeSelection();
          }, u.prototype.toolbarDidShowDialog = function(t3) {
            return this.notifyEditorElement("toolbar-dialog-show", {dialogName: t3});
          }, u.prototype.toolbarDidHideDialog = function(t3) {
            return this.thawSelection(), this.editorElement.focus(), this.notifyEditorElement("toolbar-dialog-hide", {dialogName: t3});
          }, u.prototype.freezeSelection = function() {
            return this.selectionFrozen ? void 0 : (this.selectionManager.lock(), this.composition.freezeSelection(), this.selectionFrozen = true, this.render());
          }, u.prototype.thawSelection = function() {
            return this.selectionFrozen ? (this.composition.thawSelection(), this.selectionManager.unlock(), this.selectionFrozen = false, this.render()) : void 0;
          }, u.prototype.actions = {undo: {test: function() {
            return this.editor.canUndo();
          }, perform: function() {
            return this.editor.undo();
          }}, redo: {test: function() {
            return this.editor.canRedo();
          }, perform: function() {
            return this.editor.redo();
          }}, link: {test: function() {
            return this.editor.canActivateAttribute("href");
          }}, increaseNestingLevel: {test: function() {
            return this.editor.canIncreaseNestingLevel();
          }, perform: function() {
            return this.editor.increaseNestingLevel() && this.render();
          }}, decreaseNestingLevel: {test: function() {
            return this.editor.canDecreaseNestingLevel();
          }, perform: function() {
            return this.editor.decreaseNestingLevel() && this.render();
          }}, attachFiles: {test: function() {
            return true;
          }, perform: function() {
            return e.config.input.pickFiles(this.editor.insertFiles);
          }}}, u.prototype.canInvokeAction = function(t3) {
            var e2, n2;
            return this.actionIsExternal(t3) ? true : !!((e2 = this.actions[t3]) != null && (n2 = e2.test) != null ? n2.call(this) : void 0);
          }, u.prototype.invokeAction = function(t3) {
            var e2, n2;
            return this.actionIsExternal(t3) ? this.notifyEditorElement("action-invoke", {actionName: t3}) : (e2 = this.actions[t3]) != null && (n2 = e2.perform) != null ? n2.call(this) : void 0;
          }, u.prototype.actionIsExternal = function(t3) {
            return /^x-./.test(t3);
          }, u.prototype.getCurrentActions = function() {
            var t3, e2;
            e2 = {};
            for (t3 in this.actions)
              e2[t3] = this.canInvokeAction(t3);
            return e2;
          }, u.prototype.updateCurrentActions = function() {
            var t3;
            return t3 = this.getCurrentActions(), n(t3, this.currentActions) ? void 0 : (this.currentActions = t3, this.toolbarController.updateActions(this.currentActions), this.notifyEditorElement("actions-change", {actions: this.currentActions}));
          }, u.prototype.runEditorFilters = function() {
            var t3, e2, n2, i2, o2, r2, s3, a2;
            for (a2 = this.composition.getSnapshot(), o2 = this.editor.filters, n2 = 0, i2 = o2.length; i2 > n2; n2++)
              e2 = o2[n2], t3 = a2.document, s3 = a2.selectedRange, a2 = (r2 = e2.call(this.editor, a2)) != null ? r2 : {}, a2.document == null && (a2.document = t3), a2.selectedRange == null && (a2.selectedRange = s3);
            return c(a2, this.composition.getSnapshot()) ? void 0 : this.composition.loadSnapshot(a2);
          }, c = function(t3, e2) {
            return o(t3.selectedRange, e2.selectedRange) && t3.document.isEqualTo(e2.document);
          }, u.prototype.updateInputElement = function() {
            var t3, n2;
            return t3 = this.compositionController.getSerializableElement(), n2 = e.serializeToContentType(t3, "text/html"), this.editorElement.setInputElementValue(n2);
          }, u.prototype.notifyEditorElement = function(t3, e2) {
            switch (t3) {
              case "document-change":
                this.documentChangedSinceLastRender = true;
                break;
              case "render":
                this.documentChangedSinceLastRender && (this.documentChangedSinceLastRender = false, this.notifyEditorElement("change"));
                break;
              case "change":
              case "attachment-add":
              case "attachment-edit":
              case "attachment-remove":
                this.updateInputElement();
            }
            return this.editorElement.notify(t3, e2);
          }, u.prototype.removeAttachment = function(t3) {
            return this.editor.recordUndoEntry("Delete Attachment"), this.composition.removeAttachment(t3), this.render();
          }, u.prototype.recordFormattingUndoEntry = function(e2) {
            var n2, o2;
            return n2 = t2(e2), o2 = this.selectionManager.getLocationRange(), n2 || !i(o2) ? this.editor.recordUndoEntry("Formatting", {context: this.getUndoContext(), consolidatable: true}) : void 0;
          }, u.prototype.recordTypingUndoEntry = function() {
            return this.editor.recordUndoEntry("Typing", {context: this.getUndoContext(this.currentAttributes), consolidatable: true});
          }, u.prototype.getUndoContext = function() {
            var t3;
            return t3 = 1 <= arguments.length ? a.call(arguments, 0) : [], [this.getLocationContext(), this.getTimeContext()].concat(a.call(t3));
          }, u.prototype.getLocationContext = function() {
            var t3;
            return t3 = this.selectionManager.getLocationRange(), i(t3) ? t3[0].index : t3;
          }, u.prototype.getTimeContext = function() {
            return e.config.undoInterval > 0 ? Math.floor(new Date().getTime() / e.config.undoInterval) : 0;
          }, u.prototype.isFocused = function() {
            var t3;
            return this.editorElement === ((t3 = this.editorElement.ownerDocument) != null ? t3.activeElement : void 0);
          }, u.prototype.isFocusedInvisibly = function() {
            return this.isFocused() && !this.getLocationRange();
          }, u;
        }(e.Controller);
      }.call(this), function() {
        var t2, n, i, o, r, s, a, u = [].indexOf || function(t3) {
          for (var e2 = 0, n2 = this.length; n2 > e2; e2++)
            if (e2 in this && this[e2] === t3)
              return e2;
          return -1;
        };
        n = e.browser, s = e.makeElement, a = e.triggerEvent, o = e.handleEvent, r = e.handleEventOnce, i = e.findClosestElementFromNode, t2 = e.AttachmentView.attachmentSelector, e.registerElement("trix-editor", function() {
          var c, l, h, p, d, f, g, m, v;
          return g = 0, l = function(t3) {
            return !document.querySelector(":focus") && t3.hasAttribute("autofocus") && document.querySelector("[autofocus]") === t3 ? t3.focus() : void 0;
          }, m = function(t3) {
            return t3.hasAttribute("contenteditable") ? void 0 : (t3.setAttribute("contenteditable", ""), r("focus", {onElement: t3, withCallback: function() {
              return h(t3);
            }}));
          }, h = function(t3) {
            return d(t3), v(t3);
          }, d = function(t3) {
            return (typeof document.queryCommandSupported == "function" ? document.queryCommandSupported("enableObjectResizing") : void 0) ? (document.execCommand("enableObjectResizing", false, false), o("mscontrolselect", {onElement: t3, preventDefault: true})) : void 0;
          }, v = function() {
            var t3;
            return (typeof document.queryCommandSupported == "function" ? document.queryCommandSupported("DefaultParagraphSeparator") : void 0) && (t3 = e.config.blockAttributes["default"].tagName, t3 === "div" || t3 === "p") ? document.execCommand("DefaultParagraphSeparator", false, t3) : void 0;
          }, c = function(t3) {
            return t3.hasAttribute("role") ? void 0 : t3.setAttribute("role", "textbox");
          }, f = function(t3) {
            var e2;
            if (!t3.hasAttribute("aria-label") && !t3.hasAttribute("aria-labelledby"))
              return (e2 = function() {
                var e3, n2, i2;
                return i2 = function() {
                  var n3, i3, o2, r2;
                  for (o2 = t3.labels, r2 = [], n3 = 0, i3 = o2.length; i3 > n3; n3++)
                    e3 = o2[n3], e3.contains(t3) || r2.push(e3.textContent);
                  return r2;
                }(), (n2 = i2.join(" ")) ? t3.setAttribute("aria-label", n2) : t3.removeAttribute("aria-label");
              })(), o("focus", {onElement: t3, withCallback: e2});
          }, p = function() {
            return n.forcesObjectResizing ? {display: "inline", width: "auto"} : {display: "inline-block", width: "1px"};
          }(), {defaultCSS: "%t {\n  display: block;\n}\n\n%t:empty:not(:focus)::before {\n  content: attr(placeholder);\n  color: graytext;\n  cursor: text;\n  pointer-events: none;\n}\n\n%t a[contenteditable=false] {\n  cursor: text;\n}\n\n%t img {\n  max-width: 100%;\n  height: auto;\n}\n\n%t " + t2 + " figcaption textarea {\n  resize: none;\n}\n\n%t " + t2 + " figcaption textarea.trix-autoresize-clone {\n  position: absolute;\n  left: -9999px;\n  max-height: 0px;\n}\n\n%t " + t2 + " figcaption[data-trix-placeholder]:empty::before {\n  content: attr(data-trix-placeholder);\n  color: graytext;\n}\n\n%t [data-trix-cursor-target] {\n  display: " + p.display + " !important;\n  width: " + p.width + " !important;\n  padding: 0 !important;\n  margin: 0 !important;\n  border: none !important;\n}\n\n%t [data-trix-cursor-target=left] {\n  vertical-align: top !important;\n  margin-left: -1px !important;\n}\n\n%t [data-trix-cursor-target=right] {\n  vertical-align: bottom !important;\n  margin-right: -1px !important;\n}", trixId: {get: function() {
            return this.hasAttribute("trix-id") ? this.getAttribute("trix-id") : (this.setAttribute("trix-id", ++g), this.trixId);
          }}, labels: {get: function() {
            var t3, e2, n2;
            return e2 = [], this.id && this.ownerDocument && e2.push.apply(e2, this.ownerDocument.querySelectorAll("label[for='" + this.id + "']")), (t3 = i(this, {matchingSelector: "label"})) && ((n2 = t3.control) === this || n2 === null) && e2.push(t3), e2;
          }}, toolbarElement: {get: function() {
            var t3, e2, n2;
            return this.hasAttribute("toolbar") ? (e2 = this.ownerDocument) != null ? e2.getElementById(this.getAttribute("toolbar")) : void 0 : this.parentNode ? (n2 = "trix-toolbar-" + this.trixId, this.setAttribute("toolbar", n2), t3 = s("trix-toolbar", {id: n2}), this.parentNode.insertBefore(t3, this), t3) : void 0;
          }}, inputElement: {get: function() {
            var t3, e2, n2;
            return this.hasAttribute("input") ? (n2 = this.ownerDocument) != null ? n2.getElementById(this.getAttribute("input")) : void 0 : this.parentNode ? (e2 = "trix-input-" + this.trixId, this.setAttribute("input", e2), t3 = s("input", {type: "hidden", id: e2}), this.parentNode.insertBefore(t3, this.nextElementSibling), t3) : void 0;
          }}, editor: {get: function() {
            var t3;
            return (t3 = this.editorController) != null ? t3.editor : void 0;
          }}, name: {get: function() {
            var t3;
            return (t3 = this.inputElement) != null ? t3.name : void 0;
          }}, value: {get: function() {
            var t3;
            return (t3 = this.inputElement) != null ? t3.value : void 0;
          }, set: function(t3) {
            var e2;
            return this.defaultValue = t3, (e2 = this.editor) != null ? e2.loadHTML(this.defaultValue) : void 0;
          }}, notify: function(t3, e2) {
            return this.editorController ? a("trix-" + t3, {onElement: this, attributes: e2}) : void 0;
          }, setInputElementValue: function(t3) {
            var e2;
            return (e2 = this.inputElement) != null ? e2.value = t3 : void 0;
          }, initialize: function() {
            return this.hasAttribute("data-trix-internal") ? void 0 : (m(this), c(this), f(this));
          }, connect: function() {
            return this.hasAttribute("data-trix-internal") ? void 0 : (this.editorController || (a("trix-before-initialize", {onElement: this}), this.editorController = new e.EditorController({editorElement: this, html: this.defaultValue = this.value}), requestAnimationFrame(function(t3) {
              return function() {
                return a("trix-initialize", {onElement: t3});
              };
            }(this))), this.editorController.registerSelectionManager(), this.registerResetListener(), this.registerClickListener(), l(this));
          }, disconnect: function() {
            var t3;
            return (t3 = this.editorController) != null && t3.unregisterSelectionManager(), this.unregisterResetListener(), this.unregisterClickListener();
          }, registerResetListener: function() {
            return this.resetListener = this.resetBubbled.bind(this), window.addEventListener("reset", this.resetListener, false);
          }, unregisterResetListener: function() {
            return window.removeEventListener("reset", this.resetListener, false);
          }, registerClickListener: function() {
            return this.clickListener = this.clickBubbled.bind(this), window.addEventListener("click", this.clickListener, false);
          }, unregisterClickListener: function() {
            return window.removeEventListener("click", this.clickListener, false);
          }, resetBubbled: function(t3) {
            var e2;
            if (!t3.defaultPrevented && t3.target === ((e2 = this.inputElement) != null ? e2.form : void 0))
              return this.reset();
          }, clickBubbled: function(t3) {
            var e2;
            if (!(t3.defaultPrevented || this.contains(t3.target) || !(e2 = i(t3.target, {matchingSelector: "label"})) || u.call(this.labels, e2) < 0))
              return this.focus();
          }, reset: function() {
            return this.value = this.defaultValue;
          }};
        }());
      }.call(this), function() {
      }.call(this);
    }).call(this), module.exports ? module.exports = e : false;
  }.call(commonjsGlobal);
});
export default trix;
