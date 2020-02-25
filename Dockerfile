# A reduced version of the AWS CodeBuild Ubuntu base, with added Cypress and missing Chrome packages.
# https://github.com/aws/aws-codebuild-docker-images/blob/master/ubuntu/standard/2.0/Dockerfile
# https://github.com/cypress-io/cypress-docker-images/blob/master/base/ubuntu16/Dockerfile
FROM ubuntu:18.04

# Utilities.
ENV DEBIAN_FRONTEND="noninteractive" \
    NODE_VERSION="10.16.2" \
    SRC_DIR="/usr/src"

RUN set -ex \
    && echo 'Acquire::CompressionTypes::Order:: "gz";' > /etc/apt/apt.conf.d/99use-gzip-compression \
    && apt-get update \
    && apt-get install -y --no-install-recommends apt-transport-https \
    && apt-get update \
    && apt-get install -y --no-install-recommends apt-utils software-properties-common \
    && apt-add-repository -y ppa:git-core/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends git=1:2.* openssh-client \
    && mkdir ~/.ssh \
    && touch ~/.ssh/known_hosts \
    && chmod 600 ~/.ssh/known_hosts \
    && apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    build-essential \
    bzip2 \
    ca-certificates \
    curl \
    dirmngr \
    dpkg-dev \
    e2fsprogs \
    expect \
    fakeroot \
    file \
    fonts-liberation \
    g++ \
    gcc \
    gettext \
    gettext-base \
    gnupg \
    groff \
    gzip \
    imagemagick \
    iptables \
    less \
    libappindicator3-1 \
    libapr1 \
    libaprutil1 \
    libasound2 \
    libbz2-dev \
    libc6-dev \
    libcurl4-openssl-dev \
    libdb-dev \
    libevent-dev \
    libffi-dev \
    libgconf-2-4 \
    libgeoip-dev \
    libglib2.0-dev \
    libjpeg-dev \
    libkrb5-dev \
    liblzma-dev \
    libncurses5-dev \
    libnss3 \
    libpq-dev \
    libreadline-dev \
    libssl-dev \
    libtool \
    libwebp-dev \
    libxml2-dev \
    libxml2-utils \
    libxrandr2 \
    libxslt1-dev \
    libxss1 \
    libxtst6 \
    locales \
    make \
    netbase \
    patch \
    procps \
    python-bzrlib \
    python-configobj \
    python3 \
    python3-dev \
    python3-pip \
    python3-setuptools \
    sgml-base \
    sgml-data \
    tar \
    unzip \
    wget \
    xdg-utils \
    xfsprogs \
    xml-core \
    xvfb \
    xz-utils \
    zip \
    zlib1g-dev \
    && apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# AWS CLI.
# https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_CLI_installation.html
RUN curl -sS -o /usr/local/bin/aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.11.5/2018-12-06/bin/linux/amd64/aws-iam-authenticator \
    && curl -sS -o /usr/local/bin/kubectl https://amazon-eks.s3-us-west-2.amazonaws.com/1.11.5/2018-12-06/bin/linux/amd64/kubectl \
    && curl -sS -o /usr/local/bin/ecs-cli https://s3.amazonaws.com/amazon-ecs-cli/ecs-cli-linux-amd64-latest \
    && chmod +x /usr/local/bin/kubectl /usr/local/bin/aws-iam-authenticator /usr/local/bin/ecs-cli

RUN set -ex \
    && pip3 install --upgrade setuptools wheel \
    && pip3 install awscli boto3

# Headless Chrome.
RUN set -ex \
    && curl --silent --show-error --location --fail --retry 3 --output /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && (dpkg -i /tmp/google-chrome-stable_current_amd64.deb || apt-get -fy install) \
    && rm -rf /tmp/google-chrome-stable_current_amd64.deb \
    && sed -i 's|HERE/chrome"|HERE/chrome" --disable-setuid-sandbox --no-sandbox|g' "/opt/google/chrome/google-chrome" \
    && google-chrome --version

# ChromeDriver.
RUN set -ex \
    && CHROME_VERSION=`google-chrome --version | awk -F '[ .]' '{print $3"."$4"."$5}'` \
    && CHROME_DRIVER_VERSION=`wget -qO- chromedriver.storage.googleapis.com/LATEST_RELEASE_$CHROME_VERSION` \
    && wget --no-verbose -O /tmp/chromedriver_linux64.zip https://chromedriver.storage.googleapis.com/$CHROME_DRIVER_VERSION/chromedriver_linux64.zip \
    && unzip /tmp/chromedriver_linux64.zip -d /opt \
    && rm /tmp/chromedriver_linux64.zip \
    && mv /opt/chromedriver /opt/chromedriver-$CHROME_DRIVER_VERSION \
    && chmod 755 /opt/chromedriver-$CHROME_DRIVER_VERSION \
    && ln -s /opt/chromedriver-$CHROME_DRIVER_VERSION /usr/bin/chromedriver \
    && chromedriver --version

# Node.js with Yarn and Cypress.
ENV N_SRC_DIR="$SRC_DIR/n"

RUN git clone https://github.com/tj/n $N_SRC_DIR \
    && cd $N_SRC_DIR && make install \
    && n $NODE_VERSION \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update && apt-get install -y --no-install-recommends yarn \
    && yarn global add cypress@4.0.2 --cache-folder ./ycache \
    && rm -rf ./ycache \
    && cd / && rm -rf $N_SRC_DIR
