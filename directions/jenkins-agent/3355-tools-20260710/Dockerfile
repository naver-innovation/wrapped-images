FROM me-riyadh-1.ocir.io/axlo4g31gl45/docker.io/amazon/aws-cli:2.15.30 AS aws-cli

FROM me-riyadh-1.ocir.io/axlo4g31gl45/docker.io/jenkins/inbound-agent:3355.v388858a_47b_33-18

USER root

RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        docker.io \
        util-linux; \
    rm -rf /var/lib/apt/lists/*

COPY --from=aws-cli /usr/local/aws-cli/ /usr/local/aws-cli/
COPY --from=aws-cli /usr/local/bin/aws /usr/local/bin/aws
COPY --from=aws-cli /usr/local/bin/aws_completer /usr/local/bin/aws_completer

COPY jenkins-agent-with-docker /usr/local/bin/jenkins-agent-with-docker
RUN chmod 0755 /usr/local/bin/jenkins-agent-with-docker

ENTRYPOINT ["/usr/local/bin/jenkins-agent-with-docker"]
