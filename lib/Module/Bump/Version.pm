package Module::Bump::Version;

use strict;
use warnings;
use version;

use Carp qw(croak);
use Data::Dumper;
use File::Find::Rule;
use PPI;

use Exporter qw(import);
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    bump_version
    get_version_info
);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

our $VERSION = '0.01';

use constant {
    FSTYPE_IS_DIR       => 1,
    FSTYPE_IS_FILE      => 2,

    DEFAULT_DIR         => 'lib/',
};
my $default_dir = 'lib/';

sub bump_version {
    my ($version, $dir) = @_;

    _validate_version($version);
    _validate_fs_entry($dir);

    my @module_files = _find_modules($dir);

    for (@module_files) {
        my $version_line = _find_version_line($_);
        my @file_contents = _fetch_file_contents($_);

        my $mem_file;

        open my $wfh, '>', \$mem_file or croak("Can't open mem file!: $!");

        my $current_version;

        for my $line (@file_contents) {
            chomp $line;
            if ($line eq $version_line) {
                $current_version = _find_file_version($_);
                $line =~ s/$current_version/$version/;
            }
        }

        print "Changed $_ from version '$current_version' to '$version'\n";
    }
}
sub get_version_info {
    my ($fs_entry) = @_;

    _validate_fs_entry($fs_entry);

    my @module_files = _find_module_files($fs_entry);

    my %version_info;

    for (@module_files) {
        my $version = _extract_file_version($_);
        $version_info{$_} = $version;
    }

    return \%version_info;
}

sub _find_module_files {
    my ($fs_entry) = @_;

    $fs_entry //= DEFAULT_DIR;

    return File::Find::Rule->file()
        ->name('*.pm')
        ->in($fs_entry);
}
sub _fetch_file_contents {
    my ($file) = @_;

    open my $fh, '<', $file
      or croak("Can't open file '$file' for reading!: $!");

    my @contents = <$fh>;
    close $fh;
    return @contents;
}
sub _extract_file_version {
    my ($module_file) = @_;

    my $version_line = _extract_file_version_line($module_file);

    if ($version_line =~ /=(.*)$/) {
        my $ver = $1;

        $ver =~ s/\s+//g;
        $ver =~ s/;//g;
        $ver =~ s/[a-zA-Z]+//g;
        $ver =~ s/"//g;
        $ver =~ s/'//g;

        if (! defined eval { version->parse($ver); 1 }) {
            croak("Can't find a valid version in file '$_'");
        }

        return $ver;
    }
}
sub _extract_file_version_line {
    my ($module_file) = @_;

    my $doc = PPI::Document->new($module_file);

    my $version_line = (
        $doc->find(
            sub {
                $_[1]->isa("PPI::Statement::Variable")
                    and $_[1]->content =~ /\$VERSION/;
            }
        )
    )->[0]->content;

    return $version_line;
}

sub _validate_fs_entry {
    my ($fs_entry) = @_;

    return if ! defined $_[0];

    return FSTYPE_IS_DIR    if -d $fs_entry;
    return FSTYPE_IS_FILE   if -f $fs_entry;

    croak("File system entry '$fs_entry' is invalid");
}
sub _validate_version {
    my ($version) = @_;

    croak("version parameter must be supplied!") if ! defined $version;

    if (! defined eval { version->parse($version); 1 }) {
        croak("The version number '$version' specified is invalid");
    }
}

1;
__END__

=head1 NAME

Module::Bump::Version - Prepare a Perl distribution for its next release cycle

=head1 DESCRIPTION

=head1 SYNOPSIS

    use Module::Bump::Version;

=head1 FUNCTIONS

=head1 AUTHOR

Steve Bertrand, C<< <steveb at cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2020 Steve Bertrand.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>
