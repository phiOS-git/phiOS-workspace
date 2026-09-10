# phiOS workspace

Monorepo-style workspace that ties together the phiOS components via git
submodules.

## Repositories

| Submodule | Description |
| --- | --- |
| [phi](phi) | Core OS: kernel config, firewall, and system-level services. |
| [phi-shell](phi-shell) | Desktop shell, QML on Quickshell. |
| [phi-packages](phi-packages) | PKGBUILDs and build scripts for every own package. |
| [phios-dotfiles](phios-dotfiles) | Personal Arch Linux configuration across three hosts. |

## Setup

```sh
git submodule update --init --recursive
```