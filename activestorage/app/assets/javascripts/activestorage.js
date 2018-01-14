(function webpackUniversalModuleDefinition(root, factory) {
	if(typeof exports === 'object' && typeof module === 'object')
		module.exports = factory();
	else if(typeof define === 'function' && define.amd)
		define([], factory);
	else if(typeof exports === 'object')
		exports["ActiveStorage"] = factory();
	else
		root["ActiveStorage"] = factory();
})(this, function() {
return /******/ (function(modules) { // webpackBootstrap
/******/ 	// The module cache
/******/ 	var installedModules = {};
/******/
/******/ 	// The require function
/******/ 	function __webpack_require__(moduleId) {
/******/
/******/ 		// Check if module is in cache
/******/ 		if(installedModules[moduleId]) {
/******/ 			return installedModules[moduleId].exports;
/******/ 		}
/******/ 		// Create a new module (and put it into the cache)
/******/ 		var module = installedModules[moduleId] = {
/******/ 			i: moduleId,
/******/ 			l: false,
/******/ 			exports: {}
/******/ 		};
/******/
/******/ 		// Execute the module function
/******/ 		modules[moduleId].call(module.exports, module, module.exports, __webpack_require__);
/******/
/******/ 		// Flag the module as loaded
/******/ 		module.l = true;
/******/
/******/ 		// Return the exports of the module
/******/ 		return module.exports;
/******/ 	}
/******/
/******/
/******/ 	// expose the modules object (__webpack_modules__)
/******/ 	__webpack_require__.m = modules;
/******/
/******/ 	// expose the module cache
/******/ 	__webpack_require__.c = installedModules;
/******/
/******/ 	// define getter function for harmony exports
/******/ 	__webpack_require__.d = function(exports, name, getter) {
/******/ 		if(!__webpack_require__.o(exports, name)) {
/******/ 			Object.defineProperty(exports, name, {
/******/ 				configurable: false,
/******/ 				enumerable: true,
/******/ 				get: getter
/******/ 			});
/******/ 		}
/******/ 	};
/******/
/******/ 	// getDefaultExport function for compatibility with non-harmony modules
/******/ 	__webpack_require__.n = function(module) {
/******/ 		var getter = module && module.__esModule ?
/******/ 			function getDefault() { return module['default']; } :
/******/ 			function getModuleExports() { return module; };
/******/ 		__webpack_require__.d(getter, 'a', getter);
/******/ 		return getter;
/******/ 	};
/******/
/******/ 	// Object.prototype.hasOwnProperty.call
/******/ 	__webpack_require__.o = function(object, property) { return Object.prototype.hasOwnProperty.call(object, property); };
/******/
/******/ 	// __webpack_public_path__
/******/ 	__webpack_require__.p = "";
/******/
/******/ 	// Load entry module and return exports
/******/ 	return __webpack_require__(__webpack_require__.s = 2);
/******/ })
/************************************************************************/
/******/ ([
/* 0 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
/* harmony export (immutable) */ __webpack_exports__["d"] = getMetaValue;
/* harmony export (immutable) */ __webpack_exports__["c"] = findElements;
/* harmony export (immutable) */ __webpack_exports__["b"] = findElement;
/* harmony export (immutable) */ __webpack_exports__["a"] = dispatchEvent;
/* harmony export (immutable) */ __webpack_exports__["e"] = toArray;
function getMetaValue(name) {
  var element = findElement(document.head, "meta[name=\"" + name + "\"]");
  if (element) {
    return element.getAttribute("content");
  }
}

function findElements(root, selector) {
  if (typeof root == "string") {
    selector = root;
    root = document;
  }
  var elements = root.querySelectorAll(selector);
  return toArray(elements);
}

function findElement(root, selector) {
  if (typeof root == "string") {
    selector = root;
    root = document;
  }
  return root.querySelector(selector);
}

function dispatchEvent(element, type) {
  var eventInit = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : {};
  var disabled = element.disabled;
  var bubbles = eventInit.bubbles,
      cancelable = eventInit.cancelable,
      detail = eventInit.detail;

  var event = document.createEvent("Event");

  event.initEvent(type, bubbles || true, cancelable || true);
  event.detail = detail || {};

  try {
    element.disabled = false;
    element.dispatchEvent(event);
  } finally {
    element.disabled = disabled;
  }

  return event;
}

function toArray(value) {
  if (Array.isArray(value)) {
    return value;
  } else if (Array.from) {
    return Array.from(value);
  } else {
    return [].slice.call(value);
  }
}

/***/ }),
/* 1 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "a", function() { return DirectUpload; });
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_0__file_checksum__ = __webpack_require__(6);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_1__blob_record__ = __webpack_require__(8);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_2__blob_upload__ = __webpack_require__(9);
var _createClass = function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ("value" in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; }();

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }





var id = 0;

var DirectUpload = function () {
  function DirectUpload(file, url, delegate) {
    _classCallCheck(this, DirectUpload);

    this.id = ++id;
    this.file = file;
    this.url = url;
    this.delegate = delegate;
  }

  _createClass(DirectUpload, [{
    key: "create",
    value: function create(callback) {
      var _this = this;

      __WEBPACK_IMPORTED_MODULE_0__file_checksum__["a" /* FileChecksum */].create(this.file, function (error, checksum) {
        var blob = new __WEBPACK_IMPORTED_MODULE_1__blob_record__["a" /* BlobRecord */](_this.file, checksum, _this.url);
        notify(_this.delegate, "directUploadWillCreateBlobWithXHR", blob.xhr);
        blob.create(function (error) {
          if (error) {
            callback(error);
          } else {
            var upload = new __WEBPACK_IMPORTED_MODULE_2__blob_upload__["a" /* BlobUpload */](blob);
            notify(_this.delegate, "directUploadWillStoreFileWithXHR", upload.xhr);
            upload.create(function (error) {
              if (error) {
                callback(error);
              } else {
                callback(null, blob.toJSON());
              }
            });
          }
        });
      });
    }
  }]);

  return DirectUpload;
}();

function notify(object, methodName) {
  if (object && typeof object[methodName] == "function") {
    for (var _len = arguments.length, messages = Array(_len > 2 ? _len - 2 : 0), _key = 2; _key < _len; _key++) {
      messages[_key - 2] = arguments[_key];
    }

    return object[methodName].apply(object, messages);
  }
}

/***/ }),
/* 2 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
Object.defineProperty(__webpack_exports__, "__esModule", { value: true });
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_0__ujs__ = __webpack_require__(3);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_1__direct_upload__ = __webpack_require__(1);
/* harmony reexport (binding) */ __webpack_require__.d(__webpack_exports__, "start", function() { return __WEBPACK_IMPORTED_MODULE_0__ujs__["a"]; });
/* harmony reexport (binding) */ __webpack_require__.d(__webpack_exports__, "DirectUpload", function() { return __WEBPACK_IMPORTED_MODULE_1__direct_upload__["a"]; });




function autostart() {
  if (window.ActiveStorage) {
    Object(__WEBPACK_IMPORTED_MODULE_0__ujs__["a" /* start */])();
  }
}

setTimeout(autostart, 1);

/***/ }),
/* 3 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
/* harmony export (immutable) */ __webpack_exports__["a"] = start;
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_0__direct_uploads_controller__ = __webpack_require__(4);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_1__helpers__ = __webpack_require__(0);



var processingAttribute = "data-direct-uploads-processing";
var started = false;

function start() {
  if (!started) {
    started = true;
    document.addEventListener("submit", didSubmitForm);
    document.addEventListener("ajax:before", didSubmitRemoteElement);
  }
}

function didSubmitForm(event) {
  handleFormSubmissionEvent(event);
}

function didSubmitRemoteElement(event) {
  if (event.target.tagName == "FORM") {
    handleFormSubmissionEvent(event);
  }
}

function handleFormSubmissionEvent(event) {
  var form = event.target;

  if (form.hasAttribute(processingAttribute)) {
    event.preventDefault();
    return;
  }

  var controller = new __WEBPACK_IMPORTED_MODULE_0__direct_uploads_controller__["a" /* DirectUploadsController */](form);
  var inputs = controller.inputs;


  if (inputs.length) {
    event.preventDefault();
    form.setAttribute(processingAttribute, "");
    inputs.forEach(disable);
    controller.start(function (error) {
      form.removeAttribute(processingAttribute);
      if (error) {
        inputs.forEach(enable);
      } else {
        submitForm(form);
      }
    });
  }
}

function submitForm(form) {
  var button = Object(__WEBPACK_IMPORTED_MODULE_1__helpers__["b" /* findElement */])(form, "input[type=submit]");
  if (button) {
    var _button = button,
        disabled = _button.disabled;

    button.disabled = false;
    button.focus();
    button.click();
    button.disabled = disabled;
  } else {
    button = document.createElement("input");
    button.type = "submit";
    button.style = "display:none";
    form.appendChild(button);
    button.click();
    form.removeChild(button);
  }
}

function disable(input) {
  input.disabled = true;
}

function enable(input) {
  input.disabled = false;
}

/***/ }),
/* 4 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "a", function() { return DirectUploadsController; });
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_0__direct_upload_controller__ = __webpack_require__(5);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_1__helpers__ = __webpack_require__(0);
var _createClass = function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ("value" in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; }();

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }




var inputSelector = "input[type=file][data-direct-upload-url]:not([disabled])";

var DirectUploadsController = function () {
  function DirectUploadsController(form) {
    _classCallCheck(this, DirectUploadsController);

    this.form = form;
    this.inputs = Object(__WEBPACK_IMPORTED_MODULE_1__helpers__["c" /* findElements */])(form, inputSelector).filter(function (input) {
      return input.files.length;
    });
  }

  _createClass(DirectUploadsController, [{
    key: "start",
    value: function start(callback) {
      var _this = this;

      var controllers = this.createDirectUploadControllers();

      var startNextController = function startNextController() {
        var controller = controllers.shift();
        if (controller) {
          controller.start(function (error) {
            if (error) {
              callback(error);
              _this.dispatch("end");
            } else {
              startNextController();
            }
          });
        } else {
          callback();
          _this.dispatch("end");
        }
      };

      this.dispatch("start");
      startNextController();
    }
  }, {
    key: "createDirectUploadControllers",
    value: function createDirectUploadControllers() {
      var controllers = [];
      this.inputs.forEach(function (input) {
        Object(__WEBPACK_IMPORTED_MODULE_1__helpers__["e" /* toArray */])(input.files).forEach(function (file) {
          var controller = new __WEBPACK_IMPORTED_MODULE_0__direct_upload_controller__["a" /* DirectUploadController */](input, file);
          controllers.push(controller);
        });
      });
      return controllers;
    }
  }, {
    key: "dispatch",
    value: function dispatch(name) {
      var detail = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};

      return Object(__WEBPACK_IMPORTED_MODULE_1__helpers__["a" /* dispatchEvent */])(this.form, "direct-uploads:" + name, { detail: detail });
    }
  }]);

  return DirectUploadsController;
}();

/***/ }),
/* 5 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "a", function() { return DirectUploadController; });
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_0__direct_upload__ = __webpack_require__(1);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_1__helpers__ = __webpack_require__(0);
var _createClass = function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ("value" in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; }();

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }




var DirectUploadController = function () {
  function DirectUploadController(input, file) {
    _classCallCheck(this, DirectUploadController);

    this.input = input;
    this.file = file;
    this.directUpload = new __WEBPACK_IMPORTED_MODULE_0__direct_upload__["a" /* DirectUpload */](this.file, this.url, this);
    this.dispatch("initialize");
  }

  _createClass(DirectUploadController, [{
    key: "start",
    value: function start(callback) {
      var _this = this;

      var hiddenInput = document.createElement("input");
      hiddenInput.type = "hidden";
      hiddenInput.name = this.input.name;
      this.input.insertAdjacentElement("beforebegin", hiddenInput);

      this.dispatch("start");

      this.directUpload.create(function (error, attributes) {
        if (error) {
          hiddenInput.parentNode.removeChild(hiddenInput);
          _this.dispatchError(error);
        } else {
          hiddenInput.value = attributes.signed_id;
        }

        _this.dispatch("end");
        callback(error);
      });
    }
  }, {
    key: "uploadRequestDidProgress",
    value: function uploadRequestDidProgress(event) {
      var progress = event.loaded / event.total * 100;
      if (progress) {
        this.dispatch("progress", { progress: progress });
      }
    }
  }, {
    key: "dispatch",
    value: function dispatch(name) {
      var detail = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};

      detail.file = this.file;
      detail.id = this.directUpload.id;
      return Object(__WEBPACK_IMPORTED_MODULE_1__helpers__["a" /* dispatchEvent */])(this.input, "direct-upload:" + name, { detail: detail });
    }
  }, {
    key: "dispatchError",
    value: function dispatchError(error) {
      var event = this.dispatch("error", { error: error });
      if (!event.defaultPrevented) {
        alert(error);
      }
    }

    // DirectUpload delegate

  }, {
    key: "directUploadWillCreateBlobWithXHR",
    value: function directUploadWillCreateBlobWithXHR(xhr) {
      this.dispatch("before-blob-request", { xhr: xhr });
    }
  }, {
    key: "directUploadWillStoreFileWithXHR",
    value: function directUploadWillStoreFileWithXHR(xhr) {
      var _this2 = this;

      this.dispatch("before-storage-request", { xhr: xhr });
      xhr.upload.addEventListener("progress", function (event) {
        return _this2.uploadRequestDidProgress(event);
      });
    }
  }, {
    key: "url",
    get: function get() {
      return this.input.getAttribute("data-direct-upload-url");
    }
  }]);

  return DirectUploadController;
}();

/***/ }),
/* 6 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "a", function() { return FileChecksum; });
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_0_spark_md5__ = __webpack_require__(7);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_0_spark_md5___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_0_spark_md5__);
var _createClass = function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ("value" in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; }();

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }



var fileSlice = File.prototype.slice || File.prototype.mozSlice || File.prototype.webkitSlice;

var FileChecksum = function () {
  _createClass(FileChecksum, null, [{
    key: "create",
    value: function create(file, callback) {
      var instance = new FileChecksum(file);
      instance.create(callback);
    }
  }]);

  function FileChecksum(file) {
    _classCallCheck(this, FileChecksum);

    this.file = file;
    this.chunkSize = 2097152; // 2MB
    this.chunkCount = Math.ceil(this.file.size / this.chunkSize);
    this.chunkIndex = 0;
  }

  _createClass(FileChecksum, [{
    key: "create",
    value: function create(callback) {
      var _this = this;

      this.callback = callback;
      this.md5Buffer = new __WEBPACK_IMPORTED_MODULE_0_spark_md5___default.a.ArrayBuffer();
      this.fileReader = new FileReader();
      this.fileReader.addEventListener("load", function (event) {
        return _this.fileReaderDidLoad(event);
      });
      this.fileReader.addEventListener("error", function (event) {
        return _this.fileReaderDidError(event);
      });
      this.readNextChunk();
    }
  }, {
    key: "fileReaderDidLoad",
    value: function fileReaderDidLoad(event) {
      this.md5Buffer.append(event.target.result);

      if (!this.readNextChunk()) {
        var binaryDigest = this.md5Buffer.end(true);
        var base64digest = btoa(binaryDigest);
        this.callback(null, base64digest);
      }
    }
  }, {
    key: "fileReaderDidError",
    value: function fileReaderDidError(event) {
      this.callback("Error reading " + this.file.name);
    }
  }, {
    key: "readNextChunk",
    value: function readNextChunk() {
      if (this.chunkIndex < this.chunkCount) {
        var start = this.chunkIndex * this.chunkSize;
        var end = Math.min(start + this.chunkSize, this.file.size);
        var bytes = fileSlice.call(this.file, start, end);
        this.fileReader.readAsArrayBuffer(bytes);
        this.chunkIndex++;
        return true;
      } else {
        return false;
      }
    }
  }]);

  return FileChecksum;
}();

/***/ }),
/* 7 */
/***/ (function(module, exports, __webpack_require__) {

(function (factory) {
    if (true) {
        // Node/CommonJS
        module.exports = factory();
    } else if (typeof define === 'function' && define.amd) {
        // AMD
        define(factory);
    } else {
        // Browser globals (with support for web workers)
        var glob;

        try {
            glob = window;
        } catch (e) {
            glob = self;
        }

        glob.SparkMD5 = factory();
    }
}(function (undefined) {

    'use strict';

    /*
     * Fastest md5 implementation around (JKM md5).
     * Credits: Joseph Myers
     *
     * @see http://www.myersdaily.org/joseph/javascript/md5-text.html
     * @see http://jsperf.com/md5-shootout/7
     */

    /* this function is much faster,
      so if possible we use it. Some IEs
      are the only ones I know of that
      need the idiotic second function,
      generated by an if clause.  */
    var add32 = function (a, b) {
        return (a + b) & 0xFFFFFFFF;
    },
        hex_chr = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'];


    function cmn(q, a, b, x, s, t) {
        a = add32(add32(a, q), add32(x, t));
        return add32((a << s) | (a >>> (32 - s)), b);
    }

    function md5cycle(x, k) {
        var a = x[0],
            b = x[1],
            c = x[2],
            d = x[3];

        a += (b & c | ~b & d) + k[0] - 680876936 | 0;
        a  = (a << 7 | a >>> 25) + b | 0;
        d += (a & b | ~a & c) + k[1] - 389564586 | 0;
        d  = (d << 12 | d >>> 20) + a | 0;
        c += (d & a | ~d & b) + k[2] + 606105819 | 0;
        c  = (c << 17 | c >>> 15) + d | 0;
        b += (c & d | ~c & a) + k[3] - 1044525330 | 0;
        b  = (b << 22 | b >>> 10) + c | 0;
        a += (b & c | ~b & d) + k[4] - 176418897 | 0;
        a  = (a << 7 | a >>> 25) + b | 0;
        d += (a & b | ~a & c) + k[5] + 1200080426 | 0;
        d  = (d << 12 | d >>> 20) + a | 0;
        c += (d & a | ~d & b) + k[6] - 1473231341 | 0;
        c  = (c << 17 | c >>> 15) + d | 0;
        b += (c & d | ~c & a) + k[7] - 45705983 | 0;
        b  = (b << 22 | b >>> 10) + c | 0;
        a += (b & c | ~b & d) + k[8] + 1770035416 | 0;
        a  = (a << 7 | a >>> 25) + b | 0;
        d += (a & b | ~a & c) + k[9] - 1958414417 | 0;
        d  = (d << 12 | d >>> 20) + a | 0;
        c += (d & a | ~d & b) + k[10] - 42063 | 0;
        c  = (c << 17 | c >>> 15) + d | 0;
        b += (c & d | ~c & a) + k[11] - 1990404162 | 0;
        b  = (b << 22 | b >>> 10) + c | 0;
        a += (b & c | ~b & d) + k[12] + 1804603682 | 0;
        a  = (a << 7 | a >>> 25) + b | 0;
        d += (a & b | ~a & c) + k[13] - 40341101 | 0;
        d  = (d << 12 | d >>> 20) + a | 0;
        c += (d & a | ~d & b) + k[14] - 1502002290 | 0;
        c  = (c << 17 | c >>> 15) + d | 0;
        b += (c & d | ~c & a) + k[15] + 1236535329 | 0;
        b  = (b << 22 | b >>> 10) + c | 0;

        a += (b & d | c & ~d) + k[1] - 165796510 | 0;
        a  = (a << 5 | a >>> 27) + b | 0;
        d += (a & c | b & ~c) + k[6] - 1069501632 | 0;
        d  = (d << 9 | d >>> 23) + a | 0;
        c += (d & b | a & ~b) + k[11] + 643717713 | 0;
        c  = (c << 14 | c >>> 18) + d | 0;
        b += (c & a | d & ~a) + k[0] - 373897302 | 0;
        b  = (b << 20 | b >>> 12) + c | 0;
        a += (b & d | c & ~d) + k[5] - 701558691 | 0;
        a  = (a << 5 | a >>> 27) + b | 0;
        d += (a & c | b & ~c) + k[10] + 38016083 | 0;
        d  = (d << 9 | d >>> 23) + a | 0;
        c += (d & b | a & ~b) + k[15] - 660478335 | 0;
        c  = (c << 14 | c >>> 18) + d | 0;
        b += (c & a | d & ~a) + k[4] - 405537848 | 0;
        b  = (b << 20 | b >>> 12) + c | 0;
        a += (b & d | c & ~d) + k[9] + 568446438 | 0;
        a  = (a << 5 | a >>> 27) + b | 0;
        d += (a & c | b & ~c) + k[14] - 1019803690 | 0;
        d  = (d << 9 | d >>> 23) + a | 0;
        c += (d & b | a & ~b) + k[3] - 187363961 | 0;
        c  = (c << 14 | c >>> 18) + d | 0;
        b += (c & a | d & ~a) + k[8] + 1163531501 | 0;
        b  = (b << 20 | b >>> 12) + c | 0;
        a += (b & d | c & ~d) + k[13] - 1444681467 | 0;
        a  = (a << 5 | a >>> 27) + b | 0;
        d += (a & c | b & ~c) + k[2] - 51403784 | 0;
        d  = (d << 9 | d >>> 23) + a | 0;
        c += (d & b | a & ~b) + k[7] + 1735328473 | 0;
        c  = (c << 14 | c >>> 18) + d | 0;
        b += (c & a | d & ~a) + k[12] - 1926607734 | 0;
        b  = (b << 20 | b >>> 12) + c | 0;

        a += (b ^ c ^ d) + k[5] - 378558 | 0;
        a  = (a << 4 | a >>> 28) + b | 0;
        d += (a ^ b ^ c) + k[8] - 2022574463 | 0;
        d  = (d << 11 | d >>> 21) + a | 0;
        c += (d ^ a ^ b) + k[11] + 1839030562 | 0;
        c  = (c << 16 | c >>> 16) + d | 0;
        b += (c ^ d ^ a) + k[14] - 35309556 | 0;
        b  = (b << 23 | b >>> 9) + c | 0;
        a += (b ^ c ^ d) + k[1] - 1530992060 | 0;
        a  = (a << 4 | a >>> 28) + b | 0;
        d += (a ^ b ^ c) + k[4] + 1272893353 | 0;
        d  = (d << 11 | d >>> 21) + a | 0;
        c += (d ^ a ^ b) + k[7] - 155497632 | 0;
        c  = (c << 16 | c >>> 16) + d | 0;
        b += (c ^ d ^ a) + k[10] - 1094730640 | 0;
        b  = (b << 23 | b >>> 9) + c | 0;
        a += (b ^ c ^ d) + k[13] + 681279174 | 0;
        a  = (a << 4 | a >>> 28) + b | 0;
        d += (a ^ b ^ c) + k[0] - 358537222 | 0;
        d  = (d << 11 | d >>> 21) + a | 0;
        c += (d ^ a ^ b) + k[3] - 722521979 | 0;
        c  = (c << 16 | c >>> 16) + d | 0;
        b += (c ^ d ^ a) + k[6] + 76029189 | 0;
        b  = (b << 23 | b >>> 9) + c | 0;
        a += (b ^ c ^ d) + k[9] - 640364487 | 0;
        a  = (a << 4 | a >>> 28) + b | 0;
        d += (a ^ b ^ c) + k[12] - 421815835 | 0;
        d  = (d << 11 | d >>> 21) + a | 0;
        c += (d ^ a ^ b) + k[15] + 530742520 | 0;
        c  = (c << 16 | c >>> 16) + d | 0;
        b += (c ^ d ^ a) + k[2] - 995338651 | 0;
        b  = (b << 23 | b >>> 9) + c | 0;

        a += (c ^ (b | ~d)) + k[0] - 198630844 | 0;
        a  = (a << 6 | a >>> 26) + b | 0;
        d += (b ^ (a | ~c)) + k[7] + 1126891415 | 0;
        d  = (d << 10 | d >>> 22) + a | 0;
        c += (a ^ (d | ~b)) + k[14] - 1416354905 | 0;
        c  = (c << 15 | c >>> 17) + d | 0;
        b += (d ^ (c | ~a)) + k[5] - 57434055 | 0;
        b  = (b << 21 |b >>> 11) + c | 0;
        a += (c ^ (b | ~d)) + k[12] + 1700485571 | 0;
        a  = (a << 6 | a >>> 26) + b | 0;
        d += (b ^ (a | ~c)) + k[3] - 1894986606 | 0;
        d  = (d << 10 | d >>> 22) + a | 0;
        c += (a ^ (d | ~b)) + k[10] - 1051523 | 0;
        c  = (c << 15 | c >>> 17) + d | 0;
        b += (d ^ (c | ~a)) + k[1] - 2054922799 | 0;
        b  = (b << 21 |b >>> 11) + c | 0;
        a += (c ^ (b | ~d)) + k[8] + 1873313359 | 0;
        a  = (a << 6 | a >>> 26) + b | 0;
        d += (b ^ (a | ~c)) + k[15] - 30611744 | 0;
        d  = (d << 10 | d >>> 22) + a | 0;
        c += (a ^ (d | ~b)) + k[6] - 1560198380 | 0;
        c  = (c << 15 | c >>> 17) + d | 0;
        b += (d ^ (c | ~a)) + k[13] + 1309151649 | 0;
        b  = (b << 21 |b >>> 11) + c | 0;
        a += (c ^ (b | ~d)) + k[4] - 145523070 | 0;
        a  = (a << 6 | a >>> 26) + b | 0;
        d += (b ^ (a | ~c)) + k[11] - 1120210379 | 0;
        d  = (d << 10 | d >>> 22) + a | 0;
        c += (a ^ (d | ~b)) + k[2] + 718787259 | 0;
        c  = (c << 15 | c >>> 17) + d | 0;
        b += (d ^ (c | ~a)) + k[9] - 343485551 | 0;
        b  = (b << 21 | b >>> 11) + c | 0;

        x[0] = a + x[0] | 0;
        x[1] = b + x[1] | 0;
        x[2] = c + x[2] | 0;
        x[3] = d + x[3] | 0;
    }

    function md5blk(s) {
        var md5blks = [],
            i; /* Andy King said do it this way. */

        for (i = 0; i < 64; i += 4) {
            md5blks[i >> 2] = s.charCodeAt(i) + (s.charCodeAt(i + 1) << 8) + (s.charCodeAt(i + 2) << 16) + (s.charCodeAt(i + 3) << 24);
        }
        return md5blks;
    }

    function md5blk_array(a) {
        var md5blks = [],
            i; /* Andy King said do it this way. */

        for (i = 0; i < 64; i += 4) {
            md5blks[i >> 2] = a[i] + (a[i + 1] << 8) + (a[i + 2] << 16) + (a[i + 3] << 24);
        }
        return md5blks;
    }

    function md51(s) {
        var n = s.length,
            state = [1732584193, -271733879, -1732584194, 271733878],
            i,
            length,
            tail,
            tmp,
            lo,
            hi;

        for (i = 64; i <= n; i += 64) {
            md5cycle(state, md5blk(s.substring(i - 64, i)));
        }
        s = s.substring(i - 64);
        length = s.length;
        tail = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        for (i = 0; i < length; i += 1) {
            tail[i >> 2] |= s.charCodeAt(i) << ((i % 4) << 3);
        }
        tail[i >> 2] |= 0x80 << ((i % 4) << 3);
        if (i > 55) {
            md5cycle(state, tail);
            for (i = 0; i < 16; i += 1) {
                tail[i] = 0;
            }
        }

        // Beware that the final length might not fit in 32 bits so we take care of that
        tmp = n * 8;
        tmp = tmp.toString(16).match(/(.*?)(.{0,8})$/);
        lo = parseInt(tmp[2], 16);
        hi = parseInt(tmp[1], 16) || 0;

        tail[14] = lo;
        tail[15] = hi;

        md5cycle(state, tail);
        return state;
    }

    function md51_array(a) {
        var n = a.length,
            state = [1732584193, -271733879, -1732584194, 271733878],
            i,
            length,
            tail,
            tmp,
            lo,
            hi;

        for (i = 64; i <= n; i += 64) {
            md5cycle(state, md5blk_array(a.subarray(i - 64, i)));
        }

        // Not sure if it is a bug, however IE10 will always produce a sub array of length 1
        // containing the last element of the parent array if the sub array specified starts
        // beyond the length of the parent array - weird.
        // https://connect.microsoft.com/IE/feedback/details/771452/typed-array-subarray-issue
        a = (i - 64) < n ? a.subarray(i - 64) : new Uint8Array(0);

        length = a.length;
        tail = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        for (i = 0; i < length; i += 1) {
            tail[i >> 2] |= a[i] << ((i % 4) << 3);
        }

        tail[i >> 2] |= 0x80 << ((i % 4) << 3);
        if (i > 55) {
            md5cycle(state, tail);
            for (i = 0; i < 16; i += 1) {
                tail[i] = 0;
            }
        }

        // Beware that the final length might not fit in 32 bits so we take care of that
        tmp = n * 8;
        tmp = tmp.toString(16).match(/(.*?)(.{0,8})$/);
        lo = parseInt(tmp[2], 16);
        hi = parseInt(tmp[1], 16) || 0;

        tail[14] = lo;
        tail[15] = hi;

        md5cycle(state, tail);

        return state;
    }

    function rhex(n) {
        var s = '',
            j;
        for (j = 0; j < 4; j += 1) {
            s += hex_chr[(n >> (j * 8 + 4)) & 0x0F] + hex_chr[(n >> (j * 8)) & 0x0F];
        }
        return s;
    }

    function hex(x) {
        var i;
        for (i = 0; i < x.length; i += 1) {
            x[i] = rhex(x[i]);
        }
        return x.join('');
    }

    // In some cases the fast add32 function cannot be used..
    if (hex(md51('hello')) !== '5d41402abc4b2a76b9719d911017c592') {
        add32 = function (x, y) {
            var lsw = (x & 0xFFFF) + (y & 0xFFFF),
                msw = (x >> 16) + (y >> 16) + (lsw >> 16);
            return (msw << 16) | (lsw & 0xFFFF);
        };
    }

    // ---------------------------------------------------

    /**
     * ArrayBuffer slice polyfill.
     *
     * @see https://github.com/ttaubert/node-arraybuffer-slice
     */

    if (typeof ArrayBuffer !== 'undefined' && !ArrayBuffer.prototype.slice) {
        (function () {
            function clamp(val, length) {
                val = (val | 0) || 0;

                if (val < 0) {
                    return Math.max(val + length, 0);
                }

                return Math.min(val, length);
            }

            ArrayBuffer.prototype.slice = function (from, to) {
                var length = this.byteLength,
                    begin = clamp(from, length),
                    end = length,
                    num,
                    target,
                    targetArray,
                    sourceArray;

                if (to !== undefined) {
                    end = clamp(to, length);
                }

                if (begin > end) {
                    return new ArrayBuffer(0);
                }

                num = end - begin;
                target = new ArrayBuffer(num);
                targetArray = new Uint8Array(target);

                sourceArray = new Uint8Array(this, begin, num);
                targetArray.set(sourceArray);

                return target;
            };
        })();
    }

    // ---------------------------------------------------

    /**
     * Helpers.
     */

    function toUtf8(str) {
        if (/[\u0080-\uFFFF]/.test(str)) {
            str = unescape(encodeURIComponent(str));
        }

        return str;
    }

    function utf8Str2ArrayBuffer(str, returnUInt8Array) {
        var length = str.length,
           buff = new ArrayBuffer(length),
           arr = new Uint8Array(buff),
           i;

        for (i = 0; i < length; i += 1) {
            arr[i] = str.charCodeAt(i);
        }

        return returnUInt8Array ? arr : buff;
    }

    function arrayBuffer2Utf8Str(buff) {
        return String.fromCharCode.apply(null, new Uint8Array(buff));
    }

    function concatenateArrayBuffers(first, second, returnUInt8Array) {
        var result = new Uint8Array(first.byteLength + second.byteLength);

        result.set(new Uint8Array(first));
        result.set(new Uint8Array(second), first.byteLength);

        return returnUInt8Array ? result : result.buffer;
    }

    function hexToBinaryString(hex) {
        var bytes = [],
            length = hex.length,
            x;

        for (x = 0; x < length - 1; x += 2) {
            bytes.push(parseInt(hex.substr(x, 2), 16));
        }

        return String.fromCharCode.apply(String, bytes);
    }

    // ---------------------------------------------------

    /**
     * SparkMD5 OOP implementation.
     *
     * Use this class to perform an incremental md5, otherwise use the
     * static methods instead.
     */

    function SparkMD5() {
        // call reset to init the instance
        this.reset();
    }

    /**
     * Appends a string.
     * A conversion will be applied if an utf8 string is detected.
     *
     * @param {String} str The string to be appended
     *
     * @return {SparkMD5} The instance itself
     */
    SparkMD5.prototype.append = function (str) {
        // Converts the string to utf8 bytes if necessary
        // Then append as binary
        this.appendBinary(toUtf8(str));

        return this;
    };

    /**
     * Appends a binary string.
     *
     * @param {String} contents The binary string to be appended
     *
     * @return {SparkMD5} The instance itself
     */
    SparkMD5.prototype.appendBinary = function (contents) {
        this._buff += contents;
        this._length += contents.length;

        var length = this._buff.length,
            i;

        for (i = 64; i <= length; i += 64) {
            md5cycle(this._hash, md5blk(this._buff.substring(i - 64, i)));
        }

        this._buff = this._buff.substring(i - 64);

        return this;
    };

    /**
     * Finishes the incremental computation, reseting the internal state and
     * returning the result.
     *
     * @param {Boolean} raw True to get the raw string, false to get the hex string
     *
     * @return {String} The result
     */
    SparkMD5.prototype.end = function (raw) {
        var buff = this._buff,
            length = buff.length,
            i,
            tail = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            ret;

        for (i = 0; i < length; i += 1) {
            tail[i >> 2] |= buff.charCodeAt(i) << ((i % 4) << 3);
        }

        this._finish(tail, length);
        ret = hex(this._hash);

        if (raw) {
            ret = hexToBinaryString(ret);
        }

        this.reset();

        return ret;
    };

    /**
     * Resets the internal state of the computation.
     *
     * @return {SparkMD5} The instance itself
     */
    SparkMD5.prototype.reset = function () {
        this._buff = '';
        this._length = 0;
        this._hash = [1732584193, -271733879, -1732584194, 271733878];

        return this;
    };

    /**
     * Gets the internal state of the computation.
     *
     * @return {Object} The state
     */
    SparkMD5.prototype.getState = function () {
        return {
            buff: this._buff,
            length: this._length,
            hash: this._hash
        };
    };

    /**
     * Gets the internal state of the computation.
     *
     * @param {Object} state The state
     *
     * @return {SparkMD5} The instance itself
     */
    SparkMD5.prototype.setState = function (state) {
        this._buff = state.buff;
        this._length = state.length;
        this._hash = state.hash;

        return this;
    };

    /**
     * Releases memory used by the incremental buffer and other additional
     * resources. If you plan to use the instance again, use reset instead.
     */
    SparkMD5.prototype.destroy = function () {
        delete this._hash;
        delete this._buff;
        delete this._length;
    };

    /**
     * Finish the final calculation based on the tail.
     *
     * @param {Array}  tail   The tail (will be modified)
     * @param {Number} length The length of the remaining buffer
     */
    SparkMD5.prototype._finish = function (tail, length) {
        var i = length,
            tmp,
            lo,
            hi;

        tail[i >> 2] |= 0x80 << ((i % 4) << 3);
        if (i > 55) {
            md5cycle(this._hash, tail);
            for (i = 0; i < 16; i += 1) {
                tail[i] = 0;
            }
        }

        // Do the final computation based on the tail and length
        // Beware that the final length may not fit in 32 bits so we take care of that
        tmp = this._length * 8;
        tmp = tmp.toString(16).match(/(.*?)(.{0,8})$/);
        lo = parseInt(tmp[2], 16);
        hi = parseInt(tmp[1], 16) || 0;

        tail[14] = lo;
        tail[15] = hi;
        md5cycle(this._hash, tail);
    };

    /**
     * Performs the md5 hash on a string.
     * A conversion will be applied if utf8 string is detected.
     *
     * @param {String}  str The string
     * @param {Boolean} raw True to get the raw string, false to get the hex string
     *
     * @return {String} The result
     */
    SparkMD5.hash = function (str, raw) {
        // Converts the string to utf8 bytes if necessary
        // Then compute it using the binary function
        return SparkMD5.hashBinary(toUtf8(str), raw);
    };

    /**
     * Performs the md5 hash on a binary string.
     *
     * @param {String}  content The binary string
     * @param {Boolean} raw     True to get the raw string, false to get the hex string
     *
     * @return {String} The result
     */
    SparkMD5.hashBinary = function (content, raw) {
        var hash = md51(content),
            ret = hex(hash);

        return raw ? hexToBinaryString(ret) : ret;
    };

    // ---------------------------------------------------

    /**
     * SparkMD5 OOP implementation for array buffers.
     *
     * Use this class to perform an incremental md5 ONLY for array buffers.
     */
    SparkMD5.ArrayBuffer = function () {
        // call reset to init the instance
        this.reset();
    };

    /**
     * Appends an array buffer.
     *
     * @param {ArrayBuffer} arr The array to be appended
     *
     * @return {SparkMD5.ArrayBuffer} The instance itself
     */
    SparkMD5.ArrayBuffer.prototype.append = function (arr) {
        var buff = concatenateArrayBuffers(this._buff.buffer, arr, true),
            length = buff.length,
            i;

        this._length += arr.byteLength;

        for (i = 64; i <= length; i += 64) {
            md5cycle(this._hash, md5blk_array(buff.subarray(i - 64, i)));
        }

        this._buff = (i - 64) < length ? new Uint8Array(buff.buffer.slice(i - 64)) : new Uint8Array(0);

        return this;
    };

    /**
     * Finishes the incremental computation, reseting the internal state and
     * returning the result.
     *
     * @param {Boolean} raw True to get the raw string, false to get the hex string
     *
     * @return {String} The result
     */
    SparkMD5.ArrayBuffer.prototype.end = function (raw) {
        var buff = this._buff,
            length = buff.length,
            tail = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            i,
            ret;

        for (i = 0; i < length; i += 1) {
            tail[i >> 2] |= buff[i] << ((i % 4) << 3);
        }

        this._finish(tail, length);
        ret = hex(this._hash);

        if (raw) {
            ret = hexToBinaryString(ret);
        }

        this.reset();

        return ret;
    };

    /**
     * Resets the internal state of the computation.
     *
     * @return {SparkMD5.ArrayBuffer} The instance itself
     */
    SparkMD5.ArrayBuffer.prototype.reset = function () {
        this._buff = new Uint8Array(0);
        this._length = 0;
        this._hash = [1732584193, -271733879, -1732584194, 271733878];

        return this;
    };

    /**
     * Gets the internal state of the computation.
     *
     * @return {Object} The state
     */
    SparkMD5.ArrayBuffer.prototype.getState = function () {
        var state = SparkMD5.prototype.getState.call(this);

        // Convert buffer to a string
        state.buff = arrayBuffer2Utf8Str(state.buff);

        return state;
    };

    /**
     * Gets the internal state of the computation.
     *
     * @param {Object} state The state
     *
     * @return {SparkMD5.ArrayBuffer} The instance itself
     */
    SparkMD5.ArrayBuffer.prototype.setState = function (state) {
        // Convert string to buffer
        state.buff = utf8Str2ArrayBuffer(state.buff, true);

        return SparkMD5.prototype.setState.call(this, state);
    };

    SparkMD5.ArrayBuffer.prototype.destroy = SparkMD5.prototype.destroy;

    SparkMD5.ArrayBuffer.prototype._finish = SparkMD5.prototype._finish;

    /**
     * Performs the md5 hash on an array buffer.
     *
     * @param {ArrayBuffer} arr The array buffer
     * @param {Boolean}     raw True to get the raw string, false to get the hex one
     *
     * @return {String} The result
     */
    SparkMD5.ArrayBuffer.hash = function (arr, raw) {
        var hash = md51_array(new Uint8Array(arr)),
            ret = hex(hash);

        return raw ? hexToBinaryString(ret) : ret;
    };

    return SparkMD5;
}));


/***/ }),
/* 8 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "a", function() { return BlobRecord; });
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_0__helpers__ = __webpack_require__(0);
var _createClass = function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ("value" in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; }();

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }



var BlobRecord = function () {
  function BlobRecord(file, checksum, url) {
    var _this = this;

    _classCallCheck(this, BlobRecord);

    this.file = file;

    this.attributes = {
      filename: file.name,
      content_type: file.type,
      byte_size: file.size,
      checksum: checksum
    };

    this.xhr = new XMLHttpRequest();
    this.xhr.open("POST", url, true);
    this.xhr.responseType = "json";
    this.xhr.setRequestHeader("Content-Type", "application/json");
    this.xhr.setRequestHeader("Accept", "application/json");
    this.xhr.setRequestHeader("X-Requested-With", "XMLHttpRequest");
    this.xhr.setRequestHeader("X-CSRF-Token", Object(__WEBPACK_IMPORTED_MODULE_0__helpers__["d" /* getMetaValue */])("csrf-token"));
    this.xhr.addEventListener("load", function (event) {
      return _this.requestDidLoad(event);
    });
    this.xhr.addEventListener("error", function (event) {
      return _this.requestDidError(event);
    });
  }

  _createClass(BlobRecord, [{
    key: "create",
    value: function create(callback) {
      this.callback = callback;
      this.xhr.send(JSON.stringify({ blob: this.attributes }));
    }
  }, {
    key: "requestDidLoad",
    value: function requestDidLoad(event) {
      if (this.status >= 200 && this.status < 300) {
        var response = this.response;
        var direct_upload = response.direct_upload;

        delete response.direct_upload;
        this.attributes = response;
        this.directUploadData = direct_upload;
        this.callback(null, this.toJSON());
      } else {
        this.requestDidError(event);
      }
    }
  }, {
    key: "requestDidError",
    value: function requestDidError(event) {
      this.callback("Error creating Blob for \"" + this.file.name + "\". Status: " + this.status);
    }
  }, {
    key: "toJSON",
    value: function toJSON() {
      var result = {};
      for (var key in this.attributes) {
        result[key] = this.attributes[key];
      }
      return result;
    }
  }, {
    key: "status",
    get: function get() {
      return this.xhr.status;
    }
  }, {
    key: "response",
    get: function get() {
      var _xhr = this.xhr,
          responseType = _xhr.responseType,
          response = _xhr.response;

      if (responseType == "json") {
        return response;
      } else {
        // Shim for IE 11: https://connect.microsoft.com/IE/feedback/details/794808
        return JSON.parse(response);
      }
    }
  }]);

  return BlobRecord;
}();

/***/ }),
/* 9 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "a", function() { return BlobUpload; });
var _createClass = function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ("value" in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; }();

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }

var BlobUpload = function () {
  function BlobUpload(blob) {
    var _this = this;

    _classCallCheck(this, BlobUpload);

    this.blob = blob;
    this.file = blob.file;

    var _blob$directUploadDat = blob.directUploadData,
        url = _blob$directUploadDat.url,
        headers = _blob$directUploadDat.headers;


    this.xhr = new XMLHttpRequest();
    this.xhr.open("PUT", url, true);
    this.xhr.responseType = "text";
    for (var key in headers) {
      this.xhr.setRequestHeader(key, headers[key]);
    }
    this.xhr.addEventListener("load", function (event) {
      return _this.requestDidLoad(event);
    });
    this.xhr.addEventListener("error", function (event) {
      return _this.requestDidError(event);
    });
  }

  _createClass(BlobUpload, [{
    key: "create",
    value: function create(callback) {
      this.callback = callback;
      this.xhr.send(this.file);
    }
  }, {
    key: "requestDidLoad",
    value: function requestDidLoad(event) {
      var _xhr = this.xhr,
          status = _xhr.status,
          response = _xhr.response;

      if (status >= 200 && status < 300) {
        this.callback(null, response);
      } else {
        this.requestDidError(event);
      }
    }
  }, {
    key: "requestDidError",
    value: function requestDidError(event) {
      this.callback("Error storing \"" + this.file.name + "\". Status: " + this.xhr.status);
    }
  }]);

  return BlobUpload;
}();

/***/ })
/******/ ]);
});