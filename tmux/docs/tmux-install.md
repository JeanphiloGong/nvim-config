# tmux Install Notes

This page records the Linux source install path for tmux 3.6. Use the package
manager first when it provides a new enough tmux; use this path when the
server package is old.

## Dependencies

Ubuntu / Debian:

```sh
sudo apt update
sudo apt install -y build-essential pkg-config libevent-dev libncurses-dev bison
```

Fedora / RHEL / CentOS:

```sh
sudo dnf install -y gcc make pkgconf-pkg-config libevent-devel ncurses-devel bison
# Older systems may use yum:
# sudo yum install -y gcc make pkgconfig libevent-devel ncurses-devel bison
```

Arch:

```sh
sudo pacman -S --needed base-devel pkgconf libevent ncurses bison
```

## Build tmux 3.6

```sh
wget https://github.com/tmux/tmux/releases/download/3.6/tmux-3.6.tar.gz
tar -xzf tmux-3.6.tar.gz
cd tmux-3.6
./configure
make
sudo make install
```

Verify:

```sh
tmux -V
which tmux
```

Expected version:

```text
tmux 3.6
```

The install path is usually:

```text
/usr/local/bin/tmux
```

## Without sudo

Install under `$HOME/local`:

```sh
./configure --prefix="$HOME/local"
make
make install
```

Make sure `$HOME/local/bin` appears before the older system tmux in `PATH`.

## Related Docs

- tmux entrypoint: [../README.md](../README.md)
