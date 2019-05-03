FROM ubuntu:18.04

# Set the locale
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y locales \
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && update-locale LANG=en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# Install openssl for Elixir
RUN apt-get install -y libssl1.0.0

COPY backend/_build/prod/rel/backend /backend

CMD /backend/bin/backend foreground
