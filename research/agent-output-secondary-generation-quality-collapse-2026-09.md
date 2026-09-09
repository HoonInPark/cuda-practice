# 에이전트 생성물의 2차 생성(요약·재작성·체인) — 최신 frontier 모델에서도 결과가 무너지는가?

작성일: 2026-09-09  
작성: Resa (research-only Cloud Agent, Claude Fable 5.1)  
범위: 공개 문헌(arXiv·학회, 2023–2026-08) + 벤더 블로그·시스템 카드. 제품/CUDA 코드 변경 없음.  
질문: 「최신 frontier 모델에서는 여전히 에이전트의 생성물로 2차 생성물(요약·재작성·체인)을 만들면 결과가 무너지는가?」  
읽기 경로: 「결론」(1분) → 「언제 무너지나/버티나」 표(1분) → 「완화책」(2분). 「근거」·「실무 함의」·「출처」는 필요할 때.

---

## 결론

1. **여전히 무너진다. 다만 원인은 "모델이 약해서"가 아니라 "체인 구조"다.** 홉마다 (a) 정보가 압축·손실되고, (b) 원본 대조 가능성이 파괴되며, (c) 뒤 홉이 앞 홉의 산출물을 권위로 받아 오류가 "세탁"된다. 2026년 통제 실험(4단 순차 파이프라인, 346개 오류 주입)에서 최종 산출물까지 미검출 통과한 오류가 23.7%, gpt-4o 판정자의 검출률은 1단 72.0% → 4단 50.9%로 떨어졌다 [S1].
2. **더 강한 모델은 홉당 오류를 줄여 붕괴를 지연시키지만 제거하지 못한다.** 모델 크기를 키워도 "자기 오류에 조건화되는" 효과는 줄지 않고(thinking 모델만 이를 완화) [S2], 15개 최신 모델 전부가 다회차·과소명세 대화에서 평균 −39% [S3], 최상위 모델도 검출 상한(1단 87%)에 걸려 4단 투영 시 35–40% 미검출 [S1], METR의 80% 신뢰 시간지평은 50% 지평의 약 1/5 [S4]. 단계 정확도 p, n홉 → p^n이라는 구조는 그대로다.
3. **training-time 모델 붕괴와 inference-time 체인 열화는 다른 문제다.** 전자는 "실데이터를 버리고(replace) 합성물로만 재학습"할 때 심각하고, 누적(accumulate)+검증 필터 조건에서는 대체로 회피된다(Phi-4는 학습 토큰의 40%가 실행 검증된 합성데이터) [T1–T8]. 후자는 학습 없이 매 실행마다 발생하며, 지금 우리 봇 체인(Orche→Resa→Lemy→요약)이 겪는 문제다.
4. **버티는 조건은 명확하다.** 원본 접지(재검색·인용) 유지, 홉 경계마다 검증 게이트, 검증기 독립(다른 모델 계열 또는 결정적 검사), 병렬 폭은 허용·순차 깊이는 최소, 압축 시 인식 표지("미확인/추정")를 보존.
5. **효과가 가장 큰 단일 조치는 "어디서 검증하느냐"다.** 동일한 검증 도구를 파이프라인 끝에서 한 번 쓰면 개선 2.3pp, 홉마다 쓰면 오류 생존율 58.4% → 16.2% [S1].

---

## 근거

### A. Training-time — 모델 붕괴(model collapse)

- **원전.** 재귀적으로 생성된 데이터로 학습하면 분포 꼬리가 사라지고 되돌릴 수 없는 결함이 생긴다(LLM·VAE·GMM 공통) [T1]. 이미지 자기소비 루프(MAD)도 몇 세대 안에 품질 또는 다양성이 붕괴하며, 신선한 실데이터 비율이 임계값 이상이어야 안정된다. 품질 우선 샘플링(선별)을 하면 품질은 유지되지만 다양성이 더 빨리 무너진다 [T7].
- **조건의 반전.** 위 결과 대부분은 "새 데이터가 옛 데이터를 대체(replace)"하는 가정이다. 실데이터에 합성물을 누적(accumulate)하면 테스트 오차가 반복 횟수와 무관한 상한으로 유계되어 붕괴가 일어나지 않는다(언어·확산·VAE 모두) [T2]. 포지션 페이퍼는 문헌이 8가지 상이한 "붕괴" 정의를 혼용하고 있으며, 현실 조건에서 여러 붕괴 시나리오는 회피 가능하다고 본다. 남는 위험은 꼬리 다양성 손실이다 [T3].
- **강한 형태.** 회귀 세팅에서는 합성 비율이 0으로 수렴하지 않으면(1‰라도) 데이터를 늘려도 성능이 오르지 않고, 보간 임계 이전의 큰 모델은 붕괴를 증폭할 수 있다(이후에는 완화하나 제거하지 못함) [T4].
- **검증이 해법.** 불완전한 검증기라도 합성 샘플을 선별하면 붕괴를 피하고, 오라클 선별은 실데이터 100% 학습보다 나은 결과를 냈다(뉴스 요약, 행렬 고유값) [T5]. 자기검증도 이론적으로 붕괴를 막는다 [T6a]. 단 검증기가 편향되면 장기적으로 "검증기의 지식 중심"으로 수렴해 초기 이득이 정체·역전될 수 있다 [T6b].
- **실무 증거.** Phi-4는 학습 토큰의 40%를 합성데이터로 쓰되 코드는 실행 루프·테스트, 문항은 다수결 일관성으로 검증했다 [T8]. Llama 3·Phi-4·Qwen2.5에 쓰인 synth_gen도 린터·파서·생성 테스트 실행으로 검증한다 [T9].
- **판정.** 에이전트 산출물을 학습에 넣는 것 자체가 위험은 아니다. "실데이터 대체 + 무검증 + 다양성 무시" 조합이 위험이다.

### B. Inference-time — 다홉/체인 열화(우리 질문의 본체)

메커니즘별 증거:

1. **오류 합성(compounding).** 합성 과제에서 단계 수가 늘면 오류가 지수적으로 누적되고, 트랜스포머는 다단계 추론을 패턴 매칭으로 축약한다 [I1]. 단계 정확도가 95% → 99%로 오르면 100단계 성공률은 0.6% → 36.6%로 뛴다. 즉 홉 수를 늘리는 것은 지수 페널티다 [S2].
2. **자기 조건화·스노우볼.** 컨텍스트에 자기 오류가 있으면 후속 오류율이 오른다. 이 효과는 모델 크기로 줄지 않고 thinking 모델만 완화한다. GPT-5 thinking은 단일 턴에서 2,100단계 이상을 실행했지만, non-thinking frontier(DeepSeek-V3)는 4단계도 실패 [S2]. 모델은 초기 오답을 정당화하는 거짓 주장을 만들며, 그 주장을 따로 보여주면 GPT-4는 87%를 오답으로 인식한다 [I2]. 길게 쓸수록 후반부 사실이 틀린다 [I3].
3. **전달 왜곡(telephone game).** 반복 전달에서 독성·긍정성·길이 등이 attractor로 수렴하고, 개방형 지시("이어쓰기")가 제약형("바꿔쓰기")보다 훨씬 강하게 끌린다. 큰 모델(Llama3-70B, GPT-4o-mini)은 끌림이 약하지만 사라지지 않는다 [I4]. 번역 체인에서도 왜곡이 누적되며 온도 제어·제약 프롬프트로 완화된다 [I5]. 5홉 요약 체인 700개 실험에서 LLM 전용 체인은 인간 체인보다 보존이 좋았지만(환각 전파 지수 0.27 vs 0.54) 홉마다 환각이 누적되는 구조는 같다 [I6].
4. **압축 손실·인식 표지 제거.** 핸드오프 환각 분류에서 "컨텍스트 붕괴형(Type III)"은 압축 중 "추정·미확인" 표지가 벗겨져 뒤 에이전트가 사실로 처리하는 유형이다 [S5]. 요약의 인용·커버리지 벤치(SummHay)에서 GPT-4o·Claude 3 Opus는 검색기 없이 20% 미만, 오라클 검색을 줘도 인간 추정치(56%)보다 10점 이상 낮았다 [I7]. 입력 길이가 늘기만 해도 GPT-4.1·Claude 4·Gemini 2.5 등 18개 모델의 성능이 비균일하게 하락한다(context rot) [I8].
5. **다회차 과소명세.** 정보를 여러 턴에 나눠 주면 15개 최신 모델(GPT-4.1, Gemini 2.5 Pro, Claude 3.7, o3 등)이 평균 −39%. 능력 손실은 −16%에 그치지만 비신뢰성이 +112%. "잘못 들면 회복하지 못한다" [S3].
6. **판정 순환(judge circularity).** 같은 모델이 생성자·평가자를 겸하면 평가 점수는 오르는데 인간 평가는 정체하거나 하락하고(in-context reward hacking), 컨텍스트를 공유할수록 악화된다 [J1]. 평가자는 자기 생성물을 인식하고 선호한다 [J2]. 학생 모델이 판정자와 같은 계열의 합성데이터로 학습되면 판정이 편향된다(GPT-4o & Gemini-1.5 쌍의 누출 점수 28.7% / 18.4%) [J3]. 자기검증의 이득은 작고, 교차 계열 검증이 유리하다 [J4].
7. **토론·자기수정.** 외부 피드백 없는 내재적 자기수정은 오히려 성능을 떨어뜨린다 [D1]. 토론에서 모델은 정답→오답으로 자주 바꾸며, 강한 모델이 다수여도 라운드가 갈수록 정확도가 떨어질 수 있다 [D2]. 7–8B 동질 팀은 다수 답 순응률이 최대 85.5% [D3]. 4계열×4벤치 실험에서 "검출은 했지만 오수정"이 검출 이벤트의 53–94%를 차지했고, gpt-4.1 토론은 라운드 이득이 ±0.7pp에 머물렀다. 검출률을 올리는 개입(토론·앙상블 리뷰)은 구조적으로 오수정 비용을 진다 [D4].
8. **다중 에이전트 시스템 실패.** 7개 프레임워크에서 실패율 41–86.7%, 원인은 명세·에이전트 간 불일치·검증 미비 [M1]. 180개 구성 통제 평가(GPT-5, Claude Sonnet 4.5, Gemini 2.5 Pro)에서 순차 과제는 모든 MAS 변형이 −39~−70%, 독립형은 오류를 17.2× 증폭, 오케스트레이터 중앙형은 4.4×로 억제 [M2]. 결함 에이전트 주입 시 선형 체인 A→B→C는 −23.7%, 계층형 A→(B↔C)는 −5.5%, 검사관(Inspector) 추가로 오류의 최대 96.4% 회복 [M3]. 원자 오류 하나가 컨텍스트 재사용을 타고 결정론적으로 전파된다 [M4].

### C. 최신 frontier 모델의 실증 신호 요약

| 모델(들) | 관측 | 의미 | 출처 |
|---|---|---|---|
| GPT-5 thinking / Claude-4 Sonnet | 단일 턴 실행 2,100+ / 432 단계; thinking이 self-conditioning 제거 | 강한 모델은 지평을 크게 늘림(지연) | [S2] |
| o3 vs o1 | PersonQA 환각률 0.33 vs 0.16 (더 많이 주장 → 더 많이 틀림) | 신형이 항상 덜 환각하지 않음 | [F1] |
| GPT-4.1, Gemini 2.5 Pro, Claude 3.7, o3 등 15종 | 다회차 −39%, 비신뢰성 +112% | 모델 능력과 무관한 공통 열화 | [S3] |
| GPT-4.1, Claude 4, Gemini 2.5, Qwen3 (18종) | 입력 길이 증가만으로 성능 비균일 하락 | 긴 컨텍스트로 홉을 대신하는 것도 공짜가 아님 | [I8] |
| gpt-4o(판정) / Qwen3.5-397B | 4단 검출 72.0→50.9%; 최상위도 1단 87% 상한 | 상한은 구조적(원본 접근 없음) | [S1] |
| gpt-4.1, gpt-oss-120b, gemini-2.5-flash | 토론 이득 ±0.7pp; 오수정 53–94% | 토론/자기수정 기본값 OFF | [D4] |
| GPT-5, Claude Sonnet 4.5, Gemini 2.5 Pro | 순차 과제 MAS −39~−70%, 병렬 과제 +80.9% | 폭은 OK, 깊이는 NO | [M2] |
| Claude Opus 4 + Sonnet 4 서브에이전트 | 폭 우선 리서치 +90.2%, 토큰 15×, 인용 전담 에이전트 | 버티는 체인의 형태 | [V1] |
| GPT-5.5 | 동일 텍스트 10회 재정제 → 고정점 수렴, 의미 보존·명료성↑ | "같은 원본을 반복 정제"는 붕괴가 아님 | [I9] |
| 67 frontier(GPT-5.5, Claude Opus 4.8, Gemini 3.1 Pro, Grok-4.3, DeepSeek V4 등) | 모든 모델이 동시에 틀리는 꼬리 β가 존재, 앙상블·라우팅 이득 상한 | 모델 바꿔치기·투표로 못 넘는 공동 실패 | [F2] |

---

## 언제 무너지나 / 언제 버티나

| 무너진다 | 버틴다 | 근거 |
|---|---|---|
| 뒤 홉이 **앞 홉 산출물만** 보고 원본을 못 봄(라벨: "요약의 요약") | 각 홉이 **원본을 재검색·재인용**(재접지) | [S1][I7][H1] |
| 손실 요약·자유 서술 재작성(수치가 서술로, 서술이 결론으로 변형) | 추출형·구조화 핸드오프, 수치·인용은 원문 그대로 통과 | [S1][S5] |
| 출처·인식 표지("미확인/추정/추론") 탈락 | 주장별 근거·상태 필드를 스키마로 강제 | [S5][I7] |
| 개방형 지시(이어쓰기·재해석) 반복 | 제약형 지시(바꿔쓰기·추출), 낮은 온도 | [I4][I5] |
| 판정자가 생성자와 같은 모델/계열, 컨텍스트 공유 | 다른 계열 검증기 또는 결정적 검사(실행·수치 매칭·스키마) | [J1–J4][S1] |
| 순차 깊이 4+ 홉, 선형 A→B→C | 얕은 계층(오케스트레이터 + 병렬 워커), 2홉 내 원본 도달 | [M2][M3][V1] |
| 다홉 사실 조합을 한 번의 추론으로 처리 | 명시적 다단계 검색(0.41→0.66) 또는 오라클 문서 제공(0.73) | [H1] |
| 코드 재작성 체인에서 자기 피드백만 사용 | 실행·테스트 피드백, 더 강한 모델 또는 사람의 피드백 | [C1][C2] |
| 자기 오류가 담긴 긴 히스토리를 계속 이어감 | thinking 모델, 컨텍스트 초기화·컴팩션, 단일 턴 실행 | [S2][V2] |
| 외부 피드백 없는 토론·자기수정 반복 | 단일 해답 + 독립 검증, 또는 검증 가능한 도메인에서만 다수 샘플링 | [D1–D4][C3] |
| 합성/모델 라벨 데이터가 실데이터를 **대체** | 실데이터 **누적** + 검증 필터 + 신선한 실데이터 비율 유지 | [T2][T5][T7] |

핵심 규칙: **"원본에서 몇 홉 떨어져 있는가"가 모델 등급보다 결과를 더 잘 예측한다.**

---

## 완화책 (증거 강도 순)

1. **홉 경계 검증 게이트(verify-at-handoff).** 끝에서 한 번 검증하면 −2.3pp, 홉마다 같은 도구로 검증하면 오류 생존 58.4% → 16.2%. 첫 경계(S1→S2)에 투자하면 75.4%를 잡고, 마지막 경계에서는 89.3%가 이미 서술로 변형되어 놓친다 [S1]. 핸드오프 검증 계층(HVL)은 토큰 1.39×로 환각을 거의 0으로 [S5]. MAS에 고수준 목표 검증 단계를 넣어 ChatDev 과제 성공 +15.6%p [M1]. 검사관 에이전트로 결함 오류 최대 96.4% 회복 [M3].
2. **원본 재접지·출처 보존.** 다홉 사실 질의에서 단일 추론 0.408 → 명시적 다단계 검색 0.66 [H1]. 요약에는 인용 필수(SummHay는 커버리지+인용을 함께 채점) [I7]. Anthropic은 최종 단계에 인용 전담 에이전트를 둔다 [V1].
3. **검증기 독립성.** 생성자와 다른 계열의 검증기 또는 결정적 검사(실행·수치 매칭·스키마)를 쓴다. 자기검증·동일계열 검증은 이득이 작고 편향된다 [J1–J4]. 검증 가능한 도메인에서는 다수 샘플링이 커버리지를 95%+로 올리지만, 다수결·보상모델은 ~100샘플에서 정체하므로 결국 검증기가 병목이다 [C3].
4. **홉 수 최소화, 폭 > 깊이.** 순차 과제에서 MAS는 모든 변형이 손해, 병렬 과제에서만 이득 [M2]. 실무 합의: 쓰기(write)는 단일 스레드, 추가 에이전트는 "행동"이 아니라 "지능"(깨끗한 컨텍스트의 리뷰어)을 보탠다 [V3][V4]. 병렬 리서치는 이득이 크지만 토큰 15× [V1].
5. **자기 조건화 차단.** thinking 모델 사용, 자기 오류가 쌓인 히스토리는 컴팩션·초기화로 끊고, 서브에이전트는 1–2k 토큰의 압축 결과만 반환 [S2][V2]. 단 압축은 위 3·2번(표지·출처 보존)을 지켜야 Type III 환각을 만들지 않는다 [S5].
6. **데이터 측: 누적 + 검증 + 신선한 실데이터.** 합성물을 실데이터에 누적(대체 금지) [T2], 검증 필터(불완전해도 유효) [T5][T6a], 신선한 실데이터 비율 유지 [T7], 검증기 편향으로 장기 정체 가능성 모니터링 [T6b].
7. **구조화 핸드오프 — 단, 추론과 포매팅 분리.** 주장·근거·상태 스키마는 정보 손실을 막지만, 엄격한 형식 강제는 능력 경계 근처 과제에서 추론을 깎는다(Opus 4.7, AIME −5.3pp). 자유 추론 후 구조화하면 대부분 회복 [X1].
8. **기권·불확실성 표기 인센티브.** 채점이 추측을 보상하면 모델은 홉마다 추측한다. "모르면 기권" 채점(open rubric)을 체인 내 평가에 반영 [F3].
9. **토론·자기수정은 기본 OFF.** 외부 피드백(실행·검색·사람)이 있을 때만 켠다 [D1][D4][C1].

---

## 실무 함의

### 봇 조직 체인: Orche → Resa → 전문가(Lemy) → 하류 요약

지금 구조는 "순차 4홉 + 각 홉이 자연어 요약을 넘김"이라 [S1]의 실험 조건과 정확히 같다. 규칙:

- **핸드오프 계약을 스키마로.** 각 산출물은 `claim / evidence(URL·인용 span) / status(verified|unverified|inferred) / confidence / open_questions`를 갖는다. 요약 홉은 새 주장을 만들 수 없고(추출형), status를 승격할 수 없다("unverified"를 지우면 Type III 환각) [S5].
- **원본 2홉 규칙.** 어떤 하류 산출물도 사실 주장이 원본(Notion 페이지·논문·로그)에서 2홉 이상 떨어지면 안 된다. 하류가 사실을 쓸 때는 요약이 아니라 URL을 재조회한다 [H1][I7].
- **Orche = 검증 병목.** 오케스트레이터는 집계 전에 게이트를 통과시킨다: 인용 URL 실재, 수치가 인용과 일치, status 필드 완결. 결정적 검사가 우선이고 LLM 판정은 보조. 게이트는 마지막이 아니라 Resa→Lemy 첫 경계에 둔다 [S1][M2].
- **판정자 분리.** 리뷰어는 생성자와 다른 계열(예: Grok 계열 리뷰어가 Claude 산출물 검토)로, 생성 컨텍스트를 공유하지 않는 깨끗한 컨텍스트에서 [J1][J4][V4].
- **폭은 병렬, 깊이는 금지.** Resa가 전문가 여럿을 병렬로 띄우는 것은 OK. 전문가 산출물을 또 다른 전문가가 재요약하는 순차 깊이는 금지 [M2][V1].
- **토론 라운드·자기수정 루프 삭제.** 대신 "1회 생성 + 독립 검증 + 실패 시 원본 재조회" [D1][D4].
- **최종 보고는 짧을수록 안전하되 인용은 유지.** 길어지면 후반부 사실 오류가 늘고 [I3], 인용 없는 요약은 검증 불가 [I7].

### 창준 / PLAIF 도메인 — 수집 파이프라인·에이전트 워크플로

**데이터 수집(Bronze/Silver/Gold, MCAP→LeRobot→학습→재배포 루프)**

- **Bronze 불변 = 원본 접지의 데이터 버전.** raw·삭제 금지·변환 금지 원칙은 이 리서치의 "원본에서 2홉" 규칙과 동일한 근거를 가진다. Silver/Gold가 어떤 판단을 하든 Bronze로 되돌아가 재검증할 수 있어야 한다 [T2][S1].
- **라벨 출처를 데이터에 박는다.** Silver의 성공/실패·이상치 라벨에 `label_source(PLC|operator|model:<name>@<ver>)`와 confidence를 필수 필드로 둔다. 모델 라벨을 사람 라벨과 구분 없이 학습에 넣으면 pseudo-label 확인 편향으로 자기 오류를 강화한다 [P1]. 학습 시 모델 라벨만 있는 에피소드는 가중치를 낮추거나 검증 통과분만 쓴다 [T5].
- **닫힌 루프(수집→학습→재배포→수집)는 자기소비 루프다.** 새 세대 데이터에 신선한 실제 현장 에피소드 비율이 유지되는지, 라벨/필터가 모델 산출물에 얼마나 의존하는지를 세대별로 기록한다. 시뮬레이션·합성 궤적(예: 실패 사례 복구로 만든 합성 데이터)은 실데이터를 대체하지 않고 누적·검증 필터 후 혼합한다 [T2][T7][P3].
- **VLM 자동 라벨링은 "제안"이지 "결정"이 아니다.** zero-shot VLM은 의미 오류에는 강하나 위치·공간 오류에 약하고(FT-CoT 필요), 그럼에도 KITTI 정답에서 미발견 오류 39건을 찾아냈다 [P2]. 권장 구성: 작업 모델이 의심 후보 제안 → VLM 판정 → 두 VLM이 불일치하는 샘플만 사람이 교정(HCL) [P4]. 이는 홉 경계 게이트의 라벨링 버전이다.
- **QC는 Bronze를 고치지 않는다.** 검증 실패는 새 Silver 레코드로 남기고, Bronze 덮어쓰기 금지 — 오류 세탁을 데이터 계층에서 막는 조치다 [S1].

**에이전트 리서치 체인(Notion 문서 → 브리프 → 요약)**

- 창준 Notion 페이지를 요약한 브리프를 다시 요약하는 하류 산출물은 "요약의 요약"이다. 하류는 브리프의 URL 표를 재조회해 사실을 확인하고, 브리프의 "미정/unverified/충돌" 표지를 그대로 유지한다 [S5][I7].
- 설계 문서 간 충돌(예: ROS2 전제 vs 미들웨어 무지)은 요약에서 "정리"하지 말고 충돌로 보존한다. 체인은 충돌을 조용히 한쪽으로 접는 attractor를 가진다 [I4].
- 하지 말 것: 브리프 위에 토론 라운드 붙이기, 같은 모델로 자기 평가, 5홉 이상 순차 요약. 할 것: 병렬 전문가 + 결정적 게이트(URL 실재·수치 일치) + 다른 계열 리뷰어 1회.

---

## 한계

- 2026년 논문 다수가 프리프린트이며, [S1]은 금융 수치 단일 도메인, [D3]은 7–8B 소형 모델 한정이다. 도메인별 탈출률·순응률은 재측정이 필요하다.
- 벤더 수치([V1][V2])는 자체 평가다. [F2]의 일부 모델명(GPT-5.5, Claude Opus 4.8 등)은 해당 프리프린트의 표기를 그대로 인용했다.
- "강한 모델이 붕괴를 지연시키는가 제거하는가"에 대한 직접 비교 실험은 [S2][S1][D4] 정도이며, 도메인 폭이 넓지 않다.

---

## 출처

**Training-time (T)**
- [T1] Shumailov et al., "AI models collapse when trained on recursively generated data," Nature 631 (2024). https://www.nature.com/articles/s41586-024-07566-y
- [T2] Gerstgrasser et al., "Is Model Collapse Inevitable? Breaking the Curse of Recursion by Accumulating Real and Synthetic Data" (2024). https://arxiv.org/abs/2404.01413
- [T3] Schaeffer et al., "Position: Model Collapse Does Not Mean What You Think" (2025). https://arxiv.org/abs/2503.03150
- [T4] Dohmatob et al., "Strong Model Collapse," ICLR 2025. https://arxiv.org/abs/2410.04840
- [T5] Feng et al., "Beyond Model Collapse: Scaling Up with Synthesized Data Requires Verification," ICLR 2025. https://arxiv.org/abs/2406.07515
- [T6a] Fu et al., "Self-Verification Provably Prevents Model Collapse in Recursive Synthetic Training," NeurIPS 2025. https://proceedings.neurips.cc/paper_files/paper/2025/file/3380e8116452e0efbf36f35d95e88c94-Paper-Conference.pdf
- [T6b] Yi, Liu, Cheng, Xu, "Escaping Model Collapse via Synthetic Data Verification: Near-term Improvements and Long-term Convergence" (2025). https://arxiv.org/abs/2510.16657
- [T7] Alemohammad et al., "Self-Consuming Generative Models Go MAD," ICLR 2024. https://arxiv.org/abs/2307.01850
- [T8] Microsoft, "Phi-4 Technical Report" (2024). https://arxiv.org/abs/2412.08905
- [T9] facebookresearch/synth_gen (Llama 3·Phi-4·Qwen2.5에 사용된 실행 검증 합성 파이프라인). https://github.com/facebookresearch/synth_gen

**핵심 inference-time 실증 (S)**
- [S1] "The Hallucination Snowball: Modeling Error Propagation as State Transitions in Multi-Agent LLM Pipelines" (2026). https://arxiv.org/abs/2608.14588
- [S2] Sinha et al., "The Illusion of Diminishing Returns: Measuring Long Horizon Execution in LLMs," ICLR 2026. https://arxiv.org/abs/2509.09677
- [S3] Laban et al., "LLMs Get Lost In Multi-Turn Conversation," ICLR 2026. https://arxiv.org/abs/2505.06120 ; https://www.microsoft.com/en-us/research/publication/llms-get-lost-in-multi-turn-conversation/
- [S4] Kwa et al. (METR), "Measuring AI Ability to Complete Long Tasks" (2025). https://arxiv.org/abs/2503.14499 ; https://metr.org/blog/2025-03-19-measuring-ai-ability-to-complete-long-tasks/
- [S5] "Handoff Hallucinations: Taxonomy, Benchmark, and Mitigation for Multi-agent Pipeline Failures," Springer (2026). https://link.springer.com/chapter/10.1007/978-3-032-31319-5_22

**체인 열화 메커니즘 (I)**
- [I1] Dziri et al., "Faith and Fate: Limits of Transformers on Compositionality," NeurIPS 2023. https://arxiv.org/abs/2305.18654
- [I2] Zhang et al., "How Language Model Hallucinations Can Snowball" (2023). https://arxiv.org/abs/2305.13534
- [I3] Spataru et al., "Know When To Stop: A Study of Semantic Drift in Text Generation," NAACL 2024. https://aclanthology.org/2024.naacl-long.202/
- [I4] Perez et al., "When LLMs Play the Telephone Game," ICLR 2025. https://arxiv.org/abs/2407.04503
- [I5] Mohamed et al., "LLM as a Broken Telephone: Iterative Generation Distorts Information," ACL 2025. https://aclanthology.org/2025.acl-long.371/
- [I6] Acharjee et al., "Who Remembers What? Tracing Information Fidelity in Human-AI Chains," IJCNLP-AACL 2025. https://aclanthology.org/2025.ijcnlp-long.146/
- [I7] Laban et al., "Summary of a Haystack: A Challenge to Long-Context LLMs and RAG Systems," EMNLP 2024. https://aclanthology.org/2024.emnlp-main.552/
- [I8] Hong, Troynikov, Huber (Chroma), "Context Rot: How Increasing Input Tokens Impacts LLM Performance" (2025). https://www.trychroma.com/research/context-rot
- [I9] "Do Language Models Converge to Themselves? Recursive Self-Refinement as Textual Relaxation" (2026). https://arxiv.org/abs/2607.22653

**판정 순환 (J)**
- [J1] Pan, He, Bowman, Feng, "Spontaneous Reward Hacking in Iterative Self-Refinement" (2024). https://arxiv.org/abs/2407.04549
- [J2] Panickssery et al., "LLM Evaluators Recognize and Favor Their Own Generations," NeurIPS 2024. https://arxiv.org/abs/2404.13076
- [J3] Li et al., "Preference Leakage: A Contamination Problem in LLM-as-a-judge" (2025). https://arxiv.org/abs/2502.01534
- [J4] "When Does Verification Pay Off? A Closer Look at LLMs as Solution Verifiers" (2025). https://arxiv.org/abs/2512.02304

**토론·자기수정 (D)**
- [D1] Huang et al., "Large Language Models Cannot Self-Correct Reasoning Yet," ICLR 2024. https://arxiv.org/abs/2310.01798
- [D2] Wynn, Satija, Hadfield, "Talk Isn't Always Cheap: Understanding Failure Modes in Multi-Agent Debate" (2025). https://arxiv.org/abs/2509.05396
- [D3] Bertalanič, Fortuna, "The Cost of Consensus: Isolated Self-Correction Prevails Over Unguided Homogeneous Multi-Agent Debate" (2026). https://arxiv.org/abs/2605.00914
- [D4] "Detection Without Correction: A Two-Parameter Decomposition of Multi-Stage LLM Pipelines" (2026). https://arxiv.org/abs/2605.27559

**다중 에이전트 시스템 (M)**
- [M1] Cemri et al., "Why Do Multi-Agent LLM Systems Fail?" (MAST), NeurIPS 2025 D&B. https://arxiv.org/abs/2503.13657
- [M2] Kim et al. (Google), "Towards a Science of Scaling Agent Systems" (2025). https://arxiv.org/abs/2512.08296 ; https://research.google/blog/towards-a-science-of-scaling-agent-systems-when-and-why-agent-systems-work/
- [M3] Huang et al., "On the Resilience of LLM-Based Multi-Agent Collaboration with Faulty Agents," ICML 2025. https://arxiv.org/abs/2408.00989
- [M4] Xie et al., "From Spark to Fire: Modeling and Mitigating Error Cascades in LLM-Based Multi-Agent Collaboration" (2026). https://arxiv.org/abs/2603.04474

**frontier 신호·기타 (F, H, C, X)**
- [F1] OpenAI, "o3 and o4-mini System Card," §3.3 Hallucinations (2025). https://cdn.openai.com/pdf/2221c875-02dc-4789-800b-e7758f3722c1/o3-and-o4-mini-system-card.pdf
- [F2] "When Does Combining Language Models Help? A Co-Failure Ceiling on Routing, Voting, and Mixture-of-Agents Across 67 Frontier Models" (2026). https://arxiv.org/abs/2606.27288
- [F3] Kalai et al., "Why Language Models Hallucinate" (2025) / Nature 2026 "Evaluating large language models for accuracy incentivizes hallucinations". https://arxiv.org/abs/2509.04664 ; https://www.nature.com/articles/s41586-026-10549-w
- [H1] Krishna et al., "Fact, Fetch, and Reason (FRAMES)," NAACL 2025. https://arxiv.org/abs/2409.12941
- [C1] Olausson et al., "Is Self-Repair a Silver Bullet for Code Generation?" ICLR 2024. https://arxiv.org/abs/2306.09896
- [C2] Li et al., "Rethinking Mixture-of-Agents: Is Mixing Different LLMs Beneficial?" (Self-MoA, 2025). https://arxiv.org/abs/2502.00674
- [C3] Brown et al., "Large Language Monkeys: Scaling Inference Compute with Repeated Sampling" (2024). https://arxiv.org/abs/2407.21787
- [X1] Tam et al., "Let Me Speak Freely?" EMNLP 2024 Industry, https://aclanthology.org/2024.emnlp-industry.91/ ; "Capacity, Not Format: Rethinking Structured Reasoning Failures" (2026), https://arxiv.org/abs/2606.09410

**벤더·실무 (V)**
- [V1] Anthropic, "How we built our multi-agent research system" (2025-06). https://www.anthropic.com/engineering/multi-agent-research-system
- [V2] Anthropic, "Effective context engineering for AI agents" (2025-09). https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- [V3] Cognition, "Don't Build Multi-Agents" (2025-06). https://cognition.com/blog/dont-build-multi-agents
- [V4] Cognition, "Multi-Agents: What's Actually Working" (2026). https://cognition.com/blog/multi-agents-working

**PLAIF 도메인 (P)**
- [P1] Arazo et al., "Pseudo-Labeling and Confirmation Bias in Deep Semi-Supervised Learning," IJCNN 2020. https://arxiv.org/abs/1908.02983
- [P2] "AutoVDC: Automated Vision Data Cleaning Using Vision-Language Models" (2025). https://arxiv.org/abs/2507.12414
- [P3] "VLAMotor: Test-Guided Enhancement of Vision-Language-Action Models via Agent-Based Data Synthesis" (2026). https://arxiv.org/abs/2606.00053
- [P4] "Human-Corrected Labels Learning: Enhancing Labels Quality via Human Correction of VLMs Discrepancies," AAAI 2026. https://doi.org/10.1609/aaai.v40i28.39504
