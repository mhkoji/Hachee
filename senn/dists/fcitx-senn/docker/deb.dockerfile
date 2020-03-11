FROM debian:stretch

RUN apt update && apt install -y \
    wget \
    build-essential \
    cmake \
    sbcl \
    fcitx-libs-dev

RUN mkdir \
    /app \
    /build \
    /output \
    /output-build

RUN cd /build && \
    wget https://beta.quicklisp.org/quicklisp.lisp && \
    sbcl --noinform \
         --no-userinit \
         --no-sysinit \
         --non-interactive \
         --load /build/quicklisp.lisp \
         --eval "(quicklisp-quickstart:install)"

COPY . /app
RUN cd /root/quicklisp/local-projects && \
    ln -s /app/hachee/ && \
    ln -s /app/senn/

WORKDIR /output-build
CMD ["/app/senn/dists/fcitx-senn/docker/deb.sh"]
