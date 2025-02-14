
# WinGet MSIX

A WinGet repository that mirrors [winget-pkgs][1]
but releases the packages using MSIX.

## Why?

MSIX applications have benefits over standard application installations:

1. Clean uninstalls

Applications installed using MSIX always properly remove user data when uninstalled.
Many times files in `%APPDATA%` and `%LOCALAPPDATA%` are not removed,
which can clutter the file system and retain useless or sensitive information.
MSIX also prevents changes to the registry which can be even harder to maintain.

2. Normalized Installation Locations

Some applications use confusing installation paths.
An app packaged with MSIX centralizes all the directories associated with the app:

`%ProgramFiles%\WindowsApps\<package_name>`: The installation directories, normally read-only
`%LocalAppData%\Packages\<package_name>`: User data

3. AppContainer Integration

Most applications do not do any form of sandboxing, which is not ideal.
Packaged applications require explicit user consent for certain actions, such as getting location information.
Some of the applications packaged in this repository are given even more limited capabilities.

# Code Signing

All the packages will be signed during GitHub actions for transparency.
This has not been done yet.

# Template Files

The template files are built on top of the Sample Template found [here][2], which is modified for the signing requirements.

[1]: https://github.com/microsoft/winget-pkgs
[2]: https://learn.microsoft.com/en-us/windows/msix/packaging-tool/generate-template-file#sample-conversion-template-file
