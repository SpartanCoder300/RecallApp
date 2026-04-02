# AI Grading Evaluation

This evaluation harness gives the grading system a fixed benchmark before prompt or model changes ship.

## Dataset

The canonical benchmark lives in:

- `docs/ai-grading-eval-dataset.json`

Each row contains:

- `term`
- `note`
- rubric fields: `keyFacts`, `acceptedSynonyms`, `commonConfusions`
- `recalledText`
- human labels: `expectedRating`, `expectedPrimaryFeedbackCategory`, optional `expectedSecondaryFeedbackCategory`

## Scorer

Run the evaluator with:

```bash
swift scripts/evaluate_grading.swift \
  --dataset docs/ai-grading-eval-dataset.json \
  --predictions path/to/predictions.json
```

It reports:

- coverage
- rating accuracy
- false easy rate
- false forgot rate
- confusion matrix
- per-domain accuracy
- primary feedback-category accuracy when provided

## Live Runner

To evaluate the actual app grader against the benchmark in one command:

```bash
scripts/run_grading_eval.sh
```

This will:

1. run `AnswerGradingService` across every case in the benchmark
2. write the live model outputs to `/tmp/ai-grading-live-predictions.json`
3. score those outputs with the evaluator

Optional flags:

```bash
scripts/run_grading_eval.sh \
  --dataset docs/ai-grading-eval-dataset.json \
  --predictions-out /tmp/my-grading-predictions.json
```

For a smaller smoke test:

```bash
scripts/run_grading_eval.sh --limit 5
```

## In-App Lab

For the most faithful runtime test, run the benchmark inside the app host:

1. Open `Settings`
2. Open `AI Evaluation Lab` in the debug-only `Internal Tools` section
3. Choose `Smoke 5`, `Smoke 20`, or `Full 100`
4. Tap `Run AI Benchmark`

The screen uses `AnswerGradingService` directly, shows the same core metrics as the scorer, and writes predictions to a temporary JSON file on-device.

## Prediction Template

Generate a blank file for model outputs:

```bash
swift scripts/evaluate_grading.swift \
  --dataset docs/ai-grading-eval-dataset.json \
  --write-template /tmp/grading-predictions.json
```

Generate a perfect-baseline file from the human labels:

```bash
swift scripts/evaluate_grading.swift \
  --dataset docs/ai-grading-eval-dataset.json \
  --write-expected /tmp/grading-expected.json
```

Then score it:

```bash
swift scripts/evaluate_grading.swift \
  --dataset docs/ai-grading-eval-dataset.json \
  --predictions /tmp/grading-expected.json
```

## Interpreting Metrics

- False easy is the most dangerous metric. It means the model passed weak answers.
- False forgot catches overly harsh grading.
- Overall accuracy matters less than the error shape. A grader with acceptable accuracy but high false easy is still unsafe.
- Per-domain accuracy helps identify prompt drift on specialized content.
