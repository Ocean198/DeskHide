# Security Policy

## Supported versions

Security fixes go into the latest release only. Please update before reporting a problem.

## Reporting a vulnerability

Please do not open a public issue for a security problem. Report it privately instead:

- by email to github@design-chirurgen.com, or
- with "Report a vulnerability" under the Security tab of this repository.

Include the DeskHide and macOS versions and the steps to reproduce. You will get a reply as soon as
possible.

## What DeskHide does and does not do

Knowing the scope helps to judge a finding:

- DeskHide runs as an ordinary app without elevated privileges, needs no permissions and makes no
  network connections.
- It only ever writes settings: its own, the desktop switches of macOS and Finder's `CreateDesktop`.
  It never touches files.
- Releases are signed with a Developer ID, use the hardened runtime and are notarized by Apple. A
  download that macOS does not accept as notarized did not come from this repository.
