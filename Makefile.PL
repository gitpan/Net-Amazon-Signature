use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Net::Amazon::Signature',
    AUTHOR              => q{Tim Nordenfur <tim@gurka.se>},
    VERSION_FROM        => 'lib/Net/Amazon/Signature.pm',
    ABSTRACT_FROM       => 'lib/Net/Amazon/Signature.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Net-Amazon-Signature-*' },
);
