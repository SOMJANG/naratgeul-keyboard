import SwiftUI
import UIKit

/// 키 하나.
///
/// 터치는 SwiftUI 제스처가 아니라 `KeyTouchArea` 를 통해 UIKit 에서 바로 받는다.
/// 이유는 그쪽 주석에 적어 뒀다.
struct KeyButton: View {
    let definition: KeyDefinition
    let onPress: (KeyPress) -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isPressed = false
    @State private var repeatTask: Task<Void, Never>?

    /// 꾹 누르고 있으면 반복되는 키인지. 지금은 백스페이스뿐이다.
    private var repeatsOnHold: Bool { definition.action == .backspace }

    private var fill: Color {
        switch (definition.style, isPressed) {
        case (.character, false): return KeyboardTheme.characterKey(scheme)
        case (.character, true): return KeyboardTheme.characterKeyPressed(scheme)
        case (.function, false): return KeyboardTheme.functionKey(scheme)
        case (.function, true): return KeyboardTheme.functionKeyPressed(scheme)
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: KeyboardTheme.keyCornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            // 키 아래 그림자 한 줄.
            // `.shadow()` 는 반경이 0이어도 블러 패스를 만든다. 같은 모양을 1pt 내려 깔면 그만이다.
            // 눌렸을 때 뷰를 빼지 않고 색만 투명으로 바꾼다. 뷰를 넣고 빼면
            // 그때마다 레이아웃이 다시 돌아서 눌림 표시가 한 박자 늦는다.
            shape
                .fill(isPressed ? .clear : KeyboardTheme.keyShadow(scheme))
                .offset(y: 1)

            shape.fill(fill)

            Group {
                if let symbol = definition.symbol {
                    Image(systemName: symbol)
                } else {
                    Text(definition.label)
                }
            }
            .font(.system(size: definition.fontSize, weight: definition.style == .function ? .medium : .regular))
            .foregroundColor(KeyboardTheme.keyLabel(scheme))

            if let number = definition.number {
                VStack {
                    HStack {
                        Spacer()
                        Text(number)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(KeyboardTheme.keyNumber(scheme))
                    }
                    Spacer()
                }
                .padding(.top, 4)
                .padding(.trailing, 5)
            }
        }
        // 높이를 고정하지 않고 늘어나게 둔다.
        // 전체 높이는 KeyboardViewController 의 제약이 정하고,
        // 가로 모드처럼 공간이 좁아지면 키가 알아서 줄어든다.
        .frame(maxWidth: .infinity, minHeight: 28, maxHeight: .infinity)
        .overlay(KeyTouchArea(onDown: press, onUp: release))
        .onDisappear(perform: stopRepeating)
        .accessibilityLabel(definition.label)
        .accessibilityAddTraits(.isKeyboardKey)
        .keyWidthRatio(definition.widthRatio)
    }

    // MARK: - 누름 처리

    private func press() {
        isPressed = true
        onPress(KeyPress(action: definition.action))
        startRepeating()
    }

    private func release() {
        isPressed = false
        stopRepeating()
    }

    /// 꾹 누르고 있는 동안 반복 입력.
    ///
    /// 네이티브 키보드와 비슷하게 잠깐 뜸을 들였다가 시작하고, 조금 지나면 빨라진다.
    /// 뜸을 안 들이면 그냥 한 번 누른 것도 두 번 지워진다.
    private func startRepeating() {
        guard repeatsOnHold else { return }
        repeatTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)

            var interval: UInt64 = 100_000_000
            var count = 0
            // 손을 뗐는데도 취소가 안 들어온 경우를 대비한 상한.
            // 20초쯤 누르고 있는 것과 같아서 정상적으로는 닿지 않는다.
            while !Task.isCancelled, count < 400 {
                onPress(KeyPress(action: definition.action, isRepeat: true))
                count += 1
                if count == 12 { interval = 60_000_000 }
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    private func stopRepeating() {
        repeatTask?.cancel()
        repeatTask = nil
    }
}

/// 키 한 행. 각 키가 `widthRatio` 에 비례해 가로를 나눠 갖는다.
///
/// `HStack` 에 `.frame(maxWidth: .infinity)` 를 얹으면 남는 자리를 똑같이 쪼개기만 해서
/// "이 키는 옆 키의 0.75배" 를 표현할 수 없다. 키보드 전체에 공통 단위 폭을 두는 방법도
/// 맞지 않는다. 행마다 비율의 합이 다르기 때문이다 (영문 셋째 줄은 1.4 + 7 + 1.4).
/// 그래서 행 단위로 직접 나눈다.
struct KeyRow: Layout {
    var spacing: CGFloat = KeyboardTheme.keyGap

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(
            width: finite(proposal.width) ?? 0,
            height: finite(proposal.height)
                ?? subviews.map { $0.sizeThatFits(.unspecified).height }.max()
                ?? KeyboardTheme.keyHeight
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard !subviews.isEmpty else { return }

        let ratios = subviews.map { max(0, $0[KeyWidthRatioKey.self]) }
        let total = ratios.reduce(0, +)
        guard total > 0 else { return }

        let gaps = spacing * CGFloat(subviews.count - 1)
        let unit = max(0, bounds.width - gaps) / total

        var x = bounds.minX
        for (index, subview) in subviews.enumerated() {
            let width = unit * ratios[index]
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            x += width + spacing
        }
    }

    /// 제안 값이 없거나 무한대면 쓸 수 없다.
    private func finite(_ value: CGFloat?) -> CGFloat? {
        guard let value, value.isFinite else { return nil }
        return value
    }
}

/// 키가 행에서 차지할 가로 비율. `KeyRow` 가 읽는다.
private struct KeyWidthRatioKey: LayoutValueKey {
    static let defaultValue: CGFloat = 1
}

extension View {
    /// 이 뷰가 `KeyRow` 안에서 차지할 가로 비율.
    ///
    /// `KeyRow` 가 아닌 곳에서는 아무 영향이 없다.
    func keyWidthRatio(_ ratio: CGFloat) -> some View {
        layoutValue(key: KeyWidthRatioKey.self, value: ratio)
    }
}

/// 키의 터치를 UIKit 에서 그대로 받아 넘긴다.
///
/// SwiftUI 의 `DragGesture(minimumDistance: 0)` 도 누르는 즉시 불리긴 하지만,
/// 제스처인 이상 상위 인식기들과 경쟁을 거친다. 키보드는 그 한 박자가 그대로 느껴진다.
/// `touchesBegan` 은 히트 테스트된 뷰에 경쟁 없이 바로 온다.
///
/// 키마다 자기 터치를 따로 받기 때문에 빠르게 두 키를 겹쳐 눌러도 서로 먹히지 않는다.
private struct KeyTouchArea: UIViewRepresentable {
    let onDown: () -> Void
    let onUp: () -> Void

    func makeUIView(context: Context) -> TouchView {
        let view = TouchView()
        view.backgroundColor = .clear
        // 접근성은 SwiftUI 쪽 KeyButton 이 이미 붙여 뒀다. 여기서 또 노출하면 두 번 읽힌다.
        view.isAccessibilityElement = false
        view.onDown = onDown
        view.onUp = onUp
        return view
    }

    func updateUIView(_ view: TouchView, context: Context) {
        view.onDown = onDown
        view.onUp = onUp
    }

    final class TouchView: UIView {
        var onDown: () -> Void = {}
        var onUp: () -> Void = {}

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            onDown()
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            onUp()
        }

        /// 시스템이 터치를 가져가는 경우 (전화 수신, 키보드 내려감 등).
        /// 여기서 안 풀면 눌린 표시와 반복 입력이 그대로 남는다.
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            onUp()
        }
    }
}
