define(
    ["angular-lib", "jquery-lib", "underscore-lib", "app-util", "app-service-registry"],
    function () {
        return function (appModule, extension, meta) {
            var FEATURE = "BookService",
                PLATFORM = "embedded",
                BookService = function ($rootScope, $http, $timeout, $q, $exceptionHandler, $compile, $cookies, $cookieStore, utilService, angularConstants, angularEventTypes, serviceRegistry) {
                    this.$rootScope = $rootScope;
                    this.$http = $http;
                    this.$timeout = $timeout;
                    this.$q = $q;
                    this.$exceptionHandler = $exceptionHandler;
                    this.$compile = $compile;
                    this.$cookies = $cookies;
                    this.$cookieStore = $cookieStore;
                    this.utilService = utilService;
                    this.serviceRegistry = serviceRegistry;
                    this.angularConstants = angularConstants;
                    this.angularEventTypes = angularEventTypes;
                };

            BookService.$inject = ["$rootScope", "$http", "$timeout", "$q", "$exceptionHandler", "$compile", "$cookies", "$cookieStore", "utilService", "angularConstants", "angularEventTypes", "serviceRegistry"];

            BookService.prototype.registerService = function () {
                this.serviceRegistry && this.serviceRegistry.register(this, FEATURE, PLATFORM);
            };

            BookService.prototype.unregisterService = function () {
                this.serviceRegistry && this.serviceRegistry.unregister(FEATURE, PLATFORM);
            };

            BookService.prototype.cordovaPromise = function (functionName) {
                var self = this;

                function cordovaReady(fn) {

                    var queue = [];

                    var impl = function () {
                        queue.push(Array.prototype.slice.call(arguments));
                    };

                    document.addEventListener('deviceready', function () {
                        queue.forEach(function (args) {
                            fn.apply(this, args);
                        });
                        impl = fn;
                    }, false);

                    return function () {
                        return impl.apply(this, arguments);
                    };
                }
                return function () {
                    var defer = self.$q.defer();

                    cordovaReady(function () {
                        cordova.exec(
                            function (result) {
                                defer.resolve(result);
                            },
                            function (err) {
                                defer.reject(err);
                            },
                            "BookNativeBridge", functionName, Array.prototype.slice.call(arguments));

                    }).apply(self, Array.prototype.slice.call(arguments));

                    return defer.promise;
                }
            };

            window.cordova && appModule.
                config(["$provide", "$injector", function ($provide, $injector) {
                    $provide.decorator("flowService", ["$delegate", function($delegate) {
                        _.extend($delegate.constructor.prototype, BookService.prototype);
                        return $delegate;
                    }]);
                    $provide.service('embeddedBookService', BookService);
                    var svc = $injector.get('embeddedBookService').$get();
                    svc.registerService();
                }]);
        };
    }
)
;