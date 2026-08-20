# 승인 외부 이미지 관리대장 (Whitelist)

허용 BaseImage 로 래핑(교체)이 불가능해 **예외 승인**을 받은 외부 이미지의 대장입니다.
PE 팀이 관리하며, 신규 승인 건이 생기면 이 파일에 PR 로 추가합니다.

> 근거 정책: [외부 이미지 사용 보안정책 가이드 12.2.2](https://wiki.navercorp.com/x/b1ROQQE)
> · [WS.OCI 외부 base 이미지 예외 등록 가이드](https://wiki.navercorp.com/x/KonVUQE)

## 1. 운영 원칙

[#2663 (comment 142622)](https://oss.navercorp.com/wasl/wasl-oci-support/discussions/2663#discussioncomment-142622) 에서 정리한 원칙:

- **shared compartment**: wrapped-images(이 repo) CI 산출물 전용. push 는 PE/CI 로 한정.
- **whitelist 승인 외부 이미지**: 승인받은 팀이 **자기 서비스 compartment 에서 직접 관리**.
- **whitelist 목록은 PE 팀이 대장(이 파일)으로 관리**: 이미지명 / digest / 승인 discussion / 복제 위치를 등록.
- 추후 필요 시 해당 repo 를 shared 로 **compartment 이동**시켜 승격.

## 2. 승인 이미지 목록

레지스트리 호스트는 모두 `me-riyadh-1.ocir.io/axlo4g31gl45` 입니다. 아래 표의 복제 경로는 그 뒤의 repository 경로만 표기합니다.

### [#2301](https://oss.navercorp.com/wasl/wasl-oci-support/discussions/2301) — GPU 추론 서빙 (wasl-search) · 승인 2026-08-06 (sungkwan-kim)

| 원본 이미지 | 승인 digest (amd64) | 복제 경로 (OCIR) | compartment | 용도 / 사용 형태 |
|---|---|---|---|---|
| `nvcr.io/nvidia/tritonserver:26.01-py3` | `sha256:c9f2ede50ccc4a3ce66e22e26ed1b5adc0c68516b58edfaca738693719c2146b` | `nvcr.io/nvidia/tritonserver:26.01-py3` | `shared` | GPU 추론 서빙 (siglip2 / bge-m3 / llu-ar). Critical CVE 조치 레이어를 얹은 파생 이미지로 사용 |
| `ghcr.io/ggml-org/llama.cpp:server-cuda` | `sha256:8d9129ac859493c23e0db914c6940a729a33d6fe42d9e5ec9ee8a5c667f10e7a` (승인 핀, amd64 변형 사용) | `ghcr.io/ggml-org/llama.cpp:server-cuda` | `shared` | LLM Translate API — Gemma4-26B(4bit GGUF) llama-server 호스팅. 원본 그대로 사용 |

> 비고: 이 건은 §1 원칙 정립(2026-08-19) 이전에 PE 가 skopeo 로 shared 에 복제한 케이스.
> 원칙대로라면 서비스 compartment 관리 대상이므로, 추후 compartment 이동 여부 검토 필요.

### [#2663](https://oss.navercorp.com/wasl/wasl-oci-support/discussions/2663) — prod OpenSearch (prod-search-svc-OKE-001-ruh) · 승인 2026-08-20 (sungkwan-kim)

복제 완료 보고: [#2663 (comment 142845)](https://oss.navercorp.com/wasl/wasl-oci-support/discussions/2663#discussioncomment-142845)

| 원본 이미지 | 승인 digest (amd64) | 복제 경로 (OCIR) | compartment | 용도 / 사용 형태 |
|---|---|---|---|---|
| `docker.io/opensearchproject/opensearch:3.8.0` | `sha256:39a8f8c63028e8b5d6b70539af1d0339b15a6729002dd5b3f4a65f520376fd30` | `docker.io/opensearchproject/opensearch:3.8.0` | `prod-search-svc` | OpenSearch 노드. 이 base 위에 Linguist2 한국어 분석 플러그인 파생 이미지 빌드 |
| `docker.io/opensearchproject/opensearch-dashboards:3.8.0` | `sha256:803638a32d12d585d705cdb623948614d748dda9356a4565c8745fe125077777` | `docker.io/opensearchproject/opensearch-dashboards:3.8.0` | `prod-search-svc` | OpenSearch Dashboards. k8s Operator 가 클러스터와 함께 배포 |
| `gcr.io/distroless/static:nonroot` | `sha256:23795be0fe67b7d47d1ee62b19c7db750152db627d5bbfa31307e892a7575bec` | `gcr.io/distroless/static:nonroot` | `prod-search-svc` | 자체 빌드 opensearch-operator 이미지의 런타임 base |

## 3. compartment 배치 현황

| compartment | 내용 | push 주체 |
|---|---|---|
| `shared` | wrapped-images(이 repo) CI 산출물 — `<registry>/<org>/<image>:<tag>` 규칙으로 push 되는 래핑 이미지 전체 | PE / CI (`build-and-push-image.yml`) |
| `shared` | #2301 whitelist 이미지 2종 (tritonserver, llama.cpp — 원칙 정립 이전 복제분) | PE (skopeo) |
| `prod-search-svc` | #2663 whitelist 이미지 3종 + 검색팀 자체 빌드 이미지 | 검색팀 (search-svc) |

### 참고 — whitelist 대상이 아닌 자체 빌드 이미지 (정책 12.2.1 3-1절 유형 A)

승인 discussion 스레드에서 함께 다뤄졌으나, 외부 이미지 예외가 아닌 **자체 빌드**로 분류된 이미지입니다. 각 팀 서비스 compartment 에서 관리합니다.

| 이미지 | compartment | 근거 |
|---|---|---|
| `opensearch/opensearch-operator` (2.8.0, 업스트림 소스 직접 빌드) | `prod-search-svc` | [#2663](https://oss.navercorp.com/wasl/wasl-oci-support/discussions/2663) |
| `opensearch/opensearch-linguist2` (opensearch 3.8.0 복제본 base 파생) | `prod-search-svc` | [#2663](https://oss.navercorp.com/wasl/wasl-oci-support/discussions/2663) |
| `opensearch/linguist2-dict-fetcher:oci-cli-3.90.3` (`baseimage/alpine:3.23` + oci-cli) | `prod-search-svc` | [#2663 (comment 142856)](https://oss.navercorp.com/wasl/wasl-oci-support/discussions/2663#discussioncomment-142856) — 현행 방식 유지 가능 확인 |

## 4. 등록 절차

1. 사용 팀이 [wasl-oci-support Discussion](https://oss.navercorp.com/wasl/wasl-oci-support/discussions) 으로 예외 등록 요청
   (래핑 불가 사유 + Trivy/ClamAV 1차 검수 결과 포함).
2. PE 팀 확인 → 보안책임자 승인 (해당 스레드에서 직접 멘션 요청).
3. 사용 팀이 승인 digest 그대로 **자기 서비스 compartment** 에 복제 후, repo 경로를 스레드에 공유.
4. PE 팀이 이 대장에 이미지명 / digest / 승인 discussion / 복제 위치 / compartment 를 등록 (PR).
