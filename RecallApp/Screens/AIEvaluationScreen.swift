#if DEBUG
import SwiftUI

struct AIEvaluationScreen: View {
    @State private var runner = AIEvaluationRunner()
    @State private var runSize: AIEvaluationRunSize = .full
    @State private var runTask: Task<Void, Never>?

    var body: some View {
        Form {
            benchmarkControlsSection
            summarySection
            domainSection
            confusionSection
            mismatchesSection
            failuresSection
            runStatusSection
            predictionsExportSection
        }
        .navigationTitle("AI Evaluation Lab")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            runTask?.cancel()
        }
    }

    @ViewBuilder
    private var benchmarkControlsSection: some View {
        Section("Run Benchmark") {
            Picker("Run size", selection: $runSize) {
                ForEach(AIEvaluationRunSize.allCases) { size in
                    Text(size.title).tag(size)
                }
            }

            if runner.isRunning {
                ProgressView(value: progressValue, total: 1.0)
                if let currentCaseDescription = runner.currentCaseDescription {
                    Text("Grading \(currentCaseDescription)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button("Cancel Run", role: .cancel) {
                    runTask?.cancel()
                }
                .accessibilityLabel("Cancel benchmark run")
                .accessibilityHint("Stops the current AI grading evaluation")
            } else {
                Button("Run AI Benchmark") {
                    runTask = Task {
                        await runner.run(size: runSize)
                    }
                }
                .accessibilityLabel("Run AI benchmark")
                .accessibilityHint("Runs the internal AI grading benchmark inside the app")
            }

            if let completedAt = runner.completedAt {
                LabeledContent("Last run") {
                    Text(completedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        if let report = runner.report {
            Section("Summary") {
                metricRow(title: "Predictions", value: "\(report.predictionsProvided)", detail: "Saved to temp JSON")
                metricRow(title: "Failures", value: "\(report.failures.count)", detail: "Cases that returned invalid output")
                metricRow(title: "Coverage", value: formattedPercent(report.coverage), detail: "\(report.matchedCount)/\(report.datasetCaseCount)")
                metricRow(title: "Rating accuracy", value: formattedPercent(report.ratingAccuracy), detail: "\(report.ratingCorrectCount)/\(report.matchedCount)")
                metricRow(title: "False easy", value: formattedPercent(report.falseEasyRate), detail: "\(report.falseEasyCount)/\(report.easyOpportunities)")
                metricRow(title: "False forgot", value: formattedPercent(report.falseForgotRate), detail: "\(report.falseForgotCount)/\(report.forgotOpportunities)")

                if let primaryFeedbackAccuracy = report.primaryFeedbackAccuracy {
                    metricRow(
                        title: "Primary feedback",
                        value: formattedPercent(primaryFeedbackAccuracy),
                        detail: "\(report.primaryFeedbackMatches)/\(report.primaryFeedbackEvaluated)"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var failuresSection: some View {
        if let report = runner.report, !report.failures.isEmpty {
            Section("Case Failures") {
                ForEach(Array(report.failures.prefix(12))) { failure in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(failure.term)
                            .font(.headline)
                        Text(failure.domain)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        LabeledContent("Case ID") {
                            Text(failure.id)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Text(failure.errorDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var domainSection: some View {
        if let report = runner.report {
            Section("Per Domain") {
                ForEach(report.domainSummaries) { summary in
                    metricRow(
                        title: summary.domain,
                        value: formattedPercent(summary.accuracy),
                        detail: "\(summary.correct)/\(summary.total)"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var confusionSection: some View {
        if let report = runner.report {
            Section("Confusion Matrix") {
                ForEach(report.confusionRows) { row in
                    confusionRowView(row)
                }
            }
        }
    }

    @ViewBuilder
    private var mismatchesSection: some View {
        if let report = runner.report, !report.mismatches.isEmpty {
            Section("Rating Mismatches") {
                ForEach(Array(report.mismatches.prefix(12))) { mismatch in
                    mismatchRowView(mismatch)
                }
            }
        }
    }

    @ViewBuilder
    private var runStatusSection: some View {
        if let lastErrorMessage = runner.lastErrorMessage {
            Section("Run Status") {
                Text(lastErrorMessage)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var predictionsExportSection: some View {
        if let exportedPredictionsPath = runner.exportedPredictionsPath {
            Section {
                Text(exportedPredictionsPath)
                    .font(.footnote)
                    .textSelection(.enabled)
            } header: {
                Text("Predictions Export")
            } footer: {
                Text("The latest benchmark predictions are written to a temporary JSON file for external scoring or inspection.")
            }
        }
    }

    private var progressValue: Double {
        guard runner.totalCount > 0 else { return 0 }
        return Double(runner.processedCount) / Double(runner.totalCount)
    }

    @ViewBuilder
    private func metricRow(title: String, value: String, detail: String) -> some View {
        LabeledContent(title) {
            VStack(alignment: .trailing, spacing: 4) {
                Text(value)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func confusionRowView(_ row: AIEvaluationConfusionRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Expected \(row.expectedRating)")
                .font(.headline)
            LabeledContent("Predicted Forgot") {
                Text("\(row.forgotCount)")
            }
            LabeledContent("Predicted Hard") {
                Text("\(row.hardCount)")
            }
            LabeledContent("Predicted Easy") {
                Text("\(row.easyCount)")
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func mismatchRowView(_ mismatch: AIEvaluationMismatch) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mismatch.term)
                .font(.headline)
            Text(mismatch.domain)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            LabeledContent("Case ID") {
                Text(mismatch.id)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Expected") {
                Text(mismatch.expectedRating)
            }
            LabeledContent("Predicted") {
                Text(mismatch.predictedRating)
            }
            LabeledContent("Expected feedback") {
                Text(mismatch.expectedPrimaryFeedbackCategory)
            }
            LabeledContent("Predicted feedback") {
                Text(mismatch.predictedPrimaryFeedbackCategory ?? "None")
            }
        }
    }

    private func formattedPercent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(1)))
    }
}

#Preview("AI Evaluation Lab") {
    NavigationStack {
        AIEvaluationScreen()
    }
}
#endif
