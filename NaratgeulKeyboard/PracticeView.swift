import SwiftUI

/// 연습 모드 첫 화면. 단계를 고른다.
struct PracticeView: View {
    /// 끝낸 단계. 앱을 껐다 켜도 남는다.
    @AppStorage("practice.clearedStages") private var clearedRaw = ""

    private var cleared: Set<String> {
        Set(clearedRaw.split(separator: "\n").map(String.init))
    }

    var body: some View {
        List {
            Section {
                ForEach(PracticeCourse.stages) { stage in
                    NavigationLink {
                        PracticeSessionView(stage: stage, onFinish: { markCleared(stage) })
                    } label: {
                        row(stage)
                    }
                }
            } footer: {
                Text("나랏글 키보드로 쳐야 연습이 됩니다. 입력창을 누른 뒤 지구본 키로 나랏글을 골라 주세요.")
            }

            if !cleared.isEmpty {
                Section {
                    Button("연습 기록 지우기", role: .destructive) { clearedRaw = "" }
                }
            }
        }
        .navigationTitle("연습")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ stage: PracticeStage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: cleared.contains(stage.title)
                  ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(cleared.contains(stage.title) ? Color.accentColor : .secondary)
                .font(.title3)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(stage.title).font(.body.weight(.medium))
                Text(stage.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("\(stage.items.count)문제")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
    }

    private func markCleared(_ stage: PracticeStage) {
        guard !cleared.contains(stage.title) else { return }
        clearedRaw = clearedRaw.isEmpty ? stage.title : clearedRaw + "\n" + stage.title
    }
}

/// 한 단계를 처음부터 끝까지 치는 화면.
struct PracticeSessionView: View {
    let stage: PracticeStage
    let onFinish: () -> Void

    @State private var index = 0
    @State private var typed = ""
    @State private var showsKeyHint = false
    @State private var isDone = false
    @FocusState private var isFocused: Bool

    private var item: PracticeItem { stage.items[index] }

    /// 지금까지 친 게 정답의 앞부분과 맞는지.
    private var isOnTrack: Bool { item.text.hasPrefix(typed) }
    private var isComplete: Bool { typed == item.text }

    var body: some View {
        Group {
            if isDone { finishedView } else { practiceView }
        }
        .navigationTitle(stage.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isFocused = true }
    }

    // MARK: - 연습 중

    private var practiceView: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(index), total: Double(stage.items.count))
                .padding(.horizontal)
                .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    targetCard
                    if !item.hint.isEmpty { hintLine }
                    inputCard
                    keyHintSection
                }
                .padding()
            }

            footer
        }
    }

    /// 쳐야 할 글자. 맞게 친 데까지는 흐리게 지워 나간다.
    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(index + 1) / \(stage.items.count)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(attributedTarget)
                .font(.system(size: 30, weight: .medium))
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var attributedTarget: AttributedString {
        var result = AttributedString()
        let done = isOnTrack ? typed.count : 0
        for (offset, character) in item.text.enumerated() {
            var piece = AttributedString(String(character))
            piece.foregroundColor = offset < done ? .secondary : .primary
            result += piece
        }
        return result
    }

    private var hintLine: some View {
        Label(item.hint, systemImage: "lightbulb")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("여기에 따라 쳐 보세요", text: $typed, axis: .vertical)
                .font(.system(size: 24))
                .lineLimit(1 ... 4)
                .focused($isFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(borderColor, lineWidth: 1.5)
                )

            Text(statusText)
                .font(.footnote)
                .foregroundStyle(isOnTrack ? .secondary : Color.red)
        }
    }

    private var borderColor: Color {
        if isComplete { return .green }
        if !isOnTrack { return .red }
        return .clear
    }

    private var statusText: String {
        if isComplete { return "맞았습니다" }
        if !isOnTrack { return "다른 글자가 들어갔습니다. ⌫ 로 지우고 다시 쳐 보세요" }
        if typed.isEmpty { return " " }
        return "\(typed.count) / \(item.text.count) 글자"
    }

    /// 어떤 키를 어떤 순서로 누르는지.
    ///
    /// 처음 쓰는 사람은 "ㅋ 이 어디 있지" 에서 막힌다. 답을 통째로 보여 주는 대신
    /// 눌러야 접히도록 두어서, 먼저 스스로 찾아보게 한다.
    @ViewBuilder
    private var keyHintSection: some View {
        if let keys = KeySequence.keys(for: item.text) {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { showsKeyHint.toggle() }
                } label: {
                    Label(
                        showsKeyHint ? "누르는 순서 접기" : "누르는 순서 보기",
                        systemImage: showsKeyHint ? "chevron.up" : "chevron.down"
                    )
                    .font(.subheadline)
                }

                if showsKeyHint {
                    FlowLayout(spacing: 6) {
                        ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                            Text(key.practiceLabel)
                                .font(.system(size: 15, weight: .medium))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(Color(.tertiarySystemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .strokeBorder(Color(.separator), lineWidth: 0.5)
                                )
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("지우기") { typed = "" }
                .buttonStyle(.bordered)
                .disabled(typed.isEmpty)

            Button(index == stage.items.count - 1 ? "끝내기" : "다음") { advance() }
                .buttonStyle(.borderedProminent)
                .disabled(!isComplete)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(.bar)
    }

    private func advance() {
        typed = ""
        showsKeyHint = false
        if index == stage.items.count - 1 {
            onFinish()
            isDone = true
        } else {
            index += 1
        }
    }

    // MARK: - 다 끝냈을 때

    private var finishedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("\(stage.title) 끝")
                .font(.title2.weight(.semibold))
            Text("\(stage.items.count)문제를 다 쳤습니다.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("다시 하기") {
                index = 0
                typed = ""
                isDone = false
                isFocused = true
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .padding()
    }
}

/// 키 힌트를 줄 넘겨 가며 늘어놓는다. `HStack` 은 넘치면 잘려서 쓸 수 없다.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, width: width)
        let height = rows.reduce(0) { $0 + $1.height } +
            CGFloat(max(0, rows.count - 1)) * spacing
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        var y = bounds.minY
        for row in arrange(subviews: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if needed > width, !row.indices.isEmpty {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

#Preview {
    NavigationStack { PracticeView() }
}
