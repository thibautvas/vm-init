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
                                              url=https://raw.githubusercontent.com/thibautvas/vm-init/refs/heads/main/debian/preseed.cfg
    initrd   /install.amd/initrd.gz
```

### archlinux

```bash
archinstall --config-url https://raw.githubusercontent.com/thibautvas/vm-init/refs/heads/main/archlinux/user_configuration.json \
            --creds-url https://raw.githubusercontent.com/thibautvas/vm-init/refs/heads/main/archlinux/user_credentials.json \
            --silent
```

## Project structure

```text
.
├── .gitignore
├── README.md
├── archlinux
│   ├── user_configuration.json
│   └── user_credentials.json
├── debian
│   └── preseed.cfg
└── setup.sh

3 directories, 6 files
```
