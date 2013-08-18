zfsweb - Primitive ZFS snapshot browser
=======================================

zfsweb is a basic web interface to a ZFS snapshot hierarchy.  Written
in Perl, using only a handful of lightweight external modules, and
generating an interface using Twitter Bootstrap, it's fast, responsive
and friendly.

### Installation ###

To install:

1. Create a CGI-capable directory in a web root on your ZFS system.
2. Copy `zfsweb.pl` and a logo (preferably `logo/zfsweb.png`) to that
   directory as `zfsweb.pl` and `logo.png`, respectively.
3. Change `$ZFSWEB_PATH` (and, if necessary, `$LOGO` and `$LOGO_ALT`).
4. Change `%STORES` to point at the filesystems.

### Security ###

None beyond what your web server allows.  Go read your web server's
manual.  At Professional Utility Board, we use Apache 2.2 and
`mod_authnz_ldap` to secure the application.
 
