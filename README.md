CentOS Kernel Upgrades
======================

[![Build Status](https://travis-ci.com/ElvenSpellmaker/CentOSKernelUpdates.svg?branch=master)](https://travis-ci.com/ElvenSpellmaker/CentOSKernelUpdates)

This script updates kernel packages on a list of CentOS machines and gives them
a reboot after a successful upgrade.

This script was written to help automate the updating of CentOS kernels on many
machines at a time to mitigate against Meltdown and Spectre.

The script assumes a naming convention of a machine ending in `[01]x*.[cd]om`
where `x` is a number which is controlled by supplying an `ODD` or `EVEN`
argument.
If this isn't appropriate you may change the regex at the bottom of the while
loop to suit your naming convention.

## Usage
`./updateKernels.bash ci ODD`
Where:
 - `ci` is the suffix of a file (`machines-ci` in this case) with a list of
  machine names adhering to the naming conventions listed above.
 - `ODD` is one of either `ODD` or `EVEN` which will update either odd or even
  numbered machines
