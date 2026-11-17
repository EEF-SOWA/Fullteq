# Fullteq 코드 리뷰 — EQP-1A 모델링 플러그인 (JUCE 8.0.6)

- 검토 대상: commit `faac7f6` 기반 + 2026-11-18 수정 반영 (아래 §6), working tree clean
- 검토일: 2026-11-18
- 이전 리뷰: commit `1f0af44` 기준 (2026-11-11) → 그 이후 `29fd2b9`, `2062456`, `faac7f6`에서 다수 수정됨. 본 문서는 현재 상태 기준으로 재작성.
- 검증 방법: 전 소스 정독 + `FullteqTests` 릴리즈 재빌드/실행 + `--sweep`/`--diag` 수집 + `-Wall -Wextra -Wunused-private-field` 구문 검사 + `auval` + `pluginval` strictness 10

## 0. 검증 결과 요약 (실측)

| 항목 | 결과 | 이전 리뷰 대비 |
|---|---|---|
| `FullteqTests` 재빌드 | 성공 (Release) | — |
| DSP 테스트 | **17그룹 전부 통과 (0 failures)** | 16 → 17 |
| `--diag` (13 kHz 앨리어싱) | amp 0.5 → -68.3 dB / **amp 0.8 → -67.7 dB** | amp 0.8: -47.6 → **-67.7 dB (해결)** |
| 엄격 경고 컴파일 | **경고 0건** | 1건(`shapeRateCoeff`) → 0 (해결) |
| `auval -v aufx Fteq EEFL` | **PASS** | 유지 |
| `pluginval` strictness 10 (VST3) | **SUCCESS** | 미실시 → 통과 (해결) |
| 바이너리 아키텍처 | VST3/AU 모두 **Universal 2** (arm64 + x86_64) | arm64 전용 → 해결 |
| `--sweep` 60 Hz 8/8 | 20 Hz -2.13 / 60 Hz -1.93 / 1 kHz -2.16 dB | 변경 없음 (§2.1) |

전반 평가: 이전 리뷰의 P1 실시간 안전성·스무딩 이슈와 문서 정합성 문제가 실제로 수정되어 재검증까지 끝났다. 남은 항목은 ** 죽은 상수 1개, 하드코딩 결합 2곳, 미결 설계 결정 1건(저역 trick 방향), 사소한 정리**뿐이다.

---

## 1. 이전 리뷰에서 해결된 항목 (재검증 완료)

| 이전 항목 | 현재 상태 |
|---|---|
| §1.1 오디오 스레드 힙 할당 (`resizeScratch`, `makeCopyOf`) | `resizeScratch` 인라인화, `dryBuffer` 준비 시점 확보 + `releaseResources`에서 보존, 32샘플 서브블록 처리. 테스트 9/17이 큰 블록·해제 후 처리를 고정. |
| §1.2 계수 스무딩 블록 양자화 | `controlSubBlockSize = 32` 서브블록 + 13개 `SmoothedValue`, 램프는 샘플 단위 `getNextValue`. |
| §1.3 셀렉터 디클릭 없음 | `lowFreqHzSmoothed`/`highFreqHzSmoothed`/`attenFreqHzSmoothed` 추가(15 ms). |
| §1.4 트랜스포머 구동 계수 즉시 반영 | `coreDrive`/`coreBias`를 스무딩된 `driveRamp`/`lowBoostDb`에서 도출. |
| §1.5 핫 입력 앨리어싱 -47.6 dB | ADAA1 셰이퍼 도입으로 amp 0.8도 -67.7 dB. 테스트 6이 두 케이스 모두 단언. |
| §2.2 없는 문서 인용 | 소스·테스트의 `IMPROVEMENT_NOTES_sound_quality_ref.md` 참조 제거, `IMPROVEMENT_PLAN.md`를 EON wiki 가이드로 정리. |
| §2.3 프리셋 상태 추적 | `parameterChanged`가 `-1(커스텀)` 무효화, 상태 XML에 `preset` 속성 저장/복원, 콤보박스 `(custom)` 표시. 테스트 10 검증. |
| §2.4 `currentSampleRate` 레이스 | `std::atomic<double>` 전환. |
| §2.6 죽은 코드 | `JilesAtherton.h` 삭제, `shapeRateCoeff`·`NonlinearState.core/envelope/prev`·`kLowBoostCornerRatio` 제거, 중복 주석 정리. |
| §2.7 테스트 구멍 | 테스트 14 실질 단언(`rel > -20`), 테스트 6 amp 0.8 추가, 번호 순서 정리(1~17). |
| §3 CMake/빌드 | 두 타깃 모두 권고 경고 플래그, `FULLTEQ_INSTALL_PLUGINS` 옵트인, Universal 2, README.md 추가, 리사이즈 UI, IN/POWER 분리 + 툴팁, `getTailLengthSeconds = 0.05`. |

---

## 2. 발견 및 처리 상태

### 2.1 설계 미결 — 저역 "Pultec trick" 방향 (사용자 결정: 현재 유지)

- `IMPROVEMENT_PLAN.md`의 Phase 1 **완료 기술**은 구현을 정확히 반영한다: "60 Hz·8/8 트릭에서 20~60 Hz -2 dB·300 Hz +0.6 dB". 문서-구현 불일치는 아니다.
- Phase 1 **목표**("60Hz 이하만 리프트")와 실제 곡선은 반대다. 실측 60 Hz 8/8: 20 Hz **-2.13**, 300 Hz +0.61, 1 kHz -2.16 dB. 부스트 코너 700 Hz 고정 vs 컷 코너 560 Hz(60 Hz dial)라 겹치는 영역에서 컷이 우세하다.
- 테스트 3도 구현에 맞춰 "the 8/8 trick pulls the sub down"을 단언한다(DspTests.cpp:232).
- **처리**: 2026-11-18 사용자 확인으로 **측정 테이블 모델 유지** 결정. DSP 변경 없음. 향후 하드웨어 서명이 필요해지면 셸프 배치 + 테스트 3 + 문서를 함께 재설계할 것.

### 2.2~2.4, 2.5(1·2) — 수정 완료 (2026-11-18)

| 항목 | 조치 |
|---|---|
| §2.2 죽은 상수 | `kCoreDriveScale` 삭제. |
| §2.3 하드코딩 결합 | `kFullScaleDb = 8.0`, `kDefaultDrive = 0.15f` 신설 후 `cutGain`·`liftDb`·drive 파라미터·코어 앵커에 적용. 캘리브레이션 리터럴과 에디터 좌표는 의도적으로 유지. |
| §2.4 KISS | `coreDrive`/`coreBias`를 클래스 멤버에서 서브블록 `const` 로컬로 전환(상태 2개 제거). |
| §2.5-1 `changeProgramName` | factory 프리셋임을 명시하는 주석 추가(의도적 no-op). |
| §2.5-2 스냅샷 안전장치 | `--snapshot` 출력 경로가 `.png`가 아니면 거부. |

- 재검증: 17그룹 전부 통과, 경고 0건, pluginval strictness 10 SUCCESS. DSP 출력은 상수 통합 전후 동일(`liftDb`/`cutGain` 수식 동치).

### 2.5 나머지 사소 항목 (P3, 미수정)

1. LICENSE — 해결. AGPLv3로 배포하고 JUCE 8 AGPL 사용, Jost는 OFL 1.1. `LICENSE`와 `THIRD_PARTY_NOTICES.md` 추가.
2. `getResponseDb`는 패시브 네트워크만 계산 — 툴팁을 "Passive EQ network response"로 정정해 오해는 줄었지만, 튜브·트랜스·트림을 포함한 실제 응답과는 여전히 다름(테스트 7/12: 50 Hz +0.46~+0.9 dB, 4 kHz -0.15~-1.6 dB).
3. `clampFrequency` 상한 0.45×fs로 44.1 kHz에서 그래프의 20 kHz 지점은 19.845 kHz 값(`PluginProcessor.cpp:21`).

---

## 3. 잘 된 점 (사실 기반, 재검증)

- NaN/Inf 입력 살균 + pluginval 퍼즈 통과, `ScopedNoDenormals`, double 정밀 TDF2 상태.
- dry 지연 라인으로 바이패스 정렬 + 지연 보고 일관성(테스트 8: 48 kHz latency 6 samples, err < 1e-6).
- ADAA1 셰이퍼로 앨리어싱을 amp 0.8에서도 -67 dB 이하로 억제.
- 응답 해석식 vs 실측 ±0.25 dB 검증이 여러 밴드에 배치, 멀티레이트(44.1/96/192 kHz) 테스트.
- 상태 라운드트립(스텝 1.0 float), 프리셋 커스텀 무효화, pluginval strictness 10 SUCCESS.
- `auval` PASS, 경고 0건, Universal 2 바이너리.

## 4. UI/UX 개선 (2026-11-18 적용)

- 11개 노브 모두에 툴팁 + 접근성 제목 추가 (`knobTooltip()`). 패널이 저역/고역에 "BOOST"/"ATTEN"을 중복 표기하므로 밴드와 주파수 소스를 명시: 예) "LOW BOOST — wide low shelf, fixed 700 Hz corner (dB)", "CPS — low-frequency dial (20/30/60/100 Hz)".
- 프리셋 콤보박스·`<`/`>` 버튼에도 툴팁/제목 추가. 콤보박스는 "선택 시 모든 노브 값이 교체됨"을 명시.
- 기존 더블클릭 기본값 복귀, 팝업 값 표시, 리사이즈 + 종횡비 고정은 유지.
- `--snapshot`으로 렌더링 확인: 2280×760, 컨트롤 겹침·잘림 없음.

## 5. 권장 조치 순서

1. LICENSE 결정 — 완료(AGPLv3).
2. 원하면 Phase 1 목표 문구를 현재 측정 모델에 맞게 정정(사운드 변경 없이 문서만).
3. 실 DAW 로드/청감 비교(유일하게 남은 큰 미검증).

## 6. 미검증 항목

- 실 DAW 로드: Ableton Live 12.4.6에서 VST3/AU 로드·파라미터·오디오 확인. 자동화/저장 재개, 청감 비교, 88.2 kHz, LV2/AAX(타깃 아님)는 미검증. AU pluginval은 VST3만 실행 — AU는 `auval` PASS로 대체.

## 7. 변경 이력 (2026-11-18)

- `Source/PluginProcessor.h`: `kCoreDriveScale` 삭제, `kFullScaleDb`/`kDefaultDrive` 신설, `coreDrive`/`coreBias` 멤버 제거.
- `Source/PluginProcessor.cpp`: 상수 통합, 로컬화, `changeProgramName` 주석.
- `Source/PluginEditor.cpp`: `knobTooltip()` + 11노브·프리셋 컨트롤 툴팁/접근성 제목, `<cstring>` 포함.
- `Tests/DspTests.cpp`: `--snapshot` 경로 `.png` 검증.
- 검증: FullteqTests/VST3/AU 빌드 성공, 17그룹 ALL PASSED, 경고 0건, pluginval strictness 10 SUCCESS, 스냅샷 렌더 정상.
