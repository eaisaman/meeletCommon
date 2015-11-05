define(
    ["angular"],
    function () {
        return function (appModule, registry) {
            var serviceRegistry = function ($rootScope, $http, $timeout, $q, $log, angularConstants) {
                this.$rootScope = $rootScope;
                this.$http = $http;
                this.$timeout = $timeout;
                this.$q = $q;
                this.$log = $log;
                this.angularConstants = angularConstants;
                this.registry = _.clone(registry);
            };

            serviceRegistry.$inject = ["$rootScope", "$http", "$timeout", "$q", "$log", "angularConstants"];

            serviceRegistry.prototype.makeGlobal = function () {
                window.serviceRegistry = this;
            };

            /**
             * @description
             *
             * When a new serviceImpl is registered, a new object with implemented functions is
             * set to feature item's impl. This object inherits previous object created during
             * service registration. So new service function overrides old one, while other old
             * service functions may still served for unimplemented functions.
             *
             * @param serviceImpl
             * @param feature
             */
            serviceRegistry.prototype.register = function (serviceImpl, feature, platform) {
                var self = this,
                    featureItem = _.findWhere(self.registry, {feature: feature});

                if (featureItem && serviceImpl) {
                    if (featureItem.impl && featureItem.impl.canRunOn(platform)) {
                        return;
                    }

                    var featureClassTmpl = {
                            FEATURE_NAME: feature,
                            MEMBERS: {
                                platform: null,
                                delegate: null,
                                eventWatchers: {}
                            },
                            initialize: function (delegate, platform) {
                                var MEMBERS = arguments.callee.prototype.MEMBERS;

                                for (var member in MEMBERS) {
                                    this[member] = angular.copy(MEMBERS[member]);
                                }

                                this.delegate = delegate;
                                this.platform = platform;
                            },
                            canRunOn: function (platform) {
                                return this.platform == platform;
                            },
                            unregister: function (platform, offspring) {
                                var clazz = featureClassTmpl.initialize;

                                if (this.canRunOn(platform)) {
                                    if (offspring) {
                                        offspring.initialize.prototype.__proto__ = clazz.prototype.__proto__;
                                    } else {
                                        var impl = clazz.prototype.__proto__,
                                            item = _.findWhere(self.registry, {feature: feature});
                                        if (_.isEmpty(impl)) {
                                            delete item.impl;
                                        } else {
                                            item.impl = impl;
                                        }
                                    }

                                    _.each(this.eventWatchers, function (watcher) {
                                        watcher && watcher();
                                    });
                                    delete this.delegate;
                                } else {
                                    clazz.prototype.__proto__.unregister(platform, this);
                                }
                            },
                            set: function (attrs) {
                                var self = this;

                                _.each(attrs, function (value, key) {
                                    self.delegate[key] = _.clone(value);
                                });
                            }
                        },
                        serviceList = featureItem.serviceList,
                        featureClass;

                    _.each(serviceList, function (serviceItem) {
                        var fn = serviceImpl[serviceItem.name];

                        if (fn && typeof fn === "function") {
                            switch (serviceItem.communicationType) {
                                case "one-way":
                                    featureClassTmpl[serviceItem.name] = function () {
                                        fn.apply(this.delegate, Array.prototype.slice.call(arguments));
                                    };
                                    break;
                                case "callback":
                                    featureClassTmpl[serviceItem.name] = function () {
                                        //Promise.then
                                        return fn.apply(this.delegate, Array.prototype.slice.call(arguments));
                                    };
                                    break;
                                case "event":
                                    featureClassTmpl[serviceItem.name] = function (eventHandler, eventId) {
                                        var instance = this;

                                        eventId = eventId || "SERVICE-EVENT-FEATURE-{0}-SERVICE-{1}-{2}".format(feature, serviceItem.name, _.now());
                                        instance.eventWatchers[eventId] && instance.eventWatchers[eventId]();
                                        instance.eventWatchers[eventId] = self.$rootScope.$on(eventId, function (event, result) {
                                            try {
                                                eventHandler && eventHandler(result);
                                            } catch (e) {
                                                self.$exceptionHandler(e);
                                            }

                                            if (instance.eventWatchers[eventId]) {
                                                instance.eventWatchers[eventId]();
                                                delete instance.eventWatchers[eventId];
                                            }
                                        });

                                        fn.apply(instance.delegate, Array.prototype.concat.apply([eventId], Array.prototype.slice.call(arguments, 1, arguments.length)));
                                    };
                                    break;
                            }
                        }
                    });

                    featureClass = featureClassTmpl.initialize;
                    featureClass.prototype = featureClassTmpl;
                    if (featureItem.impl) {
                        featureClassTmpl.__proto__ = featureItem.impl;
                    }

                    featureItem.impl = new featureClass(serviceImpl, platform);
                }
            };

            serviceRegistry.prototype.unregister = function (feature, platform) {
                var self = this,
                    featureItem = _.findWhere(self.registry, {feature: feature});

                if (featureItem && featureItem.impl) {
                    featureItem.impl.unregister(platform);
                }
            };

            serviceRegistry.prototype.invoke = function (feature, serviceName) {
                var self = this,
                    featureItem = _.findWhere(self.registry, {feature: feature});

                if (featureItem && featureItem.impl) {
                    var fn = featureItem.impl[serviceName];
                    if (fn) {
                        return function () {
                            fn.apply(featureItem.impl, Array.prototype.slice.call(arguments));
                        };
                    } else {
                        self.$log.warn("Function {0} not found on implementation of feature {1}".format(serviceName, feature));
                    }
                } else {
                    self.$log.warn("Feature " + feature + " not found or its implementation undefined.");
                }

                return angular.noop;
            };

            serviceRegistry.prototype.setServiceAttribute = function (feature, attrs) {
                var self = this,
                    featureItem = _.findWhere(self.registry, {feature: feature});

                if (featureItem && featureItem.impl) {
                    featureItem.impl.set(attrs);
                }
            }

            appModule.
                config(["$provide", function ($provide) {
                    $provide.service('serviceRegistry', serviceRegistry);
                }]);
        }
    }
)
;