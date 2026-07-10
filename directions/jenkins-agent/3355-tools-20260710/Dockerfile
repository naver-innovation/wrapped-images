FROM me-riyadh-1.ocir.io/axlo4g31gl45/docker.io/jenkins/inbound-agent:3355.v388858a_47b_33-18

USER root

RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        awscli \
        docker.io \
        util-linux; \
    rm -rf /var/lib/apt/lists/*

COPY jenkins-agent-with-docker /usr/local/bin/jenkins-agent-with-docker
RUN chmod 0755 /usr/local/bin/jenkins-agent-with-docker

ENTRYPOINT ["/usr/local/bin/jenkins-agent-with-docker"]
