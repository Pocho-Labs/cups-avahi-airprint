FROM alpine:3.20

# Install required packages
RUN echo -e "https://dl-cdn.alpinelinux.org/alpine/edge/testing\nhttps://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    apk add --update \
        cups \
        cups-libs \
        cups-pdf \
        cups-client \
        cups-filters \
        cups-dev \
        ghostscript \
        hplip \
        avahi \
        dbus \
        inotify-tools \
        python3 \
        build-base \
        wget \
        perl \
        splix \
    && rm -rf /var/cache/apk/*

# Build and install brlaser from source (Brother laser printers)
RUN apk add --no-cache git cmake && \
    git clone https://github.com/pdewacht/brlaser.git && \
    cd brlaser && \
    cmake -DCMAKE_POLICY_VERSION_MINIMUM=3.5 . && \
    make && \
    make install && \
    cd .. && \
    rm -rf brlaser

# Build and install gutenprint from source (Epson, Canon and others)
RUN wget -O gutenprint-5.3.5.tar.xz https://sourceforge.net/projects/gimp-print/files/gutenprint-5.3/5.3.5/gutenprint-5.3.5.tar.xz/download && \
    tar -xJf gutenprint-5.3.5.tar.xz && \
    cd gutenprint-5.3.5 && \
    find src/testpattern -type f -exec sed -i 's/\bPAGESIZE\b/GPT_PAGESIZE/g' {} + && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf gutenprint-5.3.5 gutenprint-5.3.5.tar.xz && \
    sed -i '1s|.*|#!/usr/bin/perl|' /usr/sbin/cups-genppdupdate

# Build and install foo2zjs from source (HP LaserJet P1005, P1006, P1505, and other ZJS printers)
RUN cd /tmp && \
    wget -q https://foo2zjs.linkevich.net/foo2zjs/foo2zjs.tar.gz && \
    tar xzf foo2zjs.tar.gz && \
    cd /tmp/foo2zjs && \
    make && \
    make install && \
    rm -rf /tmp/foo2zjs*

EXPOSE 631
VOLUME /config

ADD root /
RUN chmod +x /root/*

# cupsd.conf is provided via ADD root / above (root/etc/cups/cupsd.conf)
# Only Avahi config needs patching
RUN sed -i 's/.*enable-dbus=.*/enable-dbus=yes/' /etc/avahi/avahi-daemon.conf

CMD ["/root/run_cups.sh"]
