# 외부 오픈소스 이미지 보안 정책 — 발췌

> 원문: [12.2.2 외부 오픈소스 이미지 보안 정책](https://wiki.navercorp.com/spaces/KSAAPP/pages/5390619759) (KSAAPP)
> 사내에서 직접 개발·빌드하는 이미지는 별도 정책 (12.2.1 사내 개발 이미지 보안 정책) 을 따른다.
> 이 파일은 발췌본이다. 정책 충돌 시 위키 원문이 우선한다.

## 기본 원칙

1. 외부 이미지(Docker Hub 등 사외 저장소)는 **직접 사용 금지**. OCIR 에 등록된 이미지만 사용 가능.
2. 외부 이미지가 필요하면 **허용된 BaseImage 로 변경(래핑)** 후 사용.
3. BaseImage 변경이 불가능한 사외 이미지는 **예외 whitelist** 처리 대상.
4. 예외 승인을 받은 이미지도 외부 저장소에서 직접 pull 금지 — **OCIR 로 복제 후 사용**.

## 래핑용 BaseImage

| 구분 | BaseImage | 비고 |
|---|---|---|
| OCI 제공 navix | `me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/navix:10.1-wasl-centos` | WASL 팀 제공 (OCIR), RHEL/centos 계열 |
| OCI 제공 ubuntu | `me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04` | WASL 팀 제공 (OCIR), debian/ubuntu 계열 |
| OCI 제공 alpine | `me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23` | WASL 팀 제공 (OCIR), alpine(musl) 계열 |
| naver 사내 BaseImage | `reg.navercorp.com/base/...` | 비권장 |

> 원본 이미지와 같은 계열의 base 를 선택한다 (alpine→alpine, debian/ubuntu→ubuntu, RHEL 파생→navix).
> 표준 태그: alpine `3.23` / ubuntu `24.04` / navix `10.1-wasl-centos` (위키 12.2.2 v6 와 동기화됨).

### naver 사내 BaseImage 로 래핑하지 않는 이유

- 사내 BaseImage 래핑 시 **네이버 사내 보안검수 통과 허들**이 추가로 생긴다.
- 사내 BaseImage 에는 사내 개발환경 정보가 포함될 수 있어 **외부 반출 보안 검수 시 challenge 대상**이 될 수 있다.

## 사용 절차 (요약)

1. BaseImage 변경 가능 여부 확인
   - 변경 가능 → Dockerfile FROM 을 계열에 맞는 허용 BaseImage(navix/ubuntu/alpine)로 교체해 래핑
   - 변경 불가 → 예외 whitelist 처리 요청
2. 이미지를 OCIR 에 push — **순수 외부 이미지는 n3r registry 를 경유하지 않는다** (WASL-IMAGE-Copier 는 사내 n3r 이미지의 OCIR 복제 용도)
3. 클라우드 이미지 보안 검수를 거쳐 사용

## 예외 whitelist 검수 기준

| 단계 | 항목 | 기준 |
|---|---|---|
| 1차 검수 | 취약성 체크 | Critical CVE 없어야 함 |
| 1차 검수 | 바이러스 탐지 체크 | 바이러스 의심 없어야 함 |
| 2차 승인 | 보안책임자 승인 | KSA 보안책임자 승인 |

## 허용/차단 케이스

| 구분 | 케이스 |
|---|---|
| ✅ 허용 | 허용 BaseImage(navix/ubuntu/alpine) 래핑 후 OCIR push + 검수 통과 / 예외 whitelist 승인된 사외 이미지 / 보안검수 받고 반출된 naver base 기반 래핑 이미지 |
| 🚫 차단 | 외부 저장소(Docker Hub 등) 직접 pull·배포 / 검수 미통과 이미지 / Critical CVE 보유 이미지 |

## FAQ

- **외부 오픈소스 이미지(예: Kafbat, Airflow)를 바로 사용할 수 있나요?**
  불가. 계열에 맞는 허용 BaseImage(navix/ubuntu/alpine)로 래핑 후 OCIR push → 검수 후 사용. 순수 외부 이미지는 n3r 경유 없이 OCIR 직접 push.
- **BaseImage 변경이 불가능한 사외 이미지는?**
  예외 whitelist 대상. 1차 검수(취약성·바이러스) + 2차 승인(보안책임자) 후 OCIR 복제하여 사용.

## 참고 문서 (위키)

- 12.2 개발 보안 / 12.2.1 사내 개발 이미지 보안 정책 / BaseImage 보안 가이드
- 01. 외부이미지 예외 요청 가이드 (SECURITYGUIDE — 사내 N3R 기준)
- GHES Discussion #886 — OCI 사용 문의 (외부 이미지 정책)
