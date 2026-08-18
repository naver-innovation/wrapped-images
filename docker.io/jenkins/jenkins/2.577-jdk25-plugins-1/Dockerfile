# 파생 이미지: 이 repo 의 2.577-jdk25 wrap + 플러그인 빌드 타임 베이크
# 원본(래핑 아님): me-riyadh-1.ocir.io/axlo4g31gl45/docker.io/jenkins/jenkins:2.577-jdk25
# 배경: directions-helmchart charts/infra/jenkins 는 additionalPlugins 런타임 다운로드로
#   부팅이 updates.jenkins.io egress 에 종속됐다. KR(mapRoute/charts jenkins,
#   mapRoute/directions-helmchart ADR-0023)과 동일하게 이미지 베이크로 정렬한다
#   (DIRECTIONS-4858). 플러그인 목록/버전은 같은 디렉토리의 plugins.txt 가 정본.
# 갱신: plugins.txt 를 바꿀 땐 새 태그 디렉토리(-2, -3 …)를 만든다 — 태그는 immutable,
#   push 빌드 트리거도 '**/Dockerfile' 경로만 본다.
FROM me-riyadh-1.ocir.io/axlo4g31gl45/docker.io/jenkins/jenkins:2.577-jdk25

# base 가 USER jenkins / REF(/usr/share/jenkins/ref) 소유권 jenkins 로 끝나므로 그대로 실행.
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --verbose -f /usr/share/jenkins/ref/plugins.txt
