FROM archlinux
RUN pacman -Sy --noconfirm && \
    --needed sudo curl bash
RUN groupadd sudo && echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers && \
    useradd -m -s $(which bash) -G sudo user
USER user
RUN mkdir -p /tmp && \
    mkdir -p /tmp/build_cache && \
    curl -fsSL raw.github.com/chris85618/My-Dotfile/master/INSTALL > /tmp/install.sh && \
    yes | BUILDDIR=/tmp/build_cache sh /tmp/install.sh && \
    rm -rf /tmp
CMD bash
