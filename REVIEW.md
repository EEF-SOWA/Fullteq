# Fullteq 코드 리뷰 — EQP-1A 모델링 플러그인 (JUCE 8.0.6)

- 검토 대상: commit `1f0af44` ("Update to measured low-band model, air shelf, iron core model and new panel UI"), working tree clean
- 검토일: 2026-11-11
- 검증 방법: 전 소스 정독 + `FullteqTests` 릴리즈 빌드/실행 + `--sweep`/`--diag` 데이터 수집 + `clang -Wall -Wextra -Wpedantic` 구문 검사 + `auval`/pluginval 시도

## 0. 검증 결과 요약

| 항목 | 결과 |
|---|---|
| `FullteqTests` 빌드 | 성공 (Release, 1s, 캐시) |
| DSP 테스트 16그룹 | **전부 통과 (0 failures)** |
| `--sweep` (저역 응답 매트릭스) | 수집 완료 — §2 참고 |
| `--diag` (13 kHz 앨리어싱) | amp 0.5 → -69.4 dB / amp **0.8 → -47.6 dB** |
| 엄격 경고 컴파일 (-Wall -Wextra -Wpedantic) | 경고 1건뿐 (`shapeRateCoeff` 미사용) — 매우 깨끗함 |
| `auval -v aufx Fteq EEFL` | **PASS** (설치된 AU, arm64) |
| pluginval strictness 10 | 미실시 — 빌드 트리의 `.vst3` 번들에 바이너리가 없고(Info.plist만 존재), AU는 등록 경로 밖에서 스캔되지 않아 "No types found" |
| 실 DAW 로드 / 청감 | 미검증 (IMPROVEMENT_PLAN.md도 미실시로 명시) |

전반 평가: 구조가 명확하고 (input gain → 패시브 EQ → 튜브 → 트랜스 → 출력), NaN/Inf 입력 살균, dry-path 지연 정렬, 지연 보고, 4x 오버샘플링 같은 기본기가 탄탄하다. 테스트가 있고 실제로 통과한다. 다만 **실시간 안전성(오디오 스레드 할당)과 파라미터 스무딩이 부분적으로 누락**되어 있고, **문서·테스트·구현이 서로 어긋난 상태**(아래 §2)가 가장 큰 리스크다.

---

## 1. P1 — 수정 권장 (실시간 안전성 / 클릭·지퍼 노이즈)

### 1.1 오디오 스레드에서 힙 할당 가능
- `PluginProcessor.cpp:447-448` — `resizeScratch(numSamples)`가 `std::vector::resize`로 램프 버퍼를 늘린다. 호스트가 prepare보다 **큰** 블록을 주면 오디오 스레드에서 할당이 발생한다(테스트 9가 정확히 이 경로를 지나간다 — 단, 테스트는 유한성만 확인).
- `PluginProcessor.cpp:528` — `dryBuffer.makeCopyOf (buffer, true)`. JUCE 8 `AudioBuffer::makeCopyOf`는 내부에서 `setSize(..., avoidReallocating)`을 호출하고(`juce_AudioSampleBuffer.h:541`), 새 블록이 기존보다 크면 `allocatedData.allocate`로 힙 할당한다(`juce_AudioSampleBuffer.h:439-444`).
- 영향: 호스트가 가변/성장하는 블록을 쓰는 순간 클릭·스톨 가능.
- 권장: prepareToPlay에서 충분한 상한(예: 최대 8192 또는 `samplesPerBlock * 2`)으로 미리 확보하고, processBlock에서는 `jmin` 클램프 + 할당 없는 경로만 사용. 호스트 블록이 상한을 넘으면 서브블록으로 쪼개 처리(이미 오버샘플러 루프는 서브블록 구조를 갖고 있으므로 자연스럽게 통합 가능).

### 1.2 필터 계수 스무딩이 블록 단위로 양자화됨
- `PluginProcessor.cpp:512-517` — `SmoothedValue::skip (numSamples)`은 "numSamples 만큼 getNextValue를 호출한 것"과 동일하며(`juce_SmoothedValue.h:330-342`), **블록 끝 시점의 값 하나**를 돌려준다. 그 값으로 블록 전체의 계수를 한 번에 교체한다(531-552).
- 30 ms 램프(48 kHz에서 1440 스텝)가 256 샘플 블록 기준 6번의 불연속 계수 점프(~187 Hz 갱신률)로 붕괴된다. 각 점프는 TDF2 상태를 유지한 채 계수만 바뀌므로 지퍼 노이즈의 원인이 된다.
- 권장: (a) 계수를 서브블록(예: 32 샘플)마다 재계산하거나, (b) 두 계수 세트를 크로스페이드, 또는 (c) 최소한 램프를 블록 시작 값 기준으로 스냅해 점프 크기를 절반으로. `skip()`의 의미를 오해한 구현이므로 주석도 함께 정리할 것.

### 1.3 셀렉터(lowFreq / highFreq / attenSel)는 스무딩·디클릭이 전혀 없음
- `PluginProcessor.cpp:248-249`, `531-532` — `makeBand()`가 `apvts.getRawParameterValue("highFreq")` 등을 **원시값으로 직접** 읽는다. 코너 주파수가 한 블록 경계에서 즉시 점프한다.
- 부스트 코너가 700 Hz 고정인 저역 부스트와 달리, 컷 코너는 dial × 9.33(560~1500 Hz)이라 셀렉터 한 칸이 코너를 크게 옮긴다 → 체인지 시 클릭 가능성이 크다.
- 권장: 셀렉터 값에도 10~20 ms 스무딩 또는 계수 보간 적용. 1.2와 같은 서브블록 재계산 구조로 함께 해결된다.

### 1.4 트랜스포머 구동 계수(coreDrive / coreBias)가 원시 파라미터에서 즉시 도출됨
- `PluginProcessor.cpp:502-508` — `driveKnob`은 스무딩 전 raw 값, `liftDb`는 `lowBoostSmoothed.getTargetValue()`(즉 목표값)에서 계산된 뒤 블록 경계에서 즉시 반영된다. 정작 튜브 drive는 `driveRamp`로 샘플 단위 스무딩되는데, 트랜스포머의 기울기 `m`(594행)과 바이어스(600행)는 이 스무딩을 우회한다.
- DRIVE 또는 LOW BOOST를 돌리면 `driveRamp` 스무딩과 무관하게 트랜스포머 출력이 한 번에 점프한다.
- 권장: `coreDrive`, `coreBias`도 `driveSmoothed`/`lowBoostSmoothed`의 **현재값**에서 도출하거나 자체 스무딩 적용.

### 1.5 핫 입력 + 풀 드라이브에서 앨리어싱 한계
- `--diag` 실측: amp 0.8 / drive 1.0에서 최악 앨리어싱 **-47.6 dB** (22~23 kHz). 테스트 6이 검증하는 amp 0.5에서는 -68.2 dB로 4x 오버샘플링이 충분하지만, 한 단계만 세워도 임계를 넘는다.
- 권장: drive > 0.5에서 8x로 전환하거나(두 단계 오버샘플러 보유), 셰이퍼 입력에 소프트 앤티앨리어스(예: -3 dB @ 20 kHz의 1폴)를 추가. 최소한 테스트 6에 amp 0.8 케이스를 추가해 현재 한계를 회귀로 고정할 것.

---

## 2. P2 — 설계/문서 정합성 (사실 확인됨)

### 2.1 "Pultec trick" 서명이 문서 목표와 정반대로 구현됨 (가장 중요한 발견)
`IMPROVEMENT_PLAN.md:47`는 Phase 1 완료를 이렇게 기록한다:

> 부스트 8 + 감쇠 8 @60 Hz에서 **25 Hz +3.8 dB**, 110 Hz **-2.4 dB**, 1 kHz 평탄

그러나 현재 코드의 실측(`FullteqTests --sweep`, dial 60, boost 8, atten 8):

| 20 Hz | 60 Hz | 110 Hz | 300 Hz | 500 Hz | 1 kHz |
|---|---|---|---|---|---|
| **-2.13** | -1.93 | -1.48 | +0.61 | +1.15 | **-2.16** |

즉 서브가 **깎이고** 200~500 Hz가 살짝 올라가는 형태다. 기구물리적 원인은 명확하다:
- 부스트 코너는 700 Hz 고정(`kLowBoostCornerHz`, Q 0.9)이고, 컷 코너는 60 Hz dial × 9.333 = 560 Hz(Q 0.4). 두 로우셸프가 겹치는 영역에서 컷이 항상 우세해, 부스트+컷의 합이 서브에서 음수가 된다.
- 고전적 trick(저역 리프트 + 그 위의 딥)은 **컷 코너가 부스트 코너보다 위에 있어야** 나온다. 현재 모델은 그 관계가 뒤집혀 있다.
- 테스트 3도 구현에 맞춰 재작성되었다: `check (analyticDb (p, 20.0) < -1.5, "the 8/8 trick pulls the sub down", ...)` (DspTests.cpp:233). "풀틱 트릭이 서브를 깎는다"는 원래 목표와 정반대의 단언이고, 1 kHz 허용 오차도 `< 3.0 dB`로 -2.16 dB를 통과시킬 만큼 느슨하다(DspTests.cpp:238).
- **조치**: 어느 쪽이 정답인지 결정 필요. (a) 측정 테이블 모델이 의도라면 IMPROVEMENT_PLAN과 테스트 문구를 사실대로 갱신, (b) 하드웨어 서명이 목표라면 셸프 배치를 재설계(컷 코너를 부스트 코너 위로, 또는 부스트 코너를 dial 비례로 복귀).

### 2.2 존재하지 않는 문서를 참조
- `PluginProcessor.h:122`, `Tests/DspTests.cpp:123,220,315`가 `IMPROVEMENT_NOTES_sound_quality_ref.md` §2/§5/§6을 근거로 인용하지만 이 파일은 저장소에 없다. "measured turnover table", "GroupDIY thread" 주장의 추적성이 끊긴다. 원문을 `reference/`에 넣거나 참조를 제거해야 한다.

### 2.3 프리셋 상태 추적이 깨짐
- `currentPreset`은 `loadPreset`에서만 갱신되고(`PluginProcessor.cpp:308`), 사용자가 노브를 돌리거나 `setStateInformation`으로 상태를 복구해도 무효화되지 않는다.
- 결과: (a) 파라미터를 바꿔도 콤보박스가 "Pultec Low Trick"을 계속 표시(에디터 타이머가 20 Hz로 `currentPreset`에 재동기화, PluginEditor.cpp:962-967), (b) `getCurrentProgram()`이 호스트에 부정확한 프로그램명을 보고, (c) 세션 재로드 시 프리셋 인덱스는 0으로 리셋되는데 파라미터는 저장값 — UI와 소리가 어긋난다.
- 권장: 파라미터 변경 시 프리셋 인덱스를 `-1(커스텀)`로 무효화하고, 상태 XML에 프리셋 인덱스를 함께 저장. 콤보박스에 "(custom)" 표기 추가.

### 2.4 메시지 스레드 데이터 레이스 (경미하나 실재)
- `currentSampleRate`는 prepareToPlay에서 쓰이고(오디오 스레드), `getResponseDb`가 메시지 스레드(응답 곡선 paint, PluginEditor.cpp:606)에서 읽는다. `double` 무보호 접근. `std::atomic<double>`로 바꾸는 것이 정확하다.

### 2.5 응답 그래프가 청감 응답과 다른 것을 "응답"으로 표시
- `getResponseDb`는 패시브 네트워크만 계산한다(튜브/트랜스/트림 제외). 튜브·트랜스는 ±수 dB의 편차를 만든다(테스트 7/12: 50 Hz +0.46~+0.9 dB, 4 kHz -0.15~-1.6 dB). drive 0.15 기본값 + TUBE/XFMR ON이 기본 상태이므로, 그래프는 실제 응답이 아니라 "EQ 네트워크 응답"이다. 라벨을 명확히 하거나 비선형 단계의 소신호 응답을 합산할 것.
- 추가: `clampFrequency` 상한 0.45×fs(PluginProcessor.cpp:14) 때문에 44.1 kHz에서 그래프의 20 kHz 지점은 실제 20 kHz 응답이 아니라 19.845 kHz 값이 그려진다.

### 2.6 죽은 코드/죽은 상태
- `Source/JilesAtherton.h` (104줄) — 어디에서도 include되지 않는다. "물리 모델" 주장과 실제 구현(play operator + tanh)이 다른데, 미완성 실험이 커밋에 남아 있다. 삭제하거나 주석으로 상태를 명시.
- `PluginProcessor.h:185-188` — `NonlinearState`의 `core`, `envelope`는 읽히지 않고, `prev`(678행에서만 대입)와 `shapeRateCoeff`(245행, 유일한 경고 출처)도 미사용.
- `PluginProcessor.h:149` — `kLowBoostCornerRatio`는 선언만 되고 코드에서 사용되지 않음(주석과 헤더 설명 49행, 131행에만 등장). "corner is kLowBoostCornerRatio above the dial"이라는 헤더 문서(49-50행)는 구현과 모순된다.
- `PluginProcessor.cpp:603-611` vs `642-654` — 히스테리시스 주석 블록이 두 번 반복되고, 첫 블록은 중간에 코어 로스 주석으로 흐름이 끊긴다. 편집 흔적이 그대로 남아 있다.

### 2.7 테스트 스위트의 구멍
- 테스트 14의 유일한 단언은 `std::isfinite (rel)`(DspTests.cpp:640) — 메모리리스 셰이퍼도 통과하는 공허한 검사다. 측정값 5.7 dB에 대해 `rel > -20 dB` 같은 실제 역치를 단언해야 한다. (테스트 16은 `fast > slow + 2.0`으로 실질적 검사를 하고 있다.)
- 테스트 6의 앨리어싱 역치(-60 dB)는 amp 0.5에서만 측정한다 — §1.5의 -47.6 dB를 놓친다.
- printf 번호가 1,1b,2,3,4,5,**15**,6,7,8,9,10,11,12,13,14,**16** 순서로 섞여 있고 IMPROVEMENT_PLAN은 "15개 항목"이라고 적혀 있다(실제 16그룹). 사소하지만 신뢰도에 영향.

---

## 3. P3 — 정리 사항

1. **`juce::juce_recommended_warning_flags`가 `FullteqTests`에 빠져 있다** (CMakeLists.txt:65-69). 테스트 타깃은 무경고 빌드인데 권장 플래그를 추가하고 CI에서 `-Werror`를 켜는 편이 낫다. (소스 자체는 -Wall -Wextra -Wpedantic에서 경고 1건 — 아주 깨끗하다.)
2. **테스트 타깃이 `PluginEditor.cpp`를 컴파일한다** (CMakeLists.txt:57-60). `createEditor()`가 에디터 심볼을 요구하기 때문인데, `#if ! FULLTEQ_HEADLESS` 가드로 DSP 테스트를 GUI에서 분리하면 링크가 가벼워진다.
3. **`COPY_PLUGIN_AFTER_BUILD TRUE`** (CMakeLists.txt:23) — 빌드마다 `~/Library/Audio/Plug-Ins/...`에 설치된다(실제로 `Fullteq.component`가 설치되어 있음). 옵트인 CMake 옵션(`option(FULLTEQ_INSTALL_PLUGINS ...)`)으로 바꾸는 편이 CI/새 머신에서 안전하다.
4. **`build/Fullteq_artefacts/`에 바이너리 없는 번들 잔해** — `.vst3`/`.component`가 Info.plist만 남아 있다(pluginval 실패의 직접 원인). `cmake --build build --target clean` 후 재빌드로 정리 권장.
5. **README/LICENSE 부재** — JUCE 8은 AGPLv3/상용 듀얼 라이선스다. 배포 계획이 있다면 라이선스 결정을 문서화해야 한다(법률 자문 대체 아님). Jost 폰트는 OFL.txt로 처리 완료.
6. **범용 바이너리 미설정** — `CMAKE_OSX_ARCHITECTURES` 미지정으로 arm64 전용. 배포 시 x86_64 병합 필요.
7. **FetchContent가 첫 configure에서 네트워크 요구** — `FETCHCONTENT_SOURCE_DIR_JUCE` 오프라인 경로 또는 서브모듈 병행 고려. 태그 8.0.6 고정은 좋다.
8. **에디터가 고정 1320×440, 리사이즈 없음** (PluginEditor.cpp:718). 1280×800 노트북에서 잘릴 수 있다. `setResizable` + 종횡비 컨스트레이너 또는 배율 옵션.
9. **`changeProgramName` no-op** — 호스트가 프로그램명 편집을 시도하면 조용히 무시된다. `getNumPrograms`가 8을 보고하므로 통일 필요.
10. **`getTailLengthSeconds()` = 0** — 오버샘플러 IIR + DC 블로커 상태가 있으므로 수 샘플의 테일이 실재한다. 정확도 개선 여지.
11. **`--snapshot` 모드가 `file.deleteFile()`로 임의 경로를 무조건 삭제** (DspTests.cpp:158) — 개발 도구이지만 안전장지 없음.
12. **IN 토글과 POWER(바이패스)가 동일 효과** (`isEffectBypassed`, PluginProcessor.cpp:295-298) — 툴팁("IN: route the signal through the equalizer")은 IN off가 EQ만 우회하는 것처럼 읽히지만 실제로는 전체 유닛 바이패스다. 툴팁 정정 권장.

---

## 4. 잘 된 점 (사실 기반)

- 입력 NaN/Inf 살균(PluginProcessor.cpp:438-441) — pluginval 퍼즈 시나리오까지 고려한 방어. 테스트 9로 고정.
- dry 지연 라인으로 바이패스 크로스페이드 정렬 + 항상 동일 지연 보고 → 지연 보상 일관성. 테스트 8이 실측 검증(latency 6 samples, err < 1e-6).
- `ScopedNoDenormals`, 오버샘플링된 비선형, double 정밀 TDF2 상태.
- 파라미터를 스텝 1.0 float로 저장해 상태 라운드트립을 안정화한 설명(PluginProcessor.cpp:170-172) — 실제로 이해에 기반한 선택.
- 테스트 존재 + 통과, 응답 해석식 vs 실측 일치 검사(±0.25 dB)가 여러 밴드에 배치됨.
- `-Wall -Wextra -Wpedantic`에서 경고 1건. `auval` PASS.

## 5. 권장 조치 순서

1. §2.1 방향 결정(측정 테이블 vs 하드웨어 서명) — 이것이 다른 모든 저역 수정의 전제.
2. §1.1 오디오 스레드 할당 제거 (prepare에서 상한 확보 + 클램프).
3. §1.2~1.4 스무딩 통합 구조(서브블록 계수 갱신 또는 계수 크로스페이드).
4. §2.2 참조 문서 복구/정리, §2.3 프리셋 무효화, §2.6 죽은 코드 제거.
5. 테스트 보강: amp 0.8 앨리어싱, 테스트 14 실질 단언, 44.1 kHz 스윙, pluginval (바이너리 있는 .vst3 재빌드 후 strictness 10).

## 6. 미검증 항목

- 실 DAW 로드 및 자동화 동작, pluginval 전체 통과(번들 바이너리 부재로 실패), Intel/x86_64 빌드, 청감 비교, LV2/AAX(타깃 아님), 88.2/96 kHz 동작(테스트는 48 kHz 고정).
