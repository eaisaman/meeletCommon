define(
    ["angular-lib", "jquery-lib", "underscore-lib", "app-util", "app-service-registry"],
    function () {
        return function (appModule, extension, meta) {
            var FEATURE = "BookService",
                PLATFORM = "browser",
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

            appModule.
                config(["$provide", "$injector", function ($provide, $injector) {
                    $provide.service('bookService', BookService);

                    var instance = $injector.get('bookServiceProvider').$get();
                    instance.registerService();
                }]);
        };
    }
)
;