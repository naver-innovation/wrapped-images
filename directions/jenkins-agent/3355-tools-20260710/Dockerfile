FROM me-riyadh-1.ocir.io/axlo4g31gl45/docker.io/amazon/aws-cli:2.15.30 AS aws-cli

FROM me-riyadh-1.ocir.io/axlo4g31gl45/docker.io/jenkins/inbound-agent:3355.v388858a_47b_33-18

USER root

RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        docker.io \
        python3.12 \
        python3.12-venv \
        util-linux; \
    rm -rf /var/lib/apt/lists/*

COPY --from=aws-cli /usr/local/aws-cli/ /usr/local/aws-cli/
RUN set -eux; \
    ln -s /usr/local/aws-cli/v2/current/bin/aws /usr/local/bin/aws; \
    ln -s /usr/local/aws-cli/v2/current/bin/aws_completer /usr/local/bin/aws_completer; \
    python3 --version; \
    aws --version

COPY jenkins-agent-with-docker /usr/local/bin/jenkins-agent-with-docker
RUN chmod 0755 /usr/local/bin/jenkins-agent-with-docker

ENTRYPOINT ["/usr/local/bin/jenkins-agent-with-docker"]
