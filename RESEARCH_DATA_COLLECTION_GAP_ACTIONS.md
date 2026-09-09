# 데이터 수집 갭 → 액션 (연구 전용)

작성일: 2026-09-09  
범위: 제품/CUDA 코드 변경 없음. 창준(cjlee / System, `cjlee@plaif.com`)이 담당인 지정 Notion만 권위 기반으로 사용. 타인 문서로 설계를 확장하지 않음.

## 권위 문서 (CORE 1–4, AUX 5)

| # | 문서 | 상태 | 최종 편집(UTC) | URL |
|---|---|---|---|---|
| 1 | [데이터 수집] 로봇 시스템 데이터 수집기 설계 | 진행 | 2026-09-08 | https://app.notion.com/p/3d5ba69e7a8780189027e109454dc9ac |
| 2 | [데이터 수집] Bronze 데이터 저장 디렉터리 설계 | 완료 | 2026-08-21 | https://app.notion.com/p/3c1ba69e7a87800089f2e5a4248563ae |
| 3 | [데이터 수집] 파이프라인 설계 | 완료 | 2026-08-20 | https://app.notion.com/p/3c0ba69e7a878024858acf96ebb7496b |
| 4 | [데이터 수집] 파이프라인 조사 | 완료 | 2026-08-10 | https://app.notion.com/p/3b1ba69e7a8780a3b19cd821ef4c7796 |
| 5 | [현대차 주름] 이미지 수집 프로그램 인수인계 (AUX, 주름 이미지 수집 wrinkle만) | 완료 | 2026-08-12 | https://app.notion.com/p/387ba69e7a87801aa637ee5686cc7ce0 |

권위 확인: 1–4 담당자는 창준. 5는 창준이 공동 담당. Notion verification은 모두 `unverified`.

## 역할 맥락 (라이트, 설계 확장 아님)

- System: 창준이 수집기/브론즈/파이프라인 문서를 담당.
- 현차 주름: #1에 따르면 ROS2 마이그레이션 완료. 실제 서비스 시스템은 아직 ROS2가 아님(March).
- 카메라: #2는 `config/camera.yaml`·intrinsics를 브론즈 사이드카로 요구. 창준 배포 메모([현대차 주름] 시스템 배포)는 `sw_camera_driver`를 Docker 이미지(`plaif-camera`)로 올리는 경로만 기록. 수집기 계약은 아님.
- Bronze 배포 이력: 지정 문서 안에 **스토리지 `/plaif_data/bronze` 실제 배포·적재 이력은 없음**. 디렉터리 설계(#2)와 파이프라인 홉(#3)만 있음.
- 데모 창(운영 제약, ~9/13–14): 레이크하우스·학습 루프·March 전 어댑터를 데모 전에 닫지 말 것. 아래 「데모 전 하지 말 것」.

---

## 문서별 갭

### 1) 수집기 설계

**주장 요약**

- 가치 있는 데이터는 서비스 현장. 서비스는 ROS2가 아니고, 현차 주름은 ROS2.
- 수집 로직은 ROS2 vs March, ingest(패킷 덤프 vs DDS), 저장 위치(HDD/SSD/HTTPS DB), 포맷(`.mcap` vs `.h5`), 배포 형태(ROS2 노드 vs `.so`), timestamp 기준을 **몰라야** 한다.
- 도메인 불변식: (1) 변환 없이 raw 저장 (2) 반드시 timestamp (3) 제어 주기와 별도 루프 (4) 수집 루프에 backpressure 없음.
- RB Box ↔ AI Controller 패킷 Read 세션을 참고했다고만 적혀 있음.

**미완·갭**

- 상태 `진행`. 추상화 목록과 불변식만 있고 인터페이스, 어댑터 목록, 언어, 세션 시작/종료, QoS, 오버플로 정책이 없다.
- timestamp는 “기준을 모른다”와 “반드시 찍는다”가 동시에 있다. 센서 시각 / 호스트 시각 / PTP / ROS `header.stamp` / MCAP `log_time` vs `publish_time`이 미정.
- no-backpressure의 실패 모드(드롭, 메트릭, 디스크 full, 제어 루프 차단 금지)가 없다.
- #3은 rosbag2 노드로 MCAP append를 전제한다. #1의 “노드인지 `.so`인지 모른다”와 충돌한다.
- March/패킷 덤프 어댑터는 참고 링크만 있고 계약이 없다.

**리스크**

- 데모 일정에 맞춰 ROS2+rosbag2만 박으면 서비스(March) 수집이 永久 후순위가 된다. #1이 가장 가치 있다고 한 경로다.
- 어댑터가 디스크/네트워크에 막히면 제어 주기에 backpressure가 새어 들어간다.
- timestamp 기준이 어댑터마다 다르면 #3 QC(시간축 정렬)와 LeRobot 변환이 깨진다.

### 2) Bronze 디렉터리

**주장 요약**

- Medallion: bronze = 세션 raw `.mcap` + rosbag2 `metadata.yaml`, 런타임 오작동까지 기록, 압축/변환 없음. silver = 정렬·중복제거·단위/좌표계·이상치·성공/실패. gold = LeRobot 학습 제품.
- 사내 Lakehouse는 아직 없다. 스토리지 서버 bronze만 설계. Hive `key=value` 관례.
- 경로: `/plaif_data/bronze/domain=…/site=…/line=…/robot_id=…/dt=…/session_id=…`
- 세션 디렉터리: `{session_id}_0.mcap` + `metadata.yaml` + `session_manifest.yaml` + `config/` + `versions/`. bronze는 삭제·덮어쓰기 금지.
- 센서 config/좌표계(예: RealSense intrinsic)를 같이 저장.

**미완·갭**

- 트리 예시는 `domain=wrinkle`, 바로 아래 테이블은 `domain=usb`. 파티션 키가 문서 내부에서 갈라진다.
- 본문은 “한 에피소드 = 한 `.mcap`”, 경로는 `session_id`, 파일은 `{session_id}_0.mcap`. session / episode / split(`_0`)이 미정의.
- `session_manifest.yaml`은 `config/collector.yaml`을 가리키는데 트리에는 `robot.yaml` / `camera.yaml` / `transforms.yaml`만 있다.
- `metadata.yaml`을 “rosbag2 메타데이터”로 고정하면 March 수집기는 rosbag2 스키마를 흉내 내거나, #1 추상화가 깨진다.
- Hive 키에 `robot_id`·`session_id`(고카디널리티)가 들어 있다. 레이크 이관 시 small-file 위험이 크다.
- silver/gold 경로는 범위 밖. 불변 bronze vs USB/HTTP 재전송 시 overwrite 프로토콜이 없다.
- 매니페스트에 체크섬·완료 마커(`_SUCCESS` 등)가 없다. #3의 “바이트 깨짐 검수”와 연결되지 않는다.
- `dt` vs `started_at`(KST `+09:00`)의 날짜 경계, MCAP “압축 포맷” 문구 vs bronze “압축/변환 없어야 함”이 충돌한다. MCAP 청크 압축(zstd)을 raw 위반으로 볼지 미정.

**리스크**

- `domain`이 wrinkle/usb로 갈리면 이후 쿼리·이관이 두 갈래가 된다.
- 공장 USB 재복사로 bronze를 덮어쓰면 불변식이 깨진다.
- 사이드카 누락(collector.yaml, versions commit hash) 세션은 재현 불가.
- 고카디널리티 파티션을 나중에 Delta 테이블로 그대로 올리면 디렉터리 폭발.

### 3) 파이프라인 설계

**주장 요약**

- Lakehouse는 당장 불가. 스토리지 서버 + 이관 쉬운 형태.
- 현실 경로: rosbag2 + MCAP. 레퍼런스: Isaac ROS MCAP → LeRobot → GR00T. Wayve/Waabi/Dexterity/Saronic도 MCAP.
- 로봇: CT = 세션. 세션 동안 rosbag2로 MCAP append → RAM·SSD → 세션 종료 후 컨트롤러 HDD → USB 또는 HTTP로 NAS. 현차 공장은 USB/개인 노트북.
- 우선 목표: RL 한 스텝 단위 저장.
- 저장소: 미정제 MCAP RAW, 바이트 검수만.
- 처리: 시간축 정렬, 이상치(예: 시트 이미지에 손), 성공/실패 → LeRobot.
- 학습/검증/배포: 가중치 또는 티칭 json/yaml → 공장 재배포 → 성공률 평가 → 루프.

**미완·갭**

- #1(미들웨어 무지)과 #3(ROS2+rosbag2 전제)이 같은 프로젝트에서 공존한다. 어떤 것이 데모 MVP인지 없다.
- “CT=세션 append”와 “RL 한 스텝 단위”가 동시에 있다. 한 세션 MCAP 안의 스텝 경계가 없다.
- RAM과 SSD에 동시에 append하는 방법(tmpfs, dual-write, 캐시 flush)이 없다. dual-write는 #1 no-backpressure와 충돌할 수 있다.
- USB/HTTP: 인증, resume, 무결성, 재시도, 에어갭, Hive 경로 재구성이 없다.
- QC 주체·도구·성공/실패 라벨 소스(PLC, 작업자, 모델)가 없다. 시계 동기(PTP/NTP)도 없다.
- silver/gold 저장 위치, 시각화, 재배포 파이프라인이 없다.
- 다이어그램 PNG만 있고 홉별 계약이 텍스트로 고정되지 않았다.
- `ros-tooling/rosbag2_storage_mcap`은 현재 `ros2/rosbag2` 트리로 흡수된 상태다(링크 stale 가능).

**리스크**

- 데모가 로봇 쪽 `ros2 bag record`만 되면 데이터는 HDD/USB에 갇힌다.
- QC가 bronze를 “고쳐서” 쓰면 #2 불변식이 깨진다.
- Isaac/GR00T 레퍼런스를 그대로 따르면 Unitree G1·텔레옵·H.264 전제와 주름 셀이 어긋난다.
- 공장 네트워크 제약에서 HTTP NAS를 가정하면 수집이 멈춘다.

### 4) 파이프라인 조사

**주장 요약**

- 목적: 학습 + 재현. closed loop = 수집 → 관리/정제 → 학습/재현 → 재배포.
- 모델 팀은 런타임 수집을 신경 쓰지 않아야 한다. 자동 저장·원격 전송·관리.
- 필요 구성요소: 수집 / 원격 전송 / 저장·쿼리 / 정제·학습 / 재배포 / 시각화.
- 레퍼런스: rosbag2, rosbag2_storage_mcap, LeRobot, Databricks Lakehouse(Tesla/Uber 언급).

**미완·갭**

- 조사 문서. 수용 기준, 담당, 데모 MVP vs 이후가 없다.
- 시각화 제품명이 없다(MCAP이면 Foxglove가 자연스럽지만 미지정).
- Lakehouse를 Tesla/Uber와 Databricks 제품 페이지로 묶었다. 아키텍처 패턴과 제품이 섞여 있다.
- March/비ROS2는 이 문서에 없다(#1에서 나중에 추가된 요구).
- 6개 구성요소를 모두 “필요”로 두면 데모 범위가 무한해진다.

**리스크**

- 조사 레퍼런스를 확정 스택으로 읽으면 Lakehouse+재배포+viz를 데모 전에 넣게 된다.
- 수집기만 만들고 전송/저장/QC가 없으면 closed loop가 성립하지 않는다(#4 자신의 전제).

### AUX 5) 이미지 수집 인수인계 (주름 wrinkle만)

현장 Windows 패널 + `Z:\` 이더넷 마운트, optical flow 자동 캡처, LabelMe 계열 IR 라벨. 천 사양은 카메라 이미지에서 주름이 안 보인다. **로봇 MCAP 수집기·Hive bronze와 다른 파이프라인**이다. 데모 전에 합치지 말 것.

---

## 적용 액션

우선순위: P0 = 데모 전 계약 고정, P1 = 데모 직후·현장 전송, P2 = 학습 루프. effort는 연구/계약/체크리스트 기준(구현 공수 아님).

| # | 우선 | 액션 | 근거 문서 | 공개 출처 | effort |
|---|---|---|---|---|---|
| A1 | P0 | timestamp 계약 1장: 에포크, 클럭 도메인(센서 vs 호스트), 동기(PTP/NTP/없음), MCAP `log_time`(기록 시각)과 `publish_time`(발행 시각, 없으면 log_time) 중 QC/학습이 쓰는 축. 어댑터가 달라도 같은 필드에 기록. | #1, #3 | https://mcap.dev/spec | S |
| A2 | P0 | no-backpressure 실패 모드: 제어 루프와 큐를 분리. 가득 차면 **드롭 + 토픽별 lost 카운트**. 디스크/네트워크 wait로 제어를 막지 않음. rosbag2는 캐시 full 시 드롭, snapshot 원형 버퍼는 오래된 메시지를 덮어씀. | #1 | https://github.com/ros2/rosbag2 , https://github.com/ros2/rosbag2/issues/1845 | S |
| A3 | P0 | bronze 키 동결: `domain`을 `wrinkle` 또는 `usb` 중 하나로 고정(문서 내부 불일치 해소). `session_id` vs episode vs `{id}_N.mcap` split 규칙. `dt`는 `started_at`의 사이트 캘린더 날짜. 쓰기 = create-only(덮어쓰기 금지, 충돌 시 새 session 또는 `_N`). | #2 | https://delta.io/blog/pros-cons-hive-style-partionining/ , https://learn.microsoft.com/en-us/fabric/data-engineering/delta-lake-partitioning | S |
| A4 | P0 | 데모 MVP 경계: **현차 주름 ROS2 어댑터 + Hive 경로 + 사이드카 + 로컬/USB 적재**. March/패킷 어댑터는 인터페이스 stub만. 수집 코어는 #1 불변식만 알고, rosbag2는 어댑터. | #1, #3 | https://github.com/ros2/rosbag2 , https://mcap.dev/ | M |
| A5 | P1 | `session_manifest.yaml` 스키마 고정: 트리와 동일한 config 파일명, `collector.yaml` 포함 여부, `versions/*` commit hash, mcap 목록, **체크섬**, 완료 플래그. `metadata.yaml`은 ROS2면 rosbag2 `rosbag2_bagfile_information`을 그대로 두고, 비ROS2는 동일 키를 채우거나 “없음 + manifest만”을 명시. | #2 | https://github.com/ros2/rosbag2/blob/rolling/rosbag2_tests/resources/mcap/cdr_test/metadata.yaml | S |
| A6 | P1 | 오프보드 전송 계약: USB와 HTTP 모두 Hive 상대경로를 유지. resume, 바이트 검증 후 커밋, 실패 시 부분 디렉터리 남기지 않거나 `incomplete/`로 격리. 현차 공장은 USB를 기본으로 문서화. | #3, #4 | https://mcap.dev/ (append-only, 손상 내성) | M |
| A7 | P1 | 로봇 측 MCAP writer 프리셋: 온로봇은 `fastwrite`(인덱스/CRC 생략, 처리량). bronze “변환 없음”과 청크 압축을 분리해 적기 — 페이로드 재인코딩은 금지, 컨테이너 zstd는 silver 또는 오프보드 재처리. `fastwrite`는 장기 보관 비권장, 이후 `mcap recover`/`ros2 bag convert`. | #2, #3 | https://github.com/ros2/rosbag2/blob/rolling/rosbag2_storage_mcap/README.md | M |
| A8 | P2 | QC는 silver만: 시간 정렬, 이상치(손 등), 성공/실패. bronze는 append-only raw. Databricks bronze = 원본 유지·최소 검증, silver = 정제. | #2, #3 | https://docs.databricks.com/aws/en/lakehouse/medallion | S |
| A9 | P2 | gold LeRobot 타깃 버전 고정(v2.1 episode 파일 vs v3.0 샤드, `lerobot>=0.4`가 v3). session→episode 매핑, fps, 카메라 키. Isaac `mcap-to-lerobot`은 레퍼런스이지 G1 스키마를 복사하지 않음. | #3, #4 | https://huggingface.co/docs/lerobot/lerobot-dataset-v3 , https://nvidia-isaac-ros.github.io/reference_workflows/isaac_for_physical_ai/reference_architecture.html , https://nvidia-isaac-ros.github.io/reference_workflows/isaac_for_physical_ai/tutorials/tutorial_convert.html | M |
| A10 | P2 | viz는 MCAP 재생(Foxglove 등). Lakehouse 쿼리 엔진은 경로 관례만 유지하고 구축하지 않음. Hive 물리적 파티션은 레이크 이관 전 디렉터리 탐색용. `session_id`를 테이블 파티션으로 올리지 말 것. | #2, #4 | https://mcap.dev/ , https://foxglove.dev/product/mcap , https://docs.databricks.com/aws/en/lakehouse/medallion , https://delta.io/blog/pros-cons-hive-style-partionining/ | L |

---

## 데모 전 하지 말 것

- Lakehouse/Delta/Hive 쿼리 엔진, Tesla/Uber급 저장·쿼리 인프라(#4 전체 구성요소).
- March/서비스 패킷 수집기 본구현. stub 이상이면 #1 추상화를 데모 코드에 고정하게 된다.
- LeRobot 변환·GR00T/VLA 학습·공장 재배포 closed loop(#3 후반, #4).
- bronze 삭제·덮어쓰기, QC 결과를 bronze에 다시 쓰기(#2, Databricks bronze).
- 온로봇 `zstd_small`/강한 압축 — CPU가 제어/수집에 backpressure(#1, MCAP preset).
- AUX #5 이미지 파이프라인(Windows, `Z:\`, optical flow, LabelMe)을 로봇 MCAP 수집기에 합치기.
- `robot_id`/`session_id`를 실제 Lakehouse 파티션 키로 승격(#2 + Hive 고카디널리티 경고).
- 제품/CUDA 코드, `sw_camera_driver` 기능 변경. 카메라는 config 사이드카만.
- 미완성 `session_id`로 `/plaif_data/bronze/...`에 최종 경로 커밋(부분 업로드를 bronze로 취급).

---

## Sources

### Notion (창준, 권위)

1. https://app.notion.com/p/3d5ba69e7a8780189027e109454dc9ac
2. https://app.notion.com/p/3c1ba69e7a87800089f2e5a4248563ae
3. https://app.notion.com/p/3c0ba69e7a878024858acf96ebb7496b
4. https://app.notion.com/p/3b1ba69e7a8780a3b19cd821ef4c7796
5. https://app.notion.com/p/387ba69e7a87801aa637ee5686cc7ce0 (AUX)

라이트 배포 맥락(수집 설계 아님): https://app.notion.com/p/396ba69e7a878084a436e7307700a6a1 (`sw_camera_driver` Docker). 담당 창준.

### 공개 웹

- MCAP 개요: https://mcap.dev/
- MCAP 스펙(`log_time` / `publish_time`, append, 청크/인덱스): https://mcap.dev/spec
- MCAP 제품 페이지: https://foxglove.dev/product/mcap
- rosbag2: https://github.com/ros2/rosbag2
- rosbag2 MCAP 플러그인 README(프리셋 `fastwrite` / `zstd_fast` / `zstd_small`): https://github.com/ros2/rosbag2/blob/rolling/rosbag2_storage_mcap/README.md
- rosbag2 `metadata.yaml` 예시: https://github.com/ros2/rosbag2/blob/rolling/rosbag2_tests/resources/mcap/cdr_test/metadata.yaml
- rosbag2 드롭/캐시: https://github.com/ros2/rosbag2/issues/1845
- LeRobot Hub: https://huggingface.co/lerobot
- LeRobot Dataset v3.0: https://huggingface.co/docs/lerobot/lerobot-dataset-v3
- Isaac ROS 레퍼런스(MCAP 기록 → LeRobot → GR00T → 배포): https://nvidia-isaac-ros.github.io/reference_workflows/isaac_for_physical_ai/reference_architecture.html
- Isaac MCAP→LeRobot: https://nvidia-isaac-ros.github.io/reference_workflows/isaac_for_physical_ai/tutorials/tutorial_convert.html
- Medallion: https://docs.databricks.com/aws/en/lakehouse/medallion
- Fabric Medallion: https://learn.microsoft.com/en-us/fabric/real-time-intelligence/architecture-medallion
- Lakehouse 제품 페이지(#4가 인용): https://www.databricks.com/product/data-lakehouse
- Hive-style partitioning: https://delta.io/blog/pros-cons-hive-style-partionining/
- Delta/Fabric 파티션 가이드(저카디널리티, ~1GB/파티션): https://learn.microsoft.com/en-us/fabric/data-engineering/delta-lake-partitioning
- #3 기업 인용(Foxglove 고객 스토리, MCAP 사용): https://foxglove.dev/customers/wayve , https://foxglove.dev/customers/waabi , https://foxglove.dev/customers/dexterity , https://foxglove.dev/customers/saronic
