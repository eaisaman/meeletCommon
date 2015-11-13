define(
    ["angular-lib", "jquery-lib", "underscore-lib", "app-util", "app-service-registry"],
    function () {
        return function (appModule, extension, meta) {
            var FEATURE = "BaseService",
                PLATFORM = "embedded",
                appService = function ($rootScope, $http, $timeout, $q, $exceptionHandler, $compile, $cookies, $cookieStore, utilService, angularConstants, angularEventTypes, serviceRegistry) {
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
                    this.appMeta = this.pageMeta = angular.copy(meta);
                };

            appService.$inject = ["$rootScope", "$http", "$timeout", "$q", "$exceptionHandler", "$compile", "$cookies", "$cookieStore", "utilService", "angularConstants", "angularEventTypes", "serviceRegistry"];

            appService.prototype.registerService = function () {
                this.serviceRegistry && this.serviceRegistry.register(this, FEATURE, PLATFORM);
            };

            appService.prototype.unregisterService = function () {
                this.serviceRegistry && this.serviceRegistry.unregister(FEATURE, PLATFORM);
            };

            appService.prototype.cordovaPromise = function (functionName) {
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
                            "BaseNativeBridge", functionName, Array.prototype.slice.call(arguments));

                    }).apply(self, Array.prototype.slice.call(arguments));

                    return defer.promise;
                }
            };

            /* Services managed by registry are visible to designer, serving generated app. */
            appService.prototype.refreshUser = function (loginName) {
                var self = this;

                return self.cordovaPromise("refreshUser").apply(self, [loginName]).then(
                    function () {
                        return self.restoreUserFromStorage();
                    },
                    function (err) {
                        return self.getRejectDefer(err);
                    }
                );
            };

            appService.prototype.doLogin = function (loginName, password) {
                var self = this;

                return self.cordovaPromise("doLogin").apply(self, [loginName, password]).then(
                    function () {
                        return self.restoreUserFromStorage();
                    },
                    function (err) {
                        return self.getRejectDefer(err);
                    }
                );
            };

            appService.prototype.doLogout = function () {
                var self = this;

                return this.cordovaPromise("doLogout").apply(this, Array.prototype.slice.call(arguments)).then(
                    function () {
                        var defer = self.$q.defer();

                        self.$timeout(function () {
                            for (var key in self.$rootScope.loginUser) {
                                delete self.$rootScope.loginUser[key];
                            }

                            defer.resolve();
                        });

                        return defer.promise;
                    },
                    function (err) {
                        return self.getRejectDefer(err);
                    }
                );
            };

            appService.prototype.restoreUserFromStorage = function () {
                var self = this;

                return self.cordovaPromise("restoreUserFromStorage").apply(this, Array.prototype.slice.call(arguments)).then(
                    function (result) {
                        var defer = self.$q.defer(),
                            userObj = result.data.resultValue;

                        self.$timeout(function () {
                            self.$rootScope.loginUser = self.$rootScope.loginUser || {};

                            for (var key in self.$rootScope.loginUser) {
                                delete self.$rootScope.loginUser[key];
                            }

                            for (var key in userObj) {
                                self.$rootScope.loginUser[key] = userObj[key];
                            }

                            defer.resolve(userObj);
                        });

                        return defer.promise;
                    },
                    function (err) {
                        return self.getRejectDefer(err);
                    }
                );
            };

            appService.prototype.getUserDetail = function (userFilter) {
                return this.cordovaPromise("getUserDetail").apply(this, [JSON.stringify(userFilter)]);
            };

            appService.prototype.getProject = function (projectFilter) {
                return this.cordovaPromise("getProject").apply(this, [JSON.stringify(projectFilter)]);
            };

            appService.prototype.getServerUrl = function () {
                return this.cordovaPromise("getServerUrl").apply(this, []);
            };

            appService.prototype.getDeviceId = function () {
                return this.cordovaPromise("getDeviceId").apply(this, []);
            };

            appService.prototype.getChatServerHost = function () {
                return this.cordovaPromise("getChatServerHost").apply(this, []);
            };

            appService.prototype.getChatServerPort = function () {
                return this.cordovaPromise("getChatServerPort").apply(this, []);
            };

            window.cordova && appModule.
                config(["$provide", "$injector", function ($provide, $injector) {
                    $provide.decorator("appService", ["$delegate", function ($delegate) {
                        _.extend($delegate.constructor.prototype, appService.prototype);
                        return $delegate;
                    }]);
                    $provide.service('embeddedAppService', appService);
                    var svc = $injector.get('embeddedAppServiceProvider').$get();
                    svc.registerService();
                }]);
        };
    }
)
;