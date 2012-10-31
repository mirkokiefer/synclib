// Generated by CoffeeScript 1.3.3
(function() {

  module.exports = {
    Repository: require('./repository'),
    TreeStore: require('./tree-store'),
    backend: {
      browser: function() {
        return {
          Memory: require('./backends/memory'),
          LocalStorage: require('./backends/localstorage')
        };
      },
      server: function() {
        return {
          Memory: require('./backends/memory'),
          FileSystem: require('./backends/filesystem')
        };
      }
    }
  };

}).call(this);