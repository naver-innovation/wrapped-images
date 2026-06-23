#
# Apache Spark 4.0.1 (scala2.13-java17-python3-ubuntu) — WASL OCIR wrap.
#
# 원본: docker.io/spark:4.0.1-scala2.13-java17-python3-ubuntu
#   (apache/spark-docker, FROM spark:4.0.1-scala2.13-java17-ubuntu + python3)
# 변경점: FROM 을 OCIR 에 래핑된 base(위 ubuntu wrap)로 교체. 나머지(python3 설치)는 원본 그대로.
#
FROM me-riyadh-1.ocir.io/axlo4g31gl45/docker.io/spark:4.0.1-scala2.13-java17-ubuntu

USER root

RUN set -ex; \
    apt-get update; \
    apt-get install -y python3 python3-pip; \
    rm -rf /var/lib/apt/lists/*

USER spark
