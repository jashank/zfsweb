#!/usr/bin/perl -w
#
# Copyright 2013 Professional Utility Board.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;

# Core modules
use CGI qw/:all/;
use File::Basename;
use File::Compare;
use File::stat;
use IO::Dir;
use POSIX;

# Dependencies
use Filesys::Df;
use File::MimeInfo::Magic;
use Number::Format qw(:subs);
use URI::Escape;

### Configurable knobs

my $ZFSWEB_PATH = "/zfsweb";
my $ZFSWEB = "$ZFSWEB_PATH/zfsweb.pl";
my $LOGO = "$ZFSWEB_PATH/logo.png";
my $LOGO_ALT = "zfsweb";

# Data stores _must_ be ZFS filesystems.
my %STORES = (
    'pub' => '/zed/pubdata',
    'homes' => '/home',
  );

### End configurable knobs

###
### Look and feel
###
sub HEADER {
  print (header());
  print <<EOF;
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en-US" xml:lang="en-US">
  <head>
    <title>zfsweb</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <link rel="stylesheet" href="//netdna.bootstrapcdn.com/bootstrap/3.0.2/css/bootstrap.min.css" />
    <link rel="stylesheet" href="//netdna.bootstrapcdn.com/font-awesome/4.0.3/css/font-awesome.css" />
  </head>
  <body>
    <div class="container">
      <div class="row">
        <div class="col-md-8 col-md-offset-2">
          <h1 class="text-center">
            <img class="text-center" src="$LOGO" alt="[$LOGO_ALT]" /></h1>
          <hr />

EOF
}


###
### Breadcrumbs.
###

# Recursively breadcrumb.
sub _crumb {
  my ($store, $point, $path, $last) = @_;

  if ($path ne "/") {
    _crumb($store, $point, dirname($path), 0);
  } else {
    return;
  }

  my $slice = basename $path;
  $path =~ s@/$@@;

  $path = uri_escape($path);
  if ($last) {
    print <<EOF;
  <li>$slice</li>
EOF
  } else {
    print <<EOF;
  <li><a href="$ZFSWEB?path=$store\@$point:$path/">$slice</a></li>
EOF
  }
}

# Breadcrumb trail.
sub crumbs {
  my ($store, $point, $path) = @_;

  print <<EOF;
<ol class="breadcrumb">
  <li><a href="$ZFSWEB">zed</a></li>
EOF

  if ($store) {
    print <<EOF;
  <li><a href="$ZFSWEB?path=$store:/">$store</a></li>
EOF
    if ($point) {
      print <<EOF;
  <li><a href="$ZFSWEB?path=$store\@$point:/">\@$point</a></li>
EOF
      if ($path ne "/") {
        _crumb($store, $point, $path, 1);
      }
    }
}

  print <<EOF;
</ol>
EOF
}

###
### Takes a percentage.  Returns a progressbar.
###
sub progressbar {
  my ($pc) = @_;

  return <<BAR;
<div class="progress progress-striped">
  <div class="progress-bar progress-bar-info" role="progressbar" aria-valuenow="%pc" aria-valuemin="0" aria-valuemax="100" style="width: $pc\%">
    <span class="sr-only">$pc\% full</span>
  </div>
</div>
BAR
}

###
### Takes a file path; calculates the mime type of that file.
###
sub mime_type {
  my ($fullPath) = @_;

  my $mime_type = mimetype($fullPath);
  $mime_type = "application/octet-stream" unless $mime_type;

  return $mime_type;
}

# store, point, path => real file path
sub fullPath {
  my ($store, $point, $path) = @_;

  $path = "" unless (defined($path));

  my $fullPath = "";

  $fullPath = $STORES{$store}."/.zfs/snapshot/".$point.$path;
  $fullPath = $STORES{$store}.$path if ($point eq "_");

  return $fullPath;
}

### Renderers

# List the datastores.
sub renderStores {
  print <<EOF;
<h2>Index of stores</h2>
EOF

  crumbs('', '', '');

  print <<EOF;
<div class="list-group">
EOF

  foreach my $store (keys %STORES) {
    my $path = $STORES{$store};
    my $fs = df($path);
    my $pc = $fs->{per};
    my $summary = "";
    $summary .= "Stored at <tt>$path</tt>.\n";
    $summary .= progressbar($pc);
    
    print <<EOF;
<a href="$ZFSWEB?path=$store:/" class="list-group-item">
  <h4 class="list-group-item-heading">$store</h4>
  <p class="list-group-item-text">$summary</p>
</a>
EOF
  }

  print <<EOF;
</div>
EOF
}

# List the snapshots of a datastore.
sub renderSnapshots {
  my ($store) = @_;

  my $path = $STORES{$store};

  print <<EOF;
<h2>Index of snapshots of $store</h2>
EOF

  crumbs($store, '', '');

  print <<EOF;
<div class="list-group">
EOF

  open my $zfs, "zfs list -r -t snapshot -Ho name -s creation $path |"
    or die "couldn't query ZFS snapshots: $!";
  my @snaps;
  while (<$zfs>) {
    chomp;
    my ($fs, $snap) = split(/@/, $_, 2);
    push @snaps, $snap;
  }
  close $zfs; # and fuck you too, ZFS.

  foreach my $snap (reverse @snaps) {
    print <<EOF;
<a href="$ZFSWEB?path=$store\@$snap:/" class="list-group-item">\@ $snap</a>
EOF
  }

  print <<EOF;
</div>
EOF
}

# list the contents of a directory
sub renderDir {
  my ($store, $point, $path, $sort) = @_;

  my $fullPath = fullPath($store, $point, $path);

  tie my %dir, 'IO::Dir', $fullPath;
  my @files = keys %dir;

  if (($sort eq "") or ($sort eq "az")) {
    @files = sort @files;
  } elsif ($sort eq "za") {
    @files = reverse sort @files;
  } elsif ($sort eq "mt") {
    @files = sort { $dir{$a}->mtime <=> $dir{$b}->mtime } @files;
  } elsif ($sort eq "tm") {
    @files = reverse sort { $dir{$a}->mtime <=> $dir{$b}->mtime } @files;
  }

  @files = grep { $_ ne ".." } @files;
  unshift @files, "..";

  my $POINT = "";
  $POINT = " at $point";
  $POINT = "" if ($point eq "_");

  print <<EOF;
<h2>Index of $store$POINT &mdash; $path</h2>
<div class="row">
  <div class="col-md-9">
EOF
  crumbs($store, $point, $path);

  my $url = url(-query => 1, -absolute => 1);

#?path=homes%40_%3A%2F;sort=tm&sort=az
  $url =~ s@;sort=..$@@;

  print <<EOF;
  </div>
  <div class="col-md-3">
    <div class="btn-group">
      <a href="$url&sort=az" class="btn btn-default"><i class="fa fa-sort-alpha-asc"></i></a>
      <a href="$url&sort=za" class="btn btn-default"><i class="fa fa-sort-alpha-desc"></i></a>
      <a href="$url&sort=mt" class="btn btn-default"><i class="fa fa-sort-numeric-asc"></i></a>
      <a href="$url&sort=tm" class="btn btn-default"><i class="fa fa-sort-numeric-desc"></i></a>
    </div>
  </div>
</div>
<ul class="list-group">
EOF

  foreach my $file (@files) {
    my $icon = "fa-circle-o";
    my $link = "$store\@$point:$path$file";
    my $name = $file;
    my $info = format_bytes($dir{$file}->size). "b |"
	. " upd. ". strftime("%F %T", localtime $dir{$file}->mtime);

    if ($file eq ".") {
      next;
    } elsif ($file eq "..") {
      $icon = "fa-share fa-rotate-270";
      $name = "[parent directory]";
      $info = "";

      if ($path eq "/") {
        $link = "$store:/";
      } else {
        $link = "$store\@$point:". dirname($path) ."/";
      }
    } elsif (-d $fullPath."/".$file) {
      $icon = "fa-folder-open";
      $link .= "/";
      $info = "upd. ". strftime("%F %T", localtime $dir{$file}->mtime);
    } elsif (-f $fullPath."/".$file) {
      $icon = "fa-file"; 
    }

    $link = uri_escape($link);

    $link .= "&sort=$sort" if $sort;
    print <<EOF;
<a href="$ZFSWEB?path=$link" class="list-group-item"><i class="fa fa-fw $icon"></i> $name <span class="badge pull-right">$info</span></a>
EOF
  }

  print <<EOF;
</ul>
EOF
}

# render file
sub renderFile {
  my ($store, $point, $path) = @_;

  my $fullPath = fullPath($store, $point, $path);

  my $file = basename $path;

  my $mime_type = mime_type $fullPath;
  my $stat = File::stat::lstat($fullPath);

  my $mtime = strftime("%F %T", localtime $stat->mtime);
  my $ctime = strftime("%F %T", localtime $stat->ctime);
  my $atime = strftime("%F %T", localtime $stat->atime);
  my $size = $stat->size;
  my $mode = $stat->mode;
  my $uid = getpwuid($stat->uid);
  my $gid = getgrgid($stat->gid);

  crumbs($store, $point, $path);

  print <<EOF;
<h3>$file</h3>
<div class="row">
  <div class="col-md-5">
EOF

  unless ($point eq "_") {
    if (compare( $STORES{$store}."/.zfs/snapshot/".$point.$path, $STORES{$store}.$path) == 0) {
      print <<EOF;
    <div class="alert alert-success"><i class="fa fa-fw fa-check-square-o"></i> This is equivalent to the latest version.</div>
EOF
    } else {
      print <<EOF;
    <div class="alert alert-info"><i class="fa fa-fw fa-exclamation"></i> This differs from the current version.</div>
EOF
    }
  }

  my $brl = uri_escape "$store\@$point:$path";
  my $brn = uri_escape "$store\@_:$path";

  print <<EOF;
<a href="$ZFSWEB?path=$brl&action=dl" class="btn btn-primary btn-lg btn-block"><i class="fa fa-fw fa-download"></i> Download This</a>
<a href="$ZFSWEB?path=$brn&action=dl" class="btn btn-default btn-lg btn-block"><i class="fa fa-fw fa-download"></i> Download Current</a>
EOF

  print <<EOF;
  </div>
  <div class="col-md-7">
    <table class="table">
      <tbody>
        <tr><th>Size</th><td>$size</td></tr>
        <tr><th>Created at</th><td>$ctime</td></tr>
        <tr><th>Last modified at</th><td>$mtime</td></tr>
        <tr><th>MIME Type</th><td>$mime_type</td></tr>
        <tr><th>Owner/Group</th><td>$uid / $gid</td></tr>
        <tr><th>File Mode</th><td>$mode</td></tr>
      </tbody>
    </table>
  </div>
</div>
EOF
}

### Dispatcher

if (param('path')) {
  my $dirname = param('path');

  # store@point:path
  # - validate store
  # - validate point
  # - screw the path (XXX we should probably validate it too) 

  my ($storepoint, $path) = split(/:/, $dirname, 2);
  my ($store, $point) = split(/@/, $storepoint, 2);
  $path = "/" if ($path eq "//");

  unless (exists($STORES{$store})) {
    HEADER();
    print "<p class=\"text-danger\">Unknown store $store</p>\n";
    goto END;
  }

  my $fullPath = fullPath($store, $point, undef);

  unless (-e $fullPath) {
    HEADER();
    print "<p class=\"text-danger\">Unknown snapshot $point</p>\n";
    goto END;
  }

  if ((param('action')) && (param('action') eq "dl")) {
    $fullPath = fullPath($store, $point, undef);

    my $name = basename $path;
    my $mime_type = mimetype($fullPath);

    print "Content-type: $mime_type\n";
    print "Content-Disposition: attachment; filename=$name\n";
    print "Content-Description: $name at $point\n\n";

    {
      open my ($fh), $fullPath;
      local $/;
      print <$fh>;
      close $fh
    }

    exit 0;
  }

  unless (defined($point)) {
    HEADER();
    renderSnapshots($store);
    goto END;
  }

#if (($path eq "/") or ($path eq ""));

  my $sort = "";
  $sort = param('sort') if param('sort');

  HEADER();
  if ($path =~ m@/$@) {
    renderDir($store, $point, $path, $sort);
  } else {
    renderFile($store, $point, $path);
  }
  goto END;

} else {
  HEADER();
  renderStores();
  goto END;
}

END:
print <<EOF;

          <footer>
	    <hr />
	    <p class="text-center">Copyright &copy; 2013 Professional Utility Board.  All rights reserved.<br />
	      <small><a href="https://github.com/Jashank/zfsweb">zfsweb</a> by <a href="http://twitter.com/JashankJ">\@JashankJ</a>.<br />
	        <a href="http://getbootstrap.com/">Bootstrap</a> | <a href="http://www.perl.org/">Perl</a> | <a href="https://java.net/projects/solaris-zfs">ZFS</a></small></p>
          </footer>
        </div>
      </div>
    </div>
    <script src="//code.jquery.com/jquery.js"></script>
    <script src="//netdna.bootstrapcdn.com/bootstrap/3.0.2/js/bootstrap.min.js"></script>
  </body>
</html>
EOF

__END__
