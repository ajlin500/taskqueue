Package.describe({
  name: 'taskqueue',
  version: '0.0.1',
  // Brief, one-line summary of the package.
  summary: '',
  // URL to the Git repository containing the source code for this package.
  git: '',
  // By default, Meteor will default to using README.md for documentation.
  // To avoid submitting documentation, set this field to null.
  documentation: 'README.md'
});

Package.onUse(function(api) {
  api.versionsFrom('1.1.0.3');

  // External packages
  api.use('coffeescript');
  api.use('check');
  api.use('aldeed:collection2');

  // Package files
  api.use('server.coffee', 'server');
});

Package.onTest(function(api) {
  api.use('sanjo:jasmine@0.16.4');
  api.use('taskqueue');

  api.addFiles('server.spec.coffee', 'server');
});