

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'DNS::WorldWideDns',
    VERSION_FROM => 'lib/DNS/WorldWideDns.pm', # finds \$VERSION
    AUTHOR       => 'JT Smith (jt_at_plainblack_com)',
    ABSTRACT     => 'An interface to the worldwidedns.net site.',
    PREREQ_PM    => {
                     'Test::Simple' => 0.44,
                    },
);
