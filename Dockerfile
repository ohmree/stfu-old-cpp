FROM archlinux:base-devel
LABEL authors="Me :)"

# Use faster mirror to speed up the image build
RUN echo 'Server = https://mirror.pkgbuild.com/$repo/os/$arch' > /etc/pacman.d/mirrorlist

# Base installation
RUN pacman -Syyu --noconfirm --noprogressbar

# Add user, group sudo
RUN /usr/sbin/groupadd --system sudo && \
    /usr/sbin/useradd -m --groups sudo user && \
    /usr/sbin/sed -i -e "s/Defaults    requiretty.*/ #Defaults    requiretty/g" /etc/sudoers && \
    /usr/sbin/echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Install paru
ENV paru_version=v1.9.0
ENV paru_folder=paru-${paru_version}-x86_64
RUN cd /tmp && \
    curl -L https://github.com/Morganamilo/paru/releases/download/${paru_version}/${paru_folder}.tar.zst | tar x --zstd && \
    install -Dm755 paru /usr/bin/paru && \
    install -Dm644 paru.conf /etc/paru.conf

# Set correct locale
RUN echo "LC_ALL=en_US.UTF-8" >> /etc/environment && \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
RUN locale-gen en_US.UTF-8
ENV LC_CTYPE 'en_US.UTF-8'

COPY --chown=user . /app/

USER user
WORKDIR /app

RUN cd pkgbuilds/qt5-jsonserializer-minimal && \
    makepkg --needed --noconfirm --noprogressbar --nocheck -sCci
RUN paru -Syu --needed --noconfirm --noprogressbar --nocheck qdep xmake cmake p7zip
RUN cd pkgbuilds/qt5-restclient-minimal && \
    makepkg --needed --noconfirm --noprogressbar --nocheck -sCci

RUN xmake repo --update
