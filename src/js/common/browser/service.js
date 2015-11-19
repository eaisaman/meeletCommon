define(
    ["angular-lib", "jquery-lib", "underscore-lib", "app-util", "app-service-registry"],
    function () {
        return function (appModule, extension, meta) {
            var FEATURE = "BaseService",
                PLATFORM = "browser",
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

                    _.extend(SoundContructor.prototype, _.pick(this, appService.$inject));
                };

            appService.$inject = ["$rootScope", "$http", "$timeout", "$q", "$exceptionHandler", "$compile", "$cookies", "$cookieStore", "utilService", "angularConstants", "angularEventTypes", "serviceRegistry"];

            var SoundContructor = function () {
                this.audioSourceNode = null;
                this.audioScriptNode = null;
                this.audioContext = null;
                this.offlineAudioContext = null;
            };

            SoundContructor.prototype.PLAYING_STATE = 0;
            SoundContructor.prototype.PAUSED_STATE = 1;
            SoundContructor.prototype.FINISHED_STATE = 2;
            SoundContructor.prototype.soundSeekPrecision = 100000;

            SoundContructor.prototype.createAudioProcessHandler = function (handler) {
                var instance = this;

                return function (event) {
                    var time = instance.audioContext.currentTime - instance.audioSourceNode.lastPlay,
                        duration = instance.audioSourceNode.buffer.duration;

                    if (time >= duration) {
                        instance.progress = 1;
                        instance.$timeout(function () {
                            var prevUrl = instance.url;

                            instance.stop();

                            if (instance.playLoop) {
                                instance.play(prevUrl);
                            }
                        });
                    } else {
                        instance.progress = Math.floor((time / duration) * instance.soundSeekPrecision) / instance.soundSeekPrecision;
                    }

                    handler && handler(instance.progress);
                }
            };

            SoundContructor.prototype.init = function (buffer, callback) {
                this.audioSourceNode = this.audioContext.createBufferSource();
                this.audioSourceNode.playbackRate.value = 1;
                this.audioSourceNode.buffer = buffer;

                this.audioScriptNode = this.audioContext.createScriptProcessor(256);
                this.audioScriptNode.onaudioprocess = this.createAudioProcessHandler(callback);

                this.audioSourceNode.connect(this.audioContext.destination);
                this.audioScriptNode.connect(this.audioContext.destination);
            };

            SoundContructor.prototype.play = function (url, callback) {
                if (url) {
                    url = (window.APP_PROJECT_PATH || "") + url;
                } else {
                    url = this.url;
                }

                if (!this.offlineAudioContext) {
                    this.offlineAudioContext = new (
                        window.OfflineAudioContext || window.webkitOfflineAudioContext
                    )(1, 2, 44100);
                }

                if (!this.audioContext) {
                    this.audioContext = new (
                        window.AudioContext || window.webkitAudioContext
                    );
                }

                if (this.playState === this.PLAYING_STATE) {
                    if (this.url === url) {
                        return this.utilService.getResolveDefer();
                    }
                }

                if (this.url !== url) {
                    this.stop();

                    this.url = url;
                    this.playDefer = this.$q.defer();
                    this.progress = 0;
                    var instance = this;
                    instance.playState = instance.PLAYING_STATE;
                    instance.$http({url: url, method: "GET", responseType: "arraybuffer"}).then(
                        function (result) {
                            if (instance.playState == instance.PLAYING_STATE) {
                                instance.offlineAudioContext.decodeAudioData(result.data, function (buffer) {
                                    instance.init(buffer, callback);
                                    instance.audioSourceNode.start(0, 0);
                                    instance.audioSourceNode.lastPlay = instance.audioContext.currentTime;
                                });
                            }
                        },
                        function (err) {
                            instance.playState = instance.PAUSED_STATE;
                            instance.$exceptionHandler(err);
                            instance.playDefer.reject(err);
                            instance.playDefer = null;
                        }
                    );
                } else {
                    this.playDefer = this.$q.defer();
                    this.audioSourceNode.start(0, this.audioSourceNode.buffer.duration * this.progress);
                    this.playState = this.PLAYING_STATE;
                }

                return this.playDefer.promise;
            };

            SoundContructor.prototype.pause = function () {
                if (this.playState === this.PLAYING_STATE) {
                    if (this.audioSourceNode) {
                        this.audioSourceNode.stop(0);
                        this.playState = this.PAUSED_STATE;
                    }

                    if (this.playDefer) {
                        this.playDefer.resolve(this.progress);
                        this.playDefer = null;
                    }
                }
            };

            SoundContructor.prototype.stop = function () {
                if (this.audioSourceNode) {
                    this.audioSourceNode.stop(0);
                    this.audioSourceNode.disconnect();
                    this.audioSourceNode = null;
                }
                if (this.audioScriptNode) {
                    this.audioScriptNode.disconnect();
                    this.audioScriptNode.onaudioprocess = null;
                    this.audioScriptNode = null;
                }
                if (this.playDefer) {
                    this.playDefer.resolve(this.progress);
                    this.playDefer = null;
                }
                this.playState = this.FINISHED_STATE;
                this.progress = 0;
                this.url = null;
            };

            SoundContructor.prototype.isPlaying = function () {
                return this.playState === this.PLAYING_STATE;
            };

            appService.prototype.registerService = function () {
                this.serviceRegistry && this.serviceRegistry.register(this, FEATURE, PLATFORM);
            };

            appService.prototype.unregisterService = function () {
                this.serviceRegistry && this.serviceRegistry.unregister(FEATURE, PLATFORM);
            };

            appService.prototype.callService = function (feature, serviceName, args) {
                if (serviceName !== "callService") {
                    var fn = this.serviceRegistry.invoke(feature, serviceName);
                    return fn.apply(null, args || []);
                } else {
                    return this.utilService.getRejectDefer("Cannot call self.");
                }
            }

            appService.prototype.loadRepoArtifact = function (repoArtifact, repoLibId, repoLibName, version, demoSelector) {
                version = version || repoArtifact.versionList[repoArtifact.versionList.length - 1].name;

                var self = this,
                    defer = self.$q.defer(),
                    loadedSpec = {
                        name: repoArtifact.name,
                        artifactId: repoArtifact._id,
                        libraryId: repoLibId,
                        libraryName: repoLibName,
                        version: version,
                        type: repoArtifact.type,
                        projectId: self.$rootScope.loadedProject && self.$rootScope.loadedProject.projectRecord && self.$rootScope.loadedProject.projectRecord._id || ""
                    },
                    repoUrl = "repo/{0}/{1}/{2}/{3}".format(
                        repoArtifact.type,
                        repoLibName,
                        repoArtifact._id,
                        version);

                require(["{0}/main".format(repoUrl)],
                    function (artifact) {
                        function requireArtifact(artifact) {
                            artifact.stylesheets && artifact.stylesheets.forEach(function (href) {
                                var link = document.createElement("link");

                                link.type = "text/css";
                                link.rel = "stylesheet";
                                link.href = "{0}/{1}".format(repoUrl, href);
                                link.setAttribute("artifact", repoArtifact._id);

                                document.getElementsByTagName("head")[0].appendChild(link);

                                (loadedSpec.stylesheets = loadedSpec.stylesheets || []).push(link.href);
                            });

                            if (artifact.template)
                                loadedSpec.template = "{0}/{1}".format(repoUrl, artifact.template);

                            if (artifact.directiveName)
                                repoArtifact.directiveName = artifact.directiveName;

                            loadedSpec.configuration = artifact.configuration;

                            var jsArr = [],
                                qArr = [];

                            if (artifact.json) {
                                loadedSpec.json = "{0}/{1}".format(repoUrl, artifact.json);

                                qArr.push(self.$http.get("{0}/{1}".format(repoUrl, artifact.json)).then(
                                    function (result) {
                                        var jsonDefer = self.$q.defer();

                                        repoArtifact.json = result.data;
                                        self.$timeout(function () {
                                            jsonDefer.resolve();
                                        });

                                        return jsonDefer.promise;
                                    }, function () {
                                        var errDefer = self.$q.defer();

                                        self.$timeout(function () {
                                            errDefer.reject();
                                        });

                                        return errDefer.promise;
                                    }
                                ));
                            }

                            artifact.js && artifact.js.forEach(function (src) {
                                var requireUrl = "{0}/{1}".format(repoUrl, src);
                                (loadedSpec.js = loadedSpec.js || []).push(requireUrl);

                                if (!requirejs.defined(requireUrl)) {
                                    jsArr.push(requireUrl);
                                }
                            });
                            if (jsArr.length) {
                                qArr.push((function () {
                                    var jsDefer = self.$q.defer();

                                    jsArr.splice(0, 0, "app-extension") && requirejs(jsArr, function () {
                                        var args = Array.prototype.slice.apply(arguments),
                                            configs = Array.prototype.slice.call(args, 1),
                                            extension = args[0];

                                        configs.forEach(function (config) {
                                            config && config(self.$injector, self.$compileProvider, self.$controllerProvider, extension, repoUrl);
                                        });

                                        jsDefer.resolve();
                                    });

                                    return jsDefer.promise;
                                })());
                            }

                            return self.$q.all(qArr).then(
                                function () {
                                    var artifactDefer = self.$q.defer();

                                    self.$timeout(function () {
                                        artifactDefer.resolve(loadedSpec);
                                    });

                                    return artifactDefer.promise;

                                }, function () {
                                    var errDefer = self.$q.defer();

                                    self.$timeout(function () {
                                        errDefer.reject();
                                    });

                                    return errDefer.promise;
                                }
                            );
                        }

                        function requireDemo(artifact, loadedSpec) {
                            var demoSpec = artifact.demo,
                                demoDefer = self.$q.defer();

                            if (demoSpec && demoSpec.url && demoSelector) {
                                loadedSpec.demo = {};

                                demoSpec.stylesheets && demoSpec.stylesheets.forEach(function (href) {
                                    var link = document.createElement("link");
                                    link.type = "text/css";
                                    link.rel = "stylesheet";
                                    link.href = "{0}/{1}".format(repoUrl, href);
                                    link.setAttribute("artifact", repoArtifact._id);

                                    document.getElementsByTagName("head")[0].appendChild(link);

                                    (loadedSpec.demo.stylesheets = loadedSpec.demo.stylesheets || []).push(link.href);
                                });

                                var jsArr = [],
                                    demoRequireDefer = self.$q.defer();

                                demoSpec.js && demoSpec.js.forEach(function (src) {
                                    jsArr.push("{0}/{1}".format(repoUrl, src));

                                    (loadedSpec.demo.js = loadedSpec.demo.js || []).push("{0}/{1}".format(repoUrl, src));
                                });
                                if (jsArr.length) {
                                    jsArr.splice(0, 0, "app-extension") && requirejs(jsArr, function () {
                                        var configs = Array.prototype.slice.call(arguments, 1),
                                            extension = arguments[0];

                                        configs.forEach(function (config) {
                                            config && config(self.$injector, self.$compileProvider, self.$controllerProvider, extension, repoUrl);
                                        });

                                        demoRequireDefer.resolve();
                                    })
                                } else {
                                    self.$timeout(function () {
                                        demoRequireDefer.resolve();
                                    });
                                }

                                demoRequireDefer.promise.then(function () {
                                    var $el;
                                    if (typeof demoSelector == "string")
                                        $el = $(demoSelector);
                                    else if (demoSelector && typeof demoSelector === "object")
                                        $el = demoSelector.jquery && demoSelector || $(demoSelector);

                                    if ($el) {
                                        $el.empty();
                                        $el.attr("ng-include", "'{0}/{1}'".format(repoUrl, demoSpec.url));
                                        var scope = angular.element($el.parent()).scope();
                                        self.$compile($el.parent())(scope);
                                    }

                                    demoDefer.resolve(loadedSpec);
                                });
                            } else {
                                self.$timeout(function () {
                                    demoDefer.resolve(loadedSpec);
                                });
                            }

                            return demoDefer.promise;
                        }

                        $("head link[type='text/css'][artifact={0}]".format(repoArtifact._id)).remove();
                        requireArtifact(artifact).then(
                            function (loadedSpec) {
                                return requireDemo(artifact, loadedSpec);
                            }, function () {
                                defer.reject();
                            }
                        ).then(
                            function (loadedSpec) {
                                defer.resolve(loadedSpec);
                            }, function () {
                                defer.reject();
                            }
                        );
                    }
                );

                return defer.promise;
            };

            appService.prototype.loadArtifactList = function (type) {
                var self = this,
                    listName = type + "LibraryList",
                    artifactLibraryList = self.$rootScope[listName] || [],
                    libraryFilter = {type: type};
                self.$rootScope[listName] = artifactLibraryList;

                if (artifactLibraryList.length) {
                    var updateTime = _.max(artifactLibraryList, function (library) {
                        return library.updateTime;
                    });
                    libraryFilter.updateTime = {$gte: updateTime};
                }

                return self.getRepoLibrary(libraryFilter).then(
                    function (result) {
                        var libraryList = result.data.result == "OK" && result.data.resultValue || [],
                            reloadCount = 0,
                            defer = self.$q.defer();

                        //Update already loaded library, append recent library
                        artifactLibraryList.forEach(function (loadedLibrary) {
                            var index;
                            if (!libraryList.every(function (library, i) {
                                    if (library._id === loadedLibrary._id) {
                                        index = i;
                                        return false;
                                    }

                                    return true;
                                })) {
                                _.extend(loadedLibrary, libraryList[index]);
                                libraryList.splice(index, 1);
                                reloadCount++;
                                libraryList.splice(0, 0, loadedLibrary);
                            }
                        });
                        if (libraryList.length > reloadCount) {
                            var recentLoadedList = libraryList.slice(reloadCount, libraryList.length - reloadCount);
                            recentLoadedList.splice(0, 0, artifactLibraryList.length, 0);
                            Array.prototype.splice.apply(artifactLibraryList, recentLoadedList);
                        }

                        //Load each library's artifacts
                        var promiseArr = [];
                        libraryList.forEach(function (library) {
                            var artifactFilter = {library: library._id};
                            if (library.artifactList && library.artifactList.length) {
                                var updateTime = _.max(library.artifactList, function (artifact) {
                                    return artifact.updateTime;
                                });

                                artifactFilter.updateTime = {$gte: updateTime};
                            }

                            promiseArr.push(self.getRepoArtifact(artifactFilter));
                        });
                        promiseArr.length && self.$q.all(promiseArr).then(
                            function (result) {
                                var artifactArr = [];

                                for (var i = 0; i < reloadCount; i++) {
                                    var artifactList = result[i].data.result == "OK" && result[i].data.resultValue || [],
                                        recentArtifactList = [];
                                    artifactList.forEach(function (artifact) {
                                        artifactArr.push({
                                            artifact: artifact,
                                            libraryId: libraryList[i]._id,
                                            libraryName: libraryList[i].name
                                        });

                                        if ((libraryList[i].artifactList = libraryList[i].artifactList || []).every(function (loadedArtifact) {
                                                if (artifact._id === loadedArtifact._id) {
                                                    _.extend(loadedArtifact, artifact);
                                                    return false;
                                                }

                                                return true;
                                            })) {
                                            recentArtifactList.push(artifact);
                                        }
                                    });

                                    if (recentArtifactList.length) {
                                        recentArtifactList.splice(0, 0, libraryList[i].artifactList.length, 0);
                                        Array.prototype.apply(libraryList[i].artifactList, recentArtifactList);
                                    }
                                }
                                for (var i = reloadCount; i < result.length; i++) {
                                    libraryList[i].artifactList = result[i].data.result == "OK" && result[i].data.resultValue || [];

                                    libraryList[i].artifactList.forEach(function (artifact) {
                                        artifactArr.push({
                                            artifact: artifact,
                                            libraryId: libraryList[i]._id,
                                            libraryName: libraryList[i].name
                                        });
                                    });
                                }

                                defer.resolve(artifactArr);
                            }, function () {
                                defer.reject();
                            }
                        ) || self.$timeout(function () {
                            defer.resolve();
                        });

                        return defer.promise;
                    },
                    function (err) {
                        var errorDefer = self.$q.defer();

                        self.$timeout(function () {
                            errorDefer.reject(err);
                        });

                        return errorDefer.promise;
                    }
                );
            };

            appService.prototype.loadEffectArtifactList = function () {
                var self = this;

                return this.loadArtifactList("effect").then(function (artifactArr) {
                        //Load each artifact's stylesheets
                        var promiseArr = [];
                        artifactArr && artifactArr.forEach(function (artifactObj) {
                            promiseArr.push(self.loadRepoArtifact(artifactObj.artifact, artifactObj.libraryId, artifactObj.libraryName));
                        });


                        return promiseArr.length && self.$q.all(promiseArr) || self.utilService.getResolveDefer();
                    },
                    function (err) {
                        return self.utilService.getRejectDefer(err);
                    }
                );
            };

            appService.prototype.loadIconArtifactList = function () {
                var self = this;

                return this.loadArtifactList("icon").then(function (artifactArr) {
                        //Load each artifact's stylesheets
                        var promiseArr = [];
                        artifactArr && artifactArr.forEach(function (artifactObj) {
                            promiseArr.push(self.loadRepoArtifact(artifactObj.artifact, artifactObj.libraryId, artifactObj.libraryName));
                        });

                        return promiseArr.length && self.$q.all(promiseArr) || self.utilService.getResolveDefer();
                    },
                    function (err) {
                        return self.utilService.getRejectDefer(err);
                    }
                );
            };

            appService.prototype.loadWidgetArtifactList = function () {
                return this.loadArtifactList("widget");
            };

            appService.prototype.addConfigurableArtifact = function (projectId, widgetId, libraryName, artifactId, type, version) {
                var self = this;

                return self.$http({
                    method: 'POST',
                    url: '/api/public/configurableArtifact',
                    params: {
                        projectId: projectId,
                        widgetId: widgetId,
                        libraryName: libraryName,
                        artifactId: artifactId,
                        type: type,
                        version: version
                    }
                }).then(function (result) {
                    var defer = self.$q.defer();

                    if (result.data.result === "OK") {
                        $("head link[type='text/css'][widget='{0}']".format(widgetId)).remove();

                        self.$timeout(function () {
                            var link = document.createElement("link");
                            link.type = "text/css";
                            link.rel = "stylesheet";
                            link.href = "project/{0}/stylesheets/{1}".format(projectId, result.data.resultValue.css);
                            link.setAttribute("artifact", artifactId);
                            link.setAttribute("widget", widgetId);
                            link.setAttribute("projectId", projectId);

                            document.getElementsByTagName("head")[0].appendChild(link);

                            defer.resolve();
                        });
                    } else {
                        self.$timeout(function () {
                            defer.reject(result.data.reason);
                        });
                    }

                    return defer.promise;
                }, function (err) {
                    var errDefer = self.$q.defer();

                    self.$timeout(function () {
                        errDefer.reject(err);
                    });

                    return errDefer.promise;
                });
            };

            appService.prototype.updateConfigurableArtifact = function (projectId, widgetId, artifactId, configurationArray) {
                var self = this,
                    configuration = {};

                _.each(configurationArray, function (obj) {
                    configuration[obj.key] = obj.value;
                });

                return self.$http({
                    method: 'PUT',
                    url: '/api/public/configurableArtifact',
                    params: {
                        projectId: projectId,
                        widgetId: widgetId,
                        artifactId: artifactId,
                        configuration: JSON.stringify(configuration)
                    }
                }).then(function (result) {
                    if (result.data.result === "OK") {
                        $("head link[type='text/css'][widget='{0}']".format(widgetId)).remove();

                        return self.$timeout(function () {
                            var link = document.createElement("link");
                            link.type = "text/css";
                            link.rel = "stylesheet";
                            link.href = "project/{0}/stylesheets/{1}".format(projectId, result.data.resultValue.css);
                            link.setAttribute("artifact", artifactId);
                            link.setAttribute("widget", widgetId);

                            document.getElementsByTagName("head")[0].appendChild(link);
                        });
                    } else {
                        return self.utilService.getRejectDefer(result.data.reason);
                    }
                }, function (err) {
                    return self.utilService.getRejectDefer(err);
                });
            };

            //FIXME Cache sketch to cookies

            appService.prototype.saveSketch = function (projectId, sketchWorks, stagingContent) {
                return this.$http({
                    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                    method: 'POST',
                    url: '/api/public/sketch',
                    data: $.param({
                        projectId: projectId,
                        sketchWorks: JSON.stringify(sketchWorks),
                        stagingContent: JSON.stringify(stagingContent)
                    })
                });
            };

            appService.prototype.loadSketch = function (projectId) {
                var self = this;

                return self.$http({
                    method: 'GET',
                    url: '/api/public/sketch',
                    params: {projectId: projectId}
                }).then(function (result) {
                        if (result.data.result === "OK") {
                            var resultValue = JSON.parse(result.data.resultValue);
                            return self.utilService.getResolveDefer(resultValue);
                        } else {
                            return self.utilService.getRejectDefer(result.data.reason);
                        }
                    },
                    function (err) {
                        return self.utilService.getRejectDefer(err);
                    }
                );
            };

            appService.prototype.loadExternal = function (projectId) {
                var self = this;

                return self.$http({
                    method: 'GET',
                    url: '/api/public/external',
                    params: {projectId: projectId}
                }).then(function (result) {
                        if (result.data.result === "OK") {
                            var resultValue = JSON.parse(result.data.resultValue);
                            return self.utilService.getResolveDefer(resultValue);
                        } else {
                            return self.utilService.getRejectDefer(result.data.reason);
                        }
                    },
                    function (err) {
                        return self.utilService.getRejectDefer(err);
                    }
                );
            };

            appService.prototype.saveFlow = function (projectId, flowWorks) {
                return this.$http({
                    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                    method: 'POST',
                    url: '/api/public/flow',
                    data: $.param({
                        projectId: projectId,
                        flowWorks: JSON.stringify(flowWorks)
                    })
                });
            };

            appService.prototype.loadFlow = function (projectId) {
                var self = this;

                return self.$http({
                    method: 'GET',
                    url: '/api/public/flow',
                    params: {projectId: projectId}
                }).then(function (result) {
                        if (result.data.result === "OK") {
                            var resultValue = JSON.parse(result.data.resultValue);
                            return self.utilService.getResolveDefer(resultValue);
                        } else {
                            return self.utilService.getRejectDefer(result.data.reason);
                        }
                    },
                    function (err) {
                        return self.utilService.getRejectDefer(err);
                    }
                );
            };

            appService.prototype.lockProject = function (userId, projectId) {
                var self = this;

                return self.$http({
                    method: 'PUT',
                    url: '/api/public/project',
                    params: {projectFilter: {_id: projectId, lock: false}, project: {lock: true, lockUser: userId}}
                }).then(
                    function (result) {
                        if (result.data.result === "OK") {
                            if (result.data.resultValue > 0) {
                                return self.utilService.getResolveDefer();
                            } else {
                                return self.utilService.getRejectDefer();
                            }
                        } else {
                            return self.utilService.getRejectDefer(result.data.reason);
                        }
                    },
                    function (err) {
                        return self.utilService.getRejectDefer(err);
                    }
                );
            };

            appService.prototype.unlockProject = function (userId, projectId) {
                var self = this;

                return self.$http({
                    method: 'PUT',
                    url: '/api/public/project',
                    params: {projectFilter: {_id: projectId, lockUser: userId}, project: {lock: false, lockUser: null}}
                }).then(
                    function (result) {
                        if (result.data.result === "OK") {
                            if (result.data.resultValue > 0) {
                                return self.utilService.getResolveDefer();
                            } else {
                                return self.utilService.getRejectDefer();
                            }
                        } else {
                            return self.utilService.getRejectDefer(result.data.reason);
                        }
                    },
                    function (err) {
                        return self.utilService.getRejectDefer(err);
                    }
                )
            };

            appService.prototype.removeProjectImage = function (projectId, fileName) {
                fileName = fileName.replace(/(.+\/)?([^\/]+)$/, "$2");
                return this.$http({
                    method: 'DELETE',
                    url: '/api/public/projectImage',
                    params: {projectId: projectId, fileName: fileName}
                });
            };

            appService.prototype.getRepoLibrary = function (libraryFilter) {
                return this.$http({
                    method: 'GET',
                    url: '/api/public/repoLibrary',
                    params: {libraryFilter: JSON.stringify(libraryFilter || {})}
                });

            };

            appService.prototype.getRepoArtifact = function (artifactFilter) {
                return this.$http({
                    method: 'GET',
                    url: '/api/public/repoArtifact',
                    params: {artifactFilter: JSON.stringify(artifactFilter || {})}
                });

            };

            appService.prototype.getProjectResource = function (projectId) {
                return this.$http({
                    method: 'GET',
                    url: '/api/public/projectResource',
                    params: {projectId: projectId}
                });

            };

            appService.prototype.deleteProjectResource = function (projectId, resourceType, fileName) {
                return this.$http({
                    method: 'DELETE',
                    url: '/api/public/projectResource',
                    params: {projectId: projectId, resourceType: resourceType, fileName: fileName}
                });

            };

            appService.prototype.getProjectDependency = function (xrefFilter) {
                return this.$http({
                    method: 'GET',
                    url: '/api/public/projectArtifactXref',
                    params: {xrefFilter: JSON.stringify(xrefFilter || {})}
                });

            };

            appService.prototype.updateProjectDependency = function (projectId, libraryId, artifactList) {
                return this.$http({
                    method: 'POST',
                    url: '/api/public/projectArtifactXref',
                    params: {
                        projectId: projectId,
                        libraryId: libraryId,
                        artifactList: JSON.stringify(artifactList || [])
                    }
                });

            };

            appService.prototype.deleteProjectDependency = function (xrefFilter) {
                return this.$http({
                    method: 'DELETE',
                    url: '/api/public/projectArtifactXref',
                    params: {xrefFilter: JSON.stringify(xrefFilter || {})}
                });
            };

            appService.prototype.createProject = function (project, sketchWorks) {
                var self = this;

                return this.$http({
                    method: 'POST',
                    url: '/api/public/project',
                    params: {
                        project: JSON.stringify(_.omit(project, "$$hashKey", "artifactList")),
                        sketchWorks: JSON.stringify(sketchWorks)
                    }
                }).then(
                    function (result) {
                        if (result.data.result === "OK") {
                            return self.utilService.getResolveDefer(result.data.resultValue);
                        } else {
                            return self.utilService.getRejectDefer(result.data.reason);
                        }
                    },
                    function (err) {
                        return self.utilService.getRejectDefer(err);
                    }
                )

            };

            appService.prototype.modifyProject = function (project) {
                var self = this;

                return self.$http({
                    method: 'PUT',
                    url: '/api/public/project',
                    params: {
                        projectFilter: JSON.stringify({_id: project._id}),
                        project: JSON.stringify(_.omit(project, "$$hashKey", "artifactList"))
                    }
                }).then(
                    function (result) {
                        if (result.data.result === "OK") {
                            return self.utilService.getResolveDefer();
                        } else {
                            return self.utilService.getRejectDefer(result.data.reason);
                        }
                    },
                    function (err) {
                        return self.utilService.getRejectDefer(err);
                    }
                )

            };

            appService.prototype.deleteProject = function (userId, project) {
                var self = this;

                return self.$http({
                    method: 'DELETE',
                    url: '/api/public/project',
                    params: {projectFilter: JSON.stringify({userId: userId, _id: project._id})}
                }).then(
                    function (result) {
                        if (result.data.result === "OK") {
                            return self.utilService.getResolveDefer();
                        } else {
                            return self.utilService.getRejectDefer(result.data.reason);
                        }
                    },
                    function (err) {
                        return self.utilService.getRejectDefer(err);
                    }
                )
            };

            appService.prototype.convertToHtml = function (userId, projectId) {
                var self = this;

                return self.$http({
                    method: 'POST',
                    url: '/api/public/convertToHtml',
                    params: {userId: userId, projectId: projectId}
                }).then(
                    function (result) {
                        if (result.data.result === "OK") {
                            return self.utilService.getResolveDefer();
                        } else {
                            return self.utilService.getRejectDefer(result.data.reason);
                        }
                    },
                    function (err) {
                        return self.utilService.getRejectDefer(err);
                    }
                )
            };

            appService.prototype.validateUrl = function (url) {
                var self = this;

                return self.$http.get(url).then(
                    function () {
                        return self.utilService.getResolveDefer();
                    }, function (err) {
                        return self.utilService.getRejectDefer(err);
                    }
                )
            };

            /* Services managed by registry are visible to designer, serving generated app. */
            function findPageElement(location) {
                var widgetId = parseWidgetId(location),
                    $container = $("#main"),
                    $page = $container.children("#" + widgetId);

                return $page.length && $page || $("<div ui-include-replace></div>").attr("ng-include", "'" + location + "'");
            }

            function setCurrentPage($page) {
                var $container = $("#main"),
                    $current = $container.children(".pageHolder.currentPage");

                if ($page.attr("id") != $current.attr("id")) {
                    $current.removeClass("currentPage");
                    $page.addClass('currentPage');
                }
            }

            appService.prototype.refreshUser = function (loginName) {
                var self = this;

                return self.$http({
                    method: 'get',
                    url: (window.serverUrl || '') + '/api/private/user',
                    params: {
                        userFilter: JSON.stringify({loginName: loginName})
                    }
                }).then(function (result) {
                    var defer = self.$q.defer(),
                        userObj = result.data && result.data.resultValue && result.data.resultValue.length && result.data.resultValue[0];

                    self.$timeout(function () {
                        if (userObj) {
                            localStorage.loginUser = JSON.stringify(userObj);
                            self.$rootScope.loginUser = self.$rootScope.loginUser || {};
                            for (var key in self.$rootScope.loginUser) {
                                delete self.$rootScope.loginUser[key];
                            }

                            _.extend(self.$rootScope.loginUser, userObj);

                            defer.resolve(userObj);
                        } else {
                            defer.reject("User object not returned.");
                        }
                    });

                    return defer.promise;
                }, function (err) {
                    return self.utilService.getRejectDefer(err);
                });
            };

            appService.prototype.doLogin = function (loginName, password) {
                var self = this,
                    encoded = self.utilService.encode(loginName + ':' + password);

                this.$http.defaults.headers.common.Authorization = 'Basic ' + encoded;

                return self.refreshUser(loginName);
            };

            appService.prototype.doLogout = function () {
                var self = this,
                    defer = self.$q.defer();

                self.$timeout(function () {
                    delete localStorage.loginUser;

                    for (var key in self.$rootScope.loginUser) {
                        delete self.$rootScope.loginUser[key];
                    }
                    self.$cookieStore.remove("connect.sid");
                    self.$http.defaults.headers.common.Authorization = "";

                    defer.resolve();
                });

                return defer.promise;
            };

            appService.prototype.restoreUserFromStorage = function () {
                var self = this,
                    defer = self.$q.defer();

                self.$timeout(
                    function () {
                        var sid = self.$cookies["connect.sid"];

                        !sid && delete localStorage.loginUser;

                        self.$rootScope.loginUser = self.$rootScope.loginUser || {};

                        var userObj = eval("(" + localStorage.loginUser + ")");

                        for (var key in self.$rootScope.loginUser) {
                            delete self.$rootScope.loginUser[key];
                        }

                        _.extend(self.$rootScope.loginUser, userObj);

                        defer.resolve(userObj);
                    }
                );

                return defer.promise;
            };

            appService.prototype.getUserDetail = function (userFilter) {
                return this.$http({
                    method: 'GET',
                    url: (window.serverUrl || '') + '/api/private/userDetail',
                    params: {userFilter: JSON.stringify(userFilter || {})}
                });

            };

            appService.prototype.getProject = function (projectFilter) {
                return this.$http({
                    method: 'GET',
                    url: (window.serverUrl || '') + '/api/public/project',
                    params: {projectFilter: JSON.stringify(projectFilter || {})}
                });

            };

            appService.prototype.nextPage = function () {
                var self = this,
                    locationIndex,
                    location = self.$rootScope.pickedPage;

                self.pageMeta.locations.every(function (loc, i) {
                    if (loc === location) {
                        locationIndex = i;
                        return false;
                    }

                    return true;
                });

                if (locationIndex < self.pageMeta.locations.length - 1) {
                    //Some pages' display is controlled by the creator. Only when he send the topic invitation, can the 
                    //audience see the page.
                    if (window.pomeloContext && self.$rootScope.loginUser && window.pomeloContext.userId !== self.$rootScope.loginUser._id) {
                        if (self.pageMeta.displayControlLocations && self.pageMeta.displayControlLocations.length) {
                            var i = locationIndex + 1;
                            for(;i < self.pageMeta.locations.length;i++) {
                                if (_.indexOf(self.pageMeta.displayControlLocations, self.pageMeta.locations[i]) < 0) {
                                    break;
                                }
                            }
                            if (i < self.pageMeta.locations.length) {
                                locationIndex = i - 1;
                            } else {
                                return self.utilService.getResolveDefer(location);
                            }                            
                        }
                    }

                    return self.loadPage(self.pageMeta.locations[locationIndex + 1]).then(
                        function () {
                            var $current = findPageElement(location),
                                $next = findPageElement(self.pageMeta.locations[locationIndex + 1]),
                                hasAnimation = false,
                                fullName;

                            $current.addClass("forward");

                            if (!_.isEmpty(self.pageMeta.pageTransition)) {
                                hasAnimation = self.pageMeta.pageTransition.effect.type === "Animation";

                                fullName = self.pageMeta.pageTransition.artifactSpec.directiveName;
                                if (self.pageMeta.pageTransition.artifactSpec.version) {
                                    fullName = fullName + "-" + self.pageMeta.pageTransition.artifactSpec.version.replace(/\./g, "-")
                                }

                                $current.attr(fullName, "");
                                $current.attr("effect", self.pageMeta.pageTransition.effect.name);
                            }

                            if (hasAnimation) {
                                $next.css("visibility", "visible");

                                return self.$q.all([
                                    self.utilService.onAnimationEnd($current),
                                    self.utilService.onAnimationEnd($next)
                                ]).then(function () {
                                    $current.removeClass("forward");
                                    $current.removeAttr("effect");
                                    fullName && $current.removeAttr(fullName);
                                    $next.css("visibility", "");
                                    setCurrentPage($next);
                                    self.$rootScope.pickedPage = self.pageMeta.locations[locationIndex + 1];

                                    return self.setState(self.$rootScope.pickedPage.replace("page-", ""), "*").then(function () {
                                        return self.utilService.getResolveDefer(location);
                                    });
                                });
                            } else {
                                return self.$timeout(function () {
                                    $current.removeClass("forward");
                                    $current.removeAttr("effect");
                                    fullName && $current.removeAttr(fullName);
                                    setCurrentPage($next);
                                    self.$rootScope.pickedPage = self.pageMeta.locations[locationIndex + 1];

                                    return self.setState(self.$rootScope.pickedPage.replace("page-", ""), "*").then(function () {
                                        return self.utilService.getResolveDefer(location);
                                    });
                                });
                            }
                        },
                        function (err) {
                            return self.utilService.getRejectDefer(err);
                        }
                    );
                }

                return self.utilService.getResolveDefer(location);
            };

            appService.prototype.prevPage = function () {
                var self = this,
                    locationIndex,
                    location = self.$rootScope.pickedPage;

                self.pageMeta.locations.every(function (loc, i) {
                    if (loc === location) {
                        locationIndex = i;
                        return false;
                    }

                    return true;
                });

                if (locationIndex > 0) {
                    //Some pages' display is controlled by the creator. Only when he send the topic invitation, can the 
                    //audience see the page.
                    if (window.pomeloContext && self.$rootScope.loginUser && window.pomeloContext.userId !== self.$rootScope.loginUser._id) {
                        if (self.pageMeta.displayControlLocations && self.pageMeta.displayControlLocations.length) {
                            var i = locationIndex - 1;
                            for(;i >= 0;i--) {
                                if (_.indexOf(self.pageMeta.displayControlLocations, self.pageMeta.locations[i]) < 0) {
                                    break;
                                }
                            }
                            if (i >= 0) {
                                locationIndex = i + 1;
                            } else {
                                return self.utilService.getResolveDefer(location);
                            }                            
                        }
                    }

                    return self.loadPage(self.pageMeta.locations[locationIndex - 1]).then(
                        function () {
                            var $current = findPageElement(location),
                                $prev = findPageElement(self.pageMeta.locations[locationIndex - 1]),
                                hasAnimation = false,
                                fullName;

                            $prev.addClass("backward previousPage");

                            if (!_.isEmpty(self.pageMeta.pageTransition)) {
                                hasAnimation = self.pageMeta.pageTransition.effect.type === "Animation";

                                fullName = self.pageMeta.pageTransition.artifactSpec.directiveName;
                                if (self.pageMeta.pageTransition.artifactSpec.version) {
                                    fullName = fullName + "-" + self.pageMeta.pageTransition.artifactSpec.version.replace(/\./g, "-")
                                }

                                $prev.attr(fullName, "");
                                $prev.attr("effect", self.pageMeta.pageTransition.effect.name);
                            }

                            if (hasAnimation) {
                                $prev.css("visibility", "visible");

                                return self.$q.all([
                                    self.utilService.onAnimationEnd($current),
                                    self.utilService.onAnimationEnd($prev)
                                ]).then(function () {
                                    $prev.removeClass("backward previousPage");
                                    $prev.removeAttr("effect");
                                    fullName && $prev.removeAttr(fullName);
                                    $prev.css("visibility", "");
                                    setCurrentPage($prev);
                                    self.$rootScope.pickedPage = self.pageMeta.locations[locationIndex - 1];

                                    return self.setState(self.$rootScope.pickedPage.replace("page-", ""), "*").then(function () {
                                        return self.utilService.getResolveDefer(location);
                                    });
                                });
                            } else {
                                return self.$timeout(function () {
                                    $prev.removeClass("backward previousPage");
                                    $prev.removeAttr("effect");
                                    fullName && $prev.removeAttr(fullName);
                                    setCurrentPage($prev);
                                    self.$rootScope.pickedPage = self.pageMeta.locations[locationIndex - 1];

                                    return self.setState(self.$rootScope.pickedPage.replace("page-", ""), "*").then(function () {
                                        return self.utilService.getResolveDefer(location);
                                    });
                                });
                            }
                        },
                        function (err) {
                            return self.utilService.getRejectDefer(err);
                        }
                    );
                }

                return self.utilService.getResolveDefer(location);
            };

            appService.prototype.gotoPage = function (pageNum, isInvited) {
                var self = this,
                    locationIndex,
                    $container = $("#main"),
                    currentLocation = self.$rootScope.pickedPage;

                self.pageMeta.locations.every(function (loc, i) {
                    if (loc === currentLocation) {
                        locationIndex = i;
                        return false;
                    }

                    return true;
                });

                if (typeof pageNum === "string") {
                    var pageLoc = pageNum;
                    pageNum = null;
                    self.pageMeta.locations.every(function (loc, i) {
                        if (loc === pageLoc) {
                            pageNum = i;
                            return false;
                        }

                        return true;
                    });
                }

                if (pageNum < self.pageMeta.locations.length && locationIndex !== pageNum) {
                    var gotoLocation = self.pageMeta.locations[pageNum];

                    //Some pages' display is controlled by the creator. Only when he send the topic invitation, can the 
                    //audience see the page.
                    if (window.pomeloContext && self.$rootScope.loginUser && window.pomeloContext.userId !== self.$rootScope.loginUser._id) {
                        if (self.pageMeta.displayControlLocations && self.pageMeta.displayControlLocations.length) {
                            if (_.indexOf(self.pageMeta.displayControlLocations, gotoLocation) >= 0) {
                                if (isInvited != null && !isInvited) {
                                    return self.utilService.getResolveDefer(gotoLocation);
                                }
                            }
                        }
                    }

                    var widgetId = parseWidgetId(gotoLocation),
                        currentWidgetId = parseWidgetId(currentLocation);
                    if (widgetId && currentWidgetId) {
                        var $unloaded = $container.children("." + self.angularConstants.widgetClasses.holderClass + ":not(#" + currentWidgetId + ")" + ":not(#" + widgetId + ")");

                        $unloaded.each(function (i, element) {
                            var scope = angular.element(element).scope();
                            scope && scope.$destroy();
                        });

                        $unloaded.remove();

                        return self.loadPage(gotoLocation).then(function () {
                            var $current = $container.children("#" + currentWidgetId),
                                $goto = findPageElement(gotoLocation),
                                hasAnimation = false,
                                fullName;

                            if (pageNum < locationIndex) {
                                $goto.addClass("backward previousPage");

                                if (!_.isEmpty(self.pageMeta.pageTransition)) {
                                    hasAnimation = self.pageMeta.pageTransition.effect.type === "Animation";

                                    fullName = self.pageMeta.pageTransition.artifactSpec.directiveName;
                                    if (self.pageMeta.pageTransition.artifactSpec.version) {
                                        fullName = fullName + "-" + self.pageMeta.pageTransition.artifactSpec.version.replace(/\./g, "-")
                                    }

                                    $goto.attr(fullName, "");
                                    $goto.attr("effect", self.pageMeta.pageTransition.effect.name);
                                }

                                if (hasAnimation) {
                                    $goto.css("visibility", "visible");

                                    return self.$q.all([
                                        self.utilService.onAnimationEnd($current),
                                        self.utilService.onAnimationEnd($goto)
                                    ]).then(function () {
                                        $goto.removeClass("backward previousPage");
                                        $goto.removeAttr("effect");
                                        fullName && $goto.removeAttr(fullName);
                                        $goto.css("visibility", "");
                                        setCurrentPage($goto);
                                        self.$rootScope.pickedPage = gotoLocation;

                                        return self.setState(gotoLocation.replace("page-", ""), "*").then(function () {
                                            $current.each(function (i, element) {
                                                var scope = angular.element(element).scope();
                                                scope && scope.$destroy();
                                            });

                                            $current.remove();

                                            return self.utilService.getResolveDefer(gotoLocation);
                                        });
                                    });
                                } else {
                                    return self.$timeout(function () {
                                        $goto.removeClass("backward previousPage");
                                        $goto.removeAttr("effect");
                                        fullName && $goto.removeAttr(fullName);
                                        setCurrentPage($goto);
                                        self.$rootScope.pickedPage = gotoLocation;

                                        return self.setState(gotoLocation.replace("page-", ""), "*").then(function () {
                                            $current.each(function (i, element) {
                                                var scope = angular.element(element).scope();
                                                scope && scope.$destroy();
                                            });

                                            $current.remove();

                                            return self.utilService.getResolveDefer(gotoLocation);
                                        });
                                    });
                                }
                            } else {
                                $current.addClass("forward");

                                if (!_.isEmpty(self.pageMeta.pageTransition)) {
                                    hasAnimation = self.pageMeta.pageTransition.effect.type === "Animation";

                                    fullName = self.pageMeta.pageTransition.artifactSpec.directiveName;
                                    if (self.pageMeta.pageTransition.artifactSpec.version) {
                                        fullName = fullName + "-" + self.pageMeta.pageTransition.artifactSpec.version.replace(/\./g, "-")
                                    }

                                    $current.attr(fullName, "");
                                    $current.attr("effect", self.pageMeta.pageTransition.effect.name);
                                }

                                if (hasAnimation) {
                                    $goto.css("visibility", "visible");

                                    return self.$q.all([
                                        self.utilService.onAnimationEnd($current),
                                        self.utilService.onAnimationEnd($goto)
                                    ]).then(function () {
                                        $current.removeClass("forward");
                                        $current.removeAttr("effect");
                                        fullName && $current.removeAttr(fullName);
                                        $goto.css("visibility", "");
                                        setCurrentPage($goto);
                                        self.$rootScope.pickedPage = gotoLocation;

                                        return self.setState(gotoLocation.replace("page-", ""), "*").then(function () {
                                            $current.each(function (i, element) {
                                                var scope = angular.element(element).scope();
                                                scope && scope.$destroy();
                                            });

                                            $current.remove();

                                            return self.utilService.getResolveDefer(gotoLocation);
                                        });
                                    });
                                } else {
                                    return self.$timeout(function () {
                                        $current.removeClass("forward");
                                        $current.removeAttr("effect");
                                        fullName && $current.removeAttr(fullName);
                                        setCurrentPage($goto);
                                        self.$rootScope.pickedPage = gotoLocation;

                                        return self.setState(gotoLocation.replace("page-", ""), "*").then(function () {
                                            $current.each(function (i, element) {
                                                var scope = angular.element(element).scope();
                                                scope && scope.$destroy();
                                            });

                                            $current.remove();

                                            return self.utilService.getResolveDefer(gotoLocation);
                                        });
                                    });
                                }
                            }
                        });
                    }
                }

                return self.utilService.getResolveDefer(location);
            };

            appService.prototype.firstPage = function () {
                return this.gotoPage(0);
            };

            appService.prototype.exitPage = function () {
                var currentLocation = this.$rootScope.pickedPage;

                if (currentLocation !== this.pageMeta.locations[0]) {
                    return this.firstPage();
                }

                return this.utilService.getResolveDefer();
            };

            function parseWidgetId(location) {
                var m = location.match(/[^\/]+$/);

                if (m && m.length) {
                    location = m[0];
                    m = location.match(/[^page-].+$/);
                    if (m && m.length) {
                        return m[0];
                    }
                }

                return null;
            }

            appService.prototype.loadPage = function (location, markCurrent) {
                var self = this,
                    $container = $("#main"),
                    $pages = $container.children("." + self.angularConstants.widgetClasses.holderClass),
                    pageCount = $pages.length,
                    currentLocation = self.$rootScope.pickedPage;

                if (typeof location === "number") {
                    if (location >= 0 && location < self.pageMeta.locations.length) {
                        location = self.pageMeta.locations[location];
                    }
                }

                var widgetId = parseWidgetId(location);
                if (widgetId) {
                    if (!$container.children("#" + widgetId).length) {
                        if (pageCount >= self.angularConstants.maxPageCountInDom) {
                            var $unloaded;

                            if (currentLocation) {
                                var currentWidgetId = parseWidgetId(currentLocation);
                                $unloaded = $container.children("." + self.angularConstants.widgetClasses.holderClass + ":not(#" + currentWidgetId + ")").eq(0);
                            } else {
                                $unloaded = $pages.eq(0);
                            }

                            if ($unloaded && $unloaded.length) {
                                var scope = angular.element($unloaded).scope();
                                $unloaded.remove();
                                scope && scope.$destroy();
                                pageCount--;
                            }
                        }

                        if (pageCount < self.angularConstants.maxPageCountInDom) {
                            var $page = $("<div ui-include-replace></div>").attr("ng-include", "'" + location + ".html'"),
                                $prev,
                                locationIndex;

                            self.pageMeta.locations.every(function (loc, i) {
                                if (loc === location) {
                                    locationIndex = i;
                                    return false;
                                }

                                return true;
                            });
                            if (locationIndex) {
                                var prevLocation, prevWidgetId;

                                do {
                                    prevLocation = self.pageMeta.locations[locationIndex - 1], prevWidgetId = parseWidgetId(prevLocation);
                                    locationIndex--;
                                } while (locationIndex >= 1 && !$container.children("#" + prevWidgetId).length);

                                $prev = $container.children("#" + prevWidgetId);
                            }

                            $prev && $prev.length && $page.insertAfter($prev) || $page.prependTo($container);

                            return self.utilService.timeout(
                                function () {
                                    var defer = self.$q.defer(),
                                        scope = angular.element($container).scope(),
                                        includeWatcher = scope.$on("$includeContentLoaded", function () {
                                            includeWatcher();

                                            if (markCurrent) {
                                                setCurrentPage($container.children("#" + widgetId));
                                                self.$rootScope.pickedPage = location;
                                            }

                                            defer.resolve(location);
                                        });

                                    self.$compile($page)(scope);

                                    return defer.promise;
                                },
                                location,
                                self.angularConstants.loadTimeout
                            );
                        } else {
                            return self.utilService.getRejectDefer("The number of pages in dom exceeds maximum limit.");
                        }
                    } else {
                        var $current = $container.children("#" + widgetId);
                        var scope = angular.element($current).scope();
                        if (scope) {
                            _.each(scope.restoreHandlers, function (handler) {
                                try {
                                    handler && handler();
                                } catch (err) {
                                    self.$exceptionHandler(err);
                                }
                            });
                            scope.restoreHandlers = null;
                        }
                        markCurrent && $current.addClass("currentPage");
                    }
                } else {
                    return self.utilService.getRejectDefer("Invalid widget id value.");
                }

                return self.utilService.getResolveDefer(location);
            };

            appService.prototype.getState = function (id) {
                var defer = self.$q.defer(),
                    widgetName;

                //Accept widget name
                if (!/Widget_\d+$/.test(id)) {
                    widgetName = id;
                    id = null;
                }

                self.utilService.whilst(function () {
                        return widgetName ? !document.getElementsByName(widgetName).length : !document.getElementById(id);
                    },
                    function (err) {
                        if (!err) {
                            var $widgetElement;
                            if (widgetName) {
                                var element = document.getElementsByName(widgetName)[0];
                                $widgetElement = $(element);
                                id = element.id;
                            } else {
                                $widgetElement = $("#" + id);
                            }

                            return defer.resolve($widgetElement.attr("state"));
                        } else {
                            defer.reject(err);
                        }
                    },
                    self.angularConstants.checkInterval,
                    "appService.getState.{0}({1})".format(id || "", widgetName || ""),
                    self.angularConstants.renderTimeout);

                return defer.promise;
            };

            appService.prototype.setState = function (id, state) {
                return this.utilService.setState(id, state);
            };

            appService.prototype.setStateOnWidget = function (id, state) {
                return this.utilService.setStateOnWidget(id, state);
            };

            appService.prototype.isPlayingSound = function () {
                var self = this;

                return self.utilService.getResolveDefer(self.soundDelegate && self.soundDelegate.isPlaying());
            };

            appService.prototype.playSound = function (url, playLoop) {
                var self = this;

                if (!self.soundDelegate) {
                    self.soundDelegate = new SoundContructor();
                }

                self.soundDelegate.playLoop = playLoop;

                return self.soundDelegate.play(url);
            };

            appService.prototype.stopPlaySound = function () {
                this.soundDelegate && this.soundDelegate.stop();

                return this.utilService.getResolveDefer();
            };

            appService.prototype.toggleSound = function (url, playLoop) {
                var self = this;

                return self.isPlayingSound().then(function (isPlaying) {
                    return isPlaying && self.stopPlaySound() || self.playSound(url, playLoop);
                })
            };

            appService.prototype.playWidgetSound = function (widgetId, url, playLoop) {
                var self = this,
                    arr = [];

                //Accept widget name
                if (!/Widget_\d+$/.test(widgetId)) {
                    var element = document.getElementsByName(widgetId)[0];
                    widgetId = element.id;
                }

                arr.push(function () {
                    self.playSound(url, playLoop);

                    return self.utilService.getResolveDefer();
                });

                if (widgetId) {
                    arr.push(
                        function () {
                            //If sound file is local, it may take a while to load the file and change state to 'playing', or unload it
                            //and change to 'stopped'.
                            return self.$timeout(function () {
                                return self.isPlayingSound().then(function (isPlaying) {
                                    if (isPlaying) {
                                        self.setState(widgetId, "*");
                                    } else {
                                        self.setState(widgetId, "mute");
                                    }
                                })
                            }, self.angularConstants.actionDelay);
                        }
                    );
                }

                return self.utilService.chain(arr);
            };

            appService.prototype.stopPlayWidgetSound = function (widgetId) {
                var self = this,
                    arr = [];

                //Accept widget name
                if (!/Widget_\d+$/.test(widgetId)) {
                    var element = document.getElementsByName(widgetId)[0];
                    widgetId = element.id;
                }

                arr.push(function () {
                    return self.stopPlaySound();
                });

                if (widgetId) {
                    arr.push(
                        function () {
                            //If sound file is local, it may take a while to load the file and change state to 'playing', or unload it
                            //and change to 'stopped'.
                            return self.$timeout(function () {
                                return self.isPlayingSound().then(function (isPlaying) {
                                    if (isPlaying) {
                                        self.setState(widgetId, "*");
                                    } else {
                                        self.setState(widgetId, "mute");
                                    }
                                })
                            }, self.angularConstants.actionDelay);
                        }
                    );
                }

                return self.utilService.chain(arr);
            };

            appService.prototype.toggleWidgetSound = function (widgetId, url, playLoop) {
                var self = this,
                    arr = [];

                //Accept widget name
                if (!/Widget_\d+$/.test(widgetId)) {
                    var element = document.getElementsByName(widgetId)[0];
                    widgetId = element.id;
                }

                arr.push(function () {
                    self.toggleSound(url, playLoop);

                    return self.utilService.getResolveDefer();
                });

                if (widgetId) {
                    arr.push(
                        function () {
                            //If sound file is local, it may take a while to load the file and change state to 'playing', or unload it
                            //and change to 'stopped'.
                            return self.$timeout(function () {
                                return self.isPlayingSound().then(function (isPlaying) {
                                    if (isPlaying) {
                                        self.setState(widgetId, "*");
                                    } else {
                                        self.setState(widgetId, "mute");
                                    }
                                })
                            }, self.angularConstants.actionDelay);
                        }
                    );
                }

                return self.utilService.chain(arr);
            };

            appService.prototype.getSameGroupUsers = function (userId) {
                var self =  this;

                return self.$http({
                    method: 'GET',
                    url: (window.serverUrl || "") + '/api/public/sameGroupUsers',
                    params: {
                        userId: userId
                    }
                }).then(function (result) {
                    if (result.data.result === "OK") {
                        var arr = result.data.resultValue;

                        return self.utilService.getResolveDefer(arr);
                    } else {
                        return self.utilService.getRejectDefer(result.data.reason);
                    }
                }, function (err) {
                    return self.utilService.getRejectDefer(err);
                });
            }

            appService.prototype.getServerUrl = function () {
                //For Debug Use, Don't commit!!!
                return this.utilService.getResolveDefer({data:{result:"OK", resultValue:"http://127.0.0.1:3000"}});
            };

            appService.prototype.getDeviceId = function () {
                return this.utilService.getResolveDefer({data:{result:"OK", resultValue:"" + new Date().getTime()}});
            };

            appService.prototype.getChatServerHost = function () {
                return this.utilService.getResolveDefer({data:{result:"OK", resultValue:"127.0.0.1"}});
            };

            appService.prototype.getChatServerPort = function () {
                return this.utilService.getResolveDefer({data:{result:"OK", resultValue:3010}});
            };

            appService.prototype.createChat = function (userId, projectId) {
                var self =  this;

                return self.$http({
                    method: 'POST',
                    url: (window.serverUrl || "") + '/api/public/chat',
                    params: {
                        userId: userId,
                        projectId: projectId,
                        route: window.pomeloContext.route
                    }
                }).then(function (result) {
                    if (result.data.result === "OK") {
                        var chatId = result.data.resultValue;

                        return self.utilService.getResolveDefer(chatId);
                    } else {
                        return self.utilService.getRejectDefer(result.data.reason);
                    }
                }, function (err) {
                    return self.utilService.getRejectDefer(err);
                });
            }

            appService.prototype.startChat = function (userId, chatId) {
                var self =  this;

                return self.$http({
                    method: 'PUT',
                    url: (window.serverUrl || "") + '/api/public/startChat',
                    params: {
                        userId: userId,
                        chatId: chatId,
                        deviceId: window.pomeloContext.deviceId
                    }
                }).then(function (result) {
                    if (result.data.result === "OK") {
                        return self.utilService.callPomelo(
                            function(pomelo, deviceId) {
                                var defer = self.$q.defer();

                                pomelo.request("chat.chatHandler.create", {
                                    userId: userId,
                                    chatId: chatId,
                                    deviceId: deviceId
                                }, function(data) {
                                    switch(data.code) {
                                        case 500:
                                            defer.reject(data.msg);
                                            break;
                                        case 200:
                                            defer.resolve();
                                            break;
                                        default:
                                            defer.reject("Unkown return code " + data.code);
                                    }
                                });
                                return defer.promise;
                            }
                        );
                    } else {
                        return self.utilService.getRejectDefer(result.data.reason);
                    }
                }, function (err) {
                    return self.utilService.getRejectDefer(err);
                });
            }

            appService.prototype.connectChat = function (userId, chatId) {
                var self = this;

                return self.utilService.callPomelo(
                    function(pomelo, deviceId) {
                        var defer = self.$q.defer();

                        pomelo.request("chat.chatHandler.connect", {
                            userId: userId,
                            chatId: chatId,
                            deviceId: deviceId
                        }, function(data) {
                            switch(data.code) {
                                case 500:
                                    defer.reject(data.msg);
                                    break;
                                case 200:
                                    defer.resolve(data.msg);
                                    break;
                                default:
                                    defer.reject("Unkown return code " + data.code);
                            }
                        });
                        return defer.promise;
                    }
                );
            }

            appService.prototype.pauseChat = function (userId, chatId) {
                var self =  this;

                return self.$http({
                    method: 'PUT',
                    url: (window.serverUrl || "") + '/api/public/pauseChat',
                    params: {
                        userId: userId,
                        chatId: chatId
                    }
                }).then(function (result) {
                    if (result.data.result === "OK") {
                        return self.utilService.callPomelo(
                            function(pomelo, deviceId) {
                                var defer = self.$q.defer();

                                pomelo.request("chat.chatHandler.pause", {
                                    userId: userId,
                                    chatId: chatId
                                }, function(data) {
                                    switch(data.code) {
                                        case 500:
                                            defer.reject(data.msg);
                                            break;
                                        case 200:
                                            defer.resolve();
                                            break;
                                        default:
                                            defer.reject("Unkown return code " + data.code);
                                    }
                                });
                                return defer.promise;
                            }
                        );
                    } else {
                        return self.utilService.getRejectDefer(result.data.reason);
                    }
                }, function (err) {
                    return self.utilService.getRejectDefer(err);
                });
            }

            appService.prototype.resumeChat = function (userId, chatId) {
                var self =  this;

                return self.$http({
                    method: 'PUT',
                    url: (window.serverUrl || "") + '/api/public/resumeChat',
                    params: {
                        userId: userId,
                        chatId: chatId
                    }
                }).then(function (result) {
                    if (result.data.result === "OK") {
                        return self.utilService.callPomelo(
                            function(pomelo, deviceId) {
                                var defer = self.$q.defer();

                                pomelo.request("chat.chatHandler.resume", {
                                    userId: userId,
                                    chatId: chatId
                                }, function(data) {
                                    switch(data.code) {
                                        case 500:
                                            defer.reject(data.msg);
                                            break;
                                        case 200:
                                            defer.resolve();
                                            break;
                                        default:
                                            defer.reject("Unkown return code " + data.code);
                                    }
                                });
                                return defer.promise;
                            }
                        );
                    } else {
                        return self.utilService.getRejectDefer(result.data.reason);
                    }
                }, function (err) {
                    return self.utilService.getRejectDefer(err);
                });
            }

            appService.prototype.inviteChat = function (userId, chatId, uids) {
                var self =  this;

                return self.$http({
                    method: 'PUT',
                    url: (window.serverUrl || "") + '/api/public/inviteChat',
                    params: {
                        userId: userId,
                        chatId: chatId,
                        uids: JSON.stringify(uids),
                        route: widnow.pomeloContext.route
                    }
                }).then(function (result) {
                    if (result.data.result === "OK") {
                        return self.utilService.callPomelo(
                            function(pomelo, deviceId) {
                                var defer = self.$q.defer();

                                pomelo.request("chat.chatHandler.invite", {
                                    userId: userId,
                                    chatId: chatId,
                                    uids: JSON.stringify(uids)
                                }, function(data) {
                                    switch(data.code) {
                                        case 500:
                                            defer.reject(data.msg);
                                            break;
                                        case 200:
                                            defer.resolve();
                                            break;
                                        default:
                                            defer.reject("Unkown return code " + data.code);
                                    }
                                });
                                return defer.promise;
                            }
                        );
                    } else {
                        return self.utilService.getRejectDefer(result.data.reason);
                    }
                }, function (err) {
                    return self.utilService.getRejectDefer(err);
                });
            }

            appService.prototype.acceptInviteChat = function (userId, chatId) {
                var self =  this;

                return self.$http({
                    method: 'PUT',
                    url: (window.serverUrl || "") + '/api/public/acceptInvite',
                    params: {
                        userId: userId,
                        chatId: chatId
                    }
                }).then(function (result) {
                    if (result.data.result === "OK") {
                        return self.connectChat(userId, chatId);
                    } else {
                        return self.utilService.getRejectDefer(result.data.reason);
                    }
                }, function (err) {
                    return self.utilService.getRejectDefer(err);
                });
            }

            appService.prototype.closeChat = function (userId, chatId) {
                var self =  this;

                return self.$http({
                    method: 'PUT',
                    url: (window.serverUrl || "") + '/api/public/closeChat',
                    params: {
                        userId: userId,
                        chatId: chatId
                    }
                }).then(function (result) {
                    if (result.data.result === "OK") {
                        return self.utilService.callPomelo(
                            function(pomelo, deviceId) {
                                var defer = self.$q.defer();

                                pomelo.request("chat.chatHandler.close", {
                                    userId: userId,
                                    chatId: chatId
                                }, function(data) {
                                    switch(data.code) {
                                        case 500:
                                            defer.reject(data.msg);
                                            break;
                                        case 200:
                                            defer.resolve();
                                            break;
                                        default:
                                            defer.reject("Unkown return code " + data.code);
                                    }
                                });
                                return defer.promise;
                            }
                        );
                    } else {
                        return self.utilService.getRejectDefer(result.data.reason);
                    }
                }, function (err) {
                    return self.utilService.getRejectDefer(err);
                });
            }

            appService.prototype.createTopic = function (userId, chatId) {
                var self =  this;

                chatId = chatId || window.pomeloContext.chatId;
                return self.$http({
                    method: 'POST',
                    url: (window.serverUrl || "") + '/api/public/topic',
                    params: {
                        userId: userId,
                        chatId: chatId,
                        route: window.pomeloContext.route
                    }
                }).then(function (result) {
                    if (result.data.result === "OK") {
                        var topicId = result.data.resultValue;

                        return self.utilService.callPomelo(
                            function(pomelo, deviceId) {
                                var defer = self.$q.defer();

                                pomelo.request("chat.chatHandler.createTopic", {
                                    userId: userId,
                                    chatId: chatId,
                                    topicId: topicId
                                }, function(data) {
                                    switch(data.code) {
                                        case 500:
                                            defer.reject(data.msg);
                                            break;
                                        case 200:
                                            defer.resolve(data.msg);
                                            break;
                                        default:
                                            defer.reject("Unkown return code " + data.code);
                                    }
                                });
                                return defer.promise;
                            }
                        );
                    } else {
                        return self.utilService.getRejectDefer(result.data.reason);
                    }
                }, function (err) {
                    return self.utilService.getRejectDefer(err);
                });
            }

            appService.prototype.pauseTopic = function (userId, chatId, topicFilter) {
                var self =  this;

                topicFilter = topicFilter || {};
                return self.$http({
                    method: 'PUT',
                    url: (window.serverUrl || "") + '/api/public/pauseTopic',
                    params: {
                        userId: userId,
                        topicFilter: JSON.stringify(topicFilter)
                    }
                }).then(function (result) {
                    if (result.data.result === "OK") {
                        var topicIdArray = result.data.resultValue;
                        if (topicIdArray && topicIdArray.length) {
                            var arr = [];
                            topicIdArray.forEach(function(topicId) {
                                arr.push(
                                    self.utilService.callPomelo(
                                        function(pomelo, deviceId) {
                                            var defer = self.$q.defer();

                                            pomelo.request("chat.chatHandler.pauseTopic", {
                                                userId: userId,
                                                chatId: chatId,
                                                topicId: topicId
                                            }, function(data) {
                                                switch(data.code) {
                                                    case 500:
                                                        defer.reject(data.msg);
                                                        break;
                                                    case 200:
                                                        defer.resolve();
                                                        break;
                                                    default:
                                                        defer.reject("Unkown return code " + data.code);
                                                }
                                            });
                                            return defer.promise;
                                        }
                                    )
                                );
                            });

                            return arr.length && self.$q.all(arr) || self.utilService.getResolveDefer();
                        } else {
                            return self.utilService.getResolveDefer();
                        }
                    } else {
                        return self.utilService.getRejectDefer(result.data.reason);
                    }
                }, function (err) {
                    return self.utilService.getRejectDefer(err);
                });
            }

            appService.prototype.resumeTopic = function (userId, chatId, topicFilter) {
                var self =  this;

                topicFilter = topicFilter || {};
                return self.$http({
                    method: 'PUT',
                    url: (window.serverUrl || "") + '/api/public/resumeTopic',
                    params: {
                        userId: userId,
                        topicFilter: JSON.stringify(topicFilter)
                    }
                }).then(function (result) {
                    if (result.data.result === "OK") {
                        var topicIdArray = result.data.resultValue;
                        if (topicIdArray && topicIdArray.length) {
                            var arr = [];
                            topicIdArray.forEach(function(topicId) {
                                arr.push(
                                    self.utilService.callPomelo(
                                        function(pomelo, deviceId) {
                                            var defer = self.$q.defer();

                                            pomelo.request("chat.chatHandler.resumeTopic", {
                                                userId: userId,
                                                chatId: chatId,
                                                topicId: topicId
                                            }, function(data) {
                                                switch(data.code) {
                                                    case 500:
                                                        defer.reject(data.msg);
                                                        break;
                                                    case 200:
                                                        defer.resolve();
                                                        break;
                                                    default:
                                                        defer.reject("Unkown return code " + data.code);
                                                }
                                            });
                                            return defer.promise;
                                        }
                                    )
                                );
                            });

                            return arr.length && self.$q.all(arr) || self.utilService.getResolveDefer();
                        } else {
                            return self.utilService.getResolveDefer();
                        }
                    } else {
                        return self.utilService.getRejectDefer(result.data.reason);
                    }
                }, function (err) {
                    return self.utilService.getRejectDefer(err);
                });
            }

            appService.prototype.inviteTopic = function (userId, chatId, topicId, uids) {
                var self =  this;

                return self.$http({
                    method: 'PUT',
                    url: (window.serverUrl || "") + '/api/public/inviteTopic',
                    params: {
                        userId: userId,
                        topicId: topicId,
                        uids: JSON.stringify(uids)
                    }
                }).then(function (result) {
                    if (result.data.result === "OK") {
                        return self.utilService.callPomelo(
                            function(pomelo, deviceId) {
                                var defer = self.$q.defer();

                                pomelo.request("chat.chatHandler.inviteTopic", {
                                    userId: userId,
                                    chatId: chatId,
                                    topicId: topicId,
                                    uids: JSON.stringify(uids)
                                }, function(data) {
                                    switch(data.code) {
                                        case 500:
                                            defer.reject(data.msg);
                                            break;
                                        case 200:
                                            defer.resolve();
                                            break;
                                        default:
                                            defer.reject("Unkown return code " + data.code);
                                    }
                                });
                                return defer.promise;
                            }
                        );
                    } else {
                        return self.utilService.getRejectDefer(result.data.reason);
                    }
                }, function (err) {
                    return self.utilService.getRejectDefer(err);
                });
            }

            appService.prototype.acceptInviteTopic = function (userId, topicId) {
                var self =  this;

                return self.$http({
                    method: 'PUT',
                    url: (window.serverUrl || "") + '/api/public/acceptInviteTopic',
                    params: {
                        userId: userId,
                        topicId: topicId
                    }
                });
            }

            appService.prototype.closeTopic = function (userId, topicId) {
                var self =  this;

                return self.$http({
                    method: 'PUT',
                    url: (window.serverUrl || "") + '/api/public/closeTopic',
                    params: {
                        userId: userId,
                        topicId: topicId
                    }
                }).then(function (result) {
                    if (result.data.result === "OK") {
                        return self.utilService.callPomelo(
                            function(pomelo, deviceId) {
                                var defer = self.$q.defer();

                                pomelo.request("chat.chatHandler.closeTopic", {
                                    userId: userId,
                                    chatId: chatId,
                                    topicId: topicId
                                }, function(data) {
                                    switch(data.code) {
                                        case 500:
                                            defer.reject(data.msg);
                                            break;
                                        case 200:
                                            defer.resolve();
                                            break;
                                        default:
                                            defer.reject("Unkown return code " + data.code);
                                    }
                                });
                                return defer.promise;
                            }
                        );
                    } else {
                        return self.utilService.getRejectDefer(result.data.reason);
                    }
                }, function (err) {
                    return self.utilService.getRejectDefer(err);
                });
            }

            appService.prototype.sendChatMessage = function (userId, chatId, uids, payload) {
                var self = this;

                return self.utilService.callPomelo(
                    function(pomelo) {
                        var defer = self.$q.defer();

                        pomelo.request("chat.chatHandler.push", {
                            userId: userId,
                            chatId: chatId,
                            uids: uids,
                            payload: payload
                        }, function(data) {
                            switch(data.code) {
                                case 500:
                                    defer.reject(data.msg);
                                    break;
                                case 200:
                                    defer.resolve();
                                    break;
                                default:
                                    defer.reject("Unkown return code " + data.code);
                            }
                        });
                        return defer.promise;
                    }
                );
            }

            appService.prototype.sendTopicMessage = function (userId, chatId, topicId, payload) {
                var self = this;

                return self.utilService.callPomelo(
                    function(pomelo) {
                        var defer = self.$q.defer();

                        pomelo.request("chat.chatHandler.pushTopic", {
                            userId: userId,
                            chatId: chatId,
                            topicId: topicId,
                            payload: payload
                        }, function(data) {
                            switch(data.code) {
                                case 500:
                                    defer.reject(data.msg);
                                    break;
                                case 200:
                                    defer.resolve();
                                    break;
                                default:
                                    defer.reject("Unkown return code " + data.code);
                            }
                        });
                        return defer.promise;
                    }
                );
            }

            appModule.
                config(['$httpProvider',
                    function ($httpProvider) {
                        $httpProvider.defaults.useXDomain = true;
                        $httpProvider.defaults.withCredentials = true;
                        delete $httpProvider.defaults.headers.common['X-Requested-With'];
                    }
                ]).
                config(["$provide", "$controllerProvider", "$compileProvider", "$injector", function ($provide, $controllerProvider, $compileProvider, $injector) {
                    $provide.service('appService', appService);
                    appService.prototype.$controllerProvider = $controllerProvider;
                    appService.prototype.$compileProvider = $compileProvider;
                    appService.prototype.$injector = $injector;

                    var instance = $injector.get('appServiceProvider').$get();
                    instance.registerService();
                }]);
        }
    }
)
;
