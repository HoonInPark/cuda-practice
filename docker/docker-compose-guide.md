# Docker Compose 가이드

## 문제
회사에서 프로젝트 별로 사용하는 컨테이너가 달랐고, 이것들을 연동하여 하나의 파이프라인을 구축해야 했다.
이를 위해 도커 컴포즈를 통해 하나의 도메인에 대한 컨테이너 묶음, 구동 순서 등등을 정의할 필요가 있었다.

## 해결
Docker Compose는 여러 컨테이너를 YAML 파일로 정의하고 한 번에 관리할 수 있는 도구입니다.

### 주요 개념
- **서비스(Service)**: 각 컨테이너의 정의 단위
- **네트워크(Network)**: 컨테이너 간 통신 설정
- **볼륨(Volume)**: 데이터 영속성 관리
- **의존성(depends_on)**: 컨테이너 시작 순서 제어

### 기본 사용법
```bash
docker compose up -d      # 백그라운드 실행
docker compose down       # 전체 중지 및 제거
docker compose logs -f    # 로그 확인
docker compose ps         # 실행 중인 서비스 확인
docker compose restart    # 서비스 재시작
```

### CUDA 파이프라인 예시
```yaml
version: '3.8'

services:
  database:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: password
    volumes:
      - db_data:/var/lib/postgresql/data
    networks:
      - pipeline

  preprocessing:
    image: nvidia/cuda:11.8.0-runtime-ubuntu22.04
    depends_on:
      - database
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
    volumes:
      - ./data:/data
    networks:
      - pipeline
    command: python preprocess.py

  inference:
    image: nvidia/cuda:11.8.0-runtime-ubuntu22.04
    depends_on:
      - preprocessing
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
    volumes:
      - ./models:/models
      - ./data:/data
    networks:
      - pipeline
    command: python inference.py

  postprocessing:
    image: python:3.10
    depends_on:
      - inference
    volumes:
      - ./data:/data
      - ./results:/results
    networks:
      - pipeline
    command: python postprocess.py

volumes:
  db_data:

networks:
  pipeline:
    driver: bridge
```

### 주요 설정 옵션

#### 1. runtime: nvidia
CUDA를 사용하는 컨테이너에 필수적인 설정입니다.

#### 2. depends_on
컨테이너 시작 순서를 정의합니다. 단, 이는 시작 순서만 보장하며 서비스가 완전히 준비되었는지는 보장하지 않습니다.

더 엄격한 의존성 관리가 필요하면 헬스체크를 사용합니다:
```yaml
database:
  healthcheck:
    test: ["CMD", "pg_isready"]
    interval: 10s
    timeout: 5s
    retries: 5

preprocessing:
  depends_on:
    database:
      condition: service_healthy
```

#### 3. volumes
- 호스트와 컨테이너 간 파일 공유
- 데이터 영속성 보장
- 여러 컨테이너 간 데이터 공유

#### 4. networks
- 같은 네트워크의 컨테이너는 서비스 이름으로 통신 가능
- 예: `preprocessing` 컨테이너에서 `http://database:5432`로 접근

### 실전 팁

#### GPU 할당
특정 GPU만 사용하려면:
```yaml
environment:
  - NVIDIA_VISIBLE_DEVICES=0,1  # GPU 0, 1번만 사용
```

#### 환경 변수 파일 사용
```yaml
services:
  inference:
    env_file:
      - .env.common
      - .env.inference
```

#### 리소스 제한
```yaml
services:
  inference:
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

### 디버깅

특정 서비스만 실행:
```bash
docker compose up preprocessing
```

특정 서비스 로그 확인:
```bash
docker compose logs -f inference
```

컨테이너 내부 접속:
```bash
docker compose exec inference bash
```

### 주의사항
- `depends_on`은 시작 순서만 보장하므로, 서비스 준비 상태 확인은 애플리케이션 레벨에서 재시도 로직으로 처리
- GPU 사용 시 호스트에 nvidia-docker2 설치 필요
- 볼륨 마운트 경로는 절대 경로 또는 상대 경로 사용 가능
