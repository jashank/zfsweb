# zfsweb #

![zfsweb logo](../logo/zfsweb.png)

zfsweb is a basic web interface to a ZFS snapshot hierarchy.  Written in Perl, using only a handful of lightweight external modules, and generating an interface using Twitter Bootstrap, it's fast, responsive and friendly. 

## Installation ##

### Dependencies ###

`zfsweb` depends on:

 - The `zfs` utility
 - Perl 5

And, from CPAN,

 - [`Filesys::Df`](https://metacpan.org/module/Filesys::Df),
 - [`File::MimeInfo`](https://metacpan.org/module/File::MimeInfo),
 - [`Number::Format`](https://metacpan.org/module/Number::Format), and
 - [`URI::Escape`](https://metacpan.org/module/URI::Escape)

### Installing zfsweb ###

To install:

1. Create a CGI-capable directory in a web root on your ZFS system.  Consult your web server's documentation for details.
2. Copy `zfsweb.pl` and a logo (preferably `logo/zfsweb.png`) to that directory as `zfsweb.pl` and `logo.png`, respectively.

### Confiuring zfsweb ###

#### Data Stores ####

`zfsweb` abstracts away the underlying file systems, and instead represents them as _data stores_.

Each data store has a unique (and preferably memorable) name that's configured in the `%STORES` variable.  Change `%STORES` to point at the filesystems you want to browse.

The default stores reflect a configuration that users may find somewhat useful.

    my %STORES = (
        'homes' => '/home',
        'pub' => '/zed/pubdata',
      );

#### Locating zfsweb ####

`$ZFSWEB_PATH` is the location with respect to the web server where `zfsweb` is installed.

    my $ZFSWEB_PATH = "/zfsweb";
    
`$ZFSWEB` is the name of the `zfsweb.pl` file, if it has been changed.

    my $ZFSWEB = "$ZFSWEB_PATH/zfsweb.pl";

`$LOGO` points at a logo.

    my $LOGO = "$ZFSWEB_PATH/logo.png";

`$LOGO_ALT` is the logo alternate text.

    my $LOGO_ALT = "zfsweb";

`$STORAGE` is the name of the data server, which appears at the
beginning of the breadcrumbs list in the user interface. 

    my $STORAGE = "zed";


### Securing zfsweb ###

__`zfsweb` has no security built in__.

You absolutely _must_ set up security for `zfsweb` before you set it live.  At Professional Utility Board, we use Apache 2.2 and `mod_authnz_ldap` to secure it; we don't provide any support for securing it.

## Using zfsweb ##

### The Stores view ###

The first thing that you see when you browse to the zfsweb application is the stores overview.

![The stores view.](img/elspeth.1.20130818.024244.png)

### The Snapshots view ###

Once you select a store, you are presented with a list of snapshots.

![The snapshots view.](img/elspeth.1.20130818.024249.png)

Be aware of a special snapshot called `_`.  `_` represents the current state.

### The Directory browser ###

Once you select a snapshot, you are presented with a directory listing.

![Directory listing.](img/elspeth.1.20130818.024256.png)

### The File view ###

`zfsweb` doesn't support displaying files in-browser (yet).  It does, however, present some vital statistics on the file and the option to download it locally.

![The file view.](img/elspeth.1.20130818.024318.png)

_Download This_ downloads the displayed version of the file.  _Download Current_ downloads the current version of the file.

In the `_` snapshot, the file's status with respect to the current revision is not displayed.

![The file view.](img/elspeth.1.20130818.024312.png)
