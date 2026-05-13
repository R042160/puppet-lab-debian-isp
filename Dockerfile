FROM debian:12-slim

# Install puppet 8 from apt.puppet.com
RUN apt-get update && apt-get install -y --no-install-recommends \
      wget ca-certificates gnupg lsb-release \
 && wget -qO /tmp/puppet-release.deb \
      https://apt.puppet.com/puppet8-release-bookworm.deb \
 && dpkg -i /tmp/puppet-release.deb \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      puppet-agent \
      systemctl \
      procps \
      curl \
      dnsutils \
 && rm -f /tmp/puppet-release.deb

ENV PATH="/opt/puppetlabs/bin:${PATH}"

WORKDIR /lab
COPY manifests/ /lab/manifests/
COPY modules/   /lab/modules/
COPY hiera.yaml /lab/hiera.yaml
COPY data/      /lab/data/

CMD ["bash", "-c", "tail -f /dev/null"]
