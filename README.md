# cla-permissions-check-plugin

This is a plugin for [Koha](https://koha-community.org/) that allows you to make queries to the [CLA Check Permissions service](https://www.cla.co.uk/check-permissions-start) for biblios within your catalogue

## Getting Started

At the time of writing (25th June 2018), the Koha core component of this functionality has been [submitted as a bug](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=20968),
but not yet merged into the main product. Until such a time as this is done, in order to use this plugin, you will need to apply Bug 20968 to your Koha installation. This can be done via [git bz](https://wiki.koha-community.org/wiki/Git_bz_configuration)

Once the patch is applied, download this plugin by downloading the latest release .kpz file from the [releases page](https://github.com/PTFS-Europe/cla-permissions-check-plugin/releases).

The plugin system needs to be turned on by a system administrator.

To set up the Koha plugin system you must first make some changes to your install.

Change `<enable_plugins>0<enable_plugins>` to `<enable_plugins>1</enable_plugins>` in your `koha-conf.xml` file
Confirm that the path to `<pluginsdir>` exists, is correct, and is writable by the web server
Restart your webserver
Once set up is complete you will need to alter your `UseKohaPlugins` system preference. On the Tools page you will see the Tools Plugins and on the Reports page you will see the Reports Plugins.

```
Give examples
```

### Installing

Once your Koha has plugins turned on, as detailed above, installing the plugin is then a case of selecting the "Upload plugin" button on the Plugins page and navigating to the .kpz file you downloaded

## Authors

* Andrew Isherwood
