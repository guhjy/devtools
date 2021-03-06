# devtools
Tools for the Stata developer

## Description
A colection of functions for the stata developer. A list of the current
available functions is:

* `dt_stata_capture()` A wrapper of `stata()`.
* `dt_random_name()` RN(ame)G algorithm based on current datetime.
* `dt_shell()` A wrapper of `shell` which retrives OS cmdline output.
* `dt_erase_file()` Deleting files through the OS cmdline.
* `dt_copy_file()` Copying files through the OS cmdline.
* `dt_restart_stata()` Restart stata.
* `dt_moxygen()` Doxygen for MATA! (and soon for stata).
* `dt_highlight()` Highlight MATA syntax with SMCL.
* `dt_txt_split()` Fixing a paragraph width.
* `dt_moxygen_preview()` Preview a hlp file of MATA source with Doxygen.
* `dt_install_on_the_fly()` Install a package on the fly.
* `dt_lookuptxt()` Search text or regex within plaintext files.
* `dt_uninstall_pkg()` Uninstall a package.
* `dt_read_txt()` Fast plain text importing into MATA.
* `dt_stata_path()` Retriving stata's exe path.
* `dt_capture()` Capturing a MATA function.
* `dt_getchars()` Retrieving Stata characteristics as associative arrray.
* `dt_setchars()` Set Stata characteristics from associative array.
* `dt_vlasarray()` Stata value label <-> Mata associative array.
* `dt_git_install()` Install a stata pkg from a git repo.
* `dt_list_files()` List files recursively.
* `dt_create_pkg()` Create a pkg file.
* `dt_shell_return()` A wrapper of `shell` which retrives OS cmdline exit status.
* `dt_rename_file()` Rename a file through OS cmdline.

Plus a set of functions to build and call modules' (packages') demos!
## Installation
For installing from Stata version \>=13

``` stata
. net install devtools, from(https://raw.github.com/gvegayon/devtools/master/) replace
. mata mata mlib index
```

For Stata version \<12, download as zip, unzip, and then replace the above -net install- with

``` stata
. net install devtools, from(full_local_path_to_files) replace
```

For earlier versions of Stata, you will have to download the package and build it (run `build_devtools.do`) and then install from the directory.


## Authors
George Vega (g dot vegayon at gmail dot com)

James Fiedler (jrfiedler at gmail dot com)

