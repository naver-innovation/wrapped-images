# 승인 외부 이미지 관리대장 (Whitelist)

허용 BaseImage 로 래핑이 불가능해 **예외 승인**을 받은 외부 이미지 대장입니다.
목록은 [`whitelist.csv`](whitelist.csv) 로 관리하며, 신규 승인 건은 PR 로 행을 추가합니다.

> 정책: [외부 이미지 사용 보안정책 12.2.2](https://wiki.navercorp.com/x/b1ROQQE) · [예외 등록 가이드](https://wiki.navercorp.com/x/KonVUQE)

## 컬럼

| 컬럼 | 내용 |
|---|---|
| `image` | 원본 이미지 (`<registry>/<org>/<image>:<tag>`) |
| `digest_amd64` | 승인받은 amd64 manifest digest |
| `ocir_repo` | 복제 위치 — `me-riyadh-1.ocir.io/axlo4g31gl45/` 뒤의 repository 경로 |
| `compartment` | 복제본이 위치한 OCI compartment |
| `approval_discussion` | 승인 discussion URL |
| `approved_date` | 보안책임자 승인일 (YYYY-MM-DD) |
| `usage` | 용도 / 사용 형태 |

## 운영 원칙 ([#2663 comment](https://oss.navercorp.com/wasl/wasl-oci-support/discussions/2663#discussioncomment-142622))

- **shared compartment**: wrapped-images CI 산출물 전용 (push 는 PE/CI 한정)
- **whitelist 승인 이미지**: 승인받은 팀이 **자기 서비스 compartment 에서 직접 관리**
- 대장은 PE 팀이 이 디렉터리로 관리, 필요 시 shared 로 compartment 이동 승격
- #2301 건 2종은 원칙 정립(2026-08-19) 이전에 shared 로 복제된 케이스 — 이동 여부 검토 대상

## 등록 절차

1. 사용 팀이 [wasl-oci-support Discussion](https://oss.navercorp.com/wasl/wasl-oci-support/discussions) 으로 예외 등록 요청 (래핑 불가 사유 + Trivy/ClamAV 검수 결과)
2. PE 팀 확인 → 보안책임자 승인
3. 사용 팀이 승인 digest 그대로 자기 서비스 compartment 에 복제 후 경로 공유
4. PE 팀이 `whitelist.csv` 에 등록 (PR)
