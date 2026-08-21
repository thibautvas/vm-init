# vm-init

## Distributions

### debian

```bash
setparams 'Install'

    set background_color=black
    linux    /install.amd/vmlinuz vga=788 --- quiet \
                                              auto=true \
                                              hostname=debian \
                                              domain='' \
                                              url=https://raw.githubusercontent.com/thibautvas/vm-init/main/debian/preseed.cfg
    initrd   /install.amd/initrd.gz
```

### archlinux

```bash
archinstall --config-url https://raw.githubusercontent.com/thibautvas/vm-init/main/archlinux/user_configuration.json \
            --silent
```

Note: if the iso is outdated archlinux-keyring might need to be updated, in that case:

```bash
curl -fsSL https://raw.githubusercontent.com/thibautvas/vm-init/main/archlinux/setup.sh | bash
```

### alpinelinux

```bash
setup-alpine -e -f https://raw.githubusercontent.com/thibautvas/vm-init/main/alpinelinux/setup-alpine.conf
```

### nixos

Seperate repo to avoid flake headaches: [nixos-vm](https://github.com/thibautvas/nixos-vm)
