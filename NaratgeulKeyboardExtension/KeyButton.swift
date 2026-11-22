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
    @Environment(\.keyGap) private var gap
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
        // 키 사이 틈은 키 바깥이 아니라 키 안쪽 여백이다. 그려지는 모양은 그대로지만
        // 터치는 틈의 절반씩까지 이 키가 받는다. 틈을 빈 자리로 두면 키보드 넓이의
        // 4분의 1쯤이 아무 반응 없는 곳이 되고, 조금 빗나간 터치가 그대로 씹힌다.
        .padding(.horizontal, gap / 2)
        .padding(.vertical, KeyboardTheme.rowGap / 2)
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
        // 두 손가락이 같은 키에 겹쳐 닿으면 여기로 두 번 온다. 앞의 반복을 놓치면 안 멈춘다.
        stopRepeating()
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
/// 키 사이 틈(`spacing`)은 비워 두지 않고 양옆 키에 절반씩 얹어 준다.
/// 그 틈을 안쪽 여백으로 그리는 건 `KeyButton` 몫이다. 그래서 양 끝 키는
/// 행 바깥으로 틈의 절반만큼 나간다.
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

        var x = bounds.minX - spacing / 2
        for (index, subview) in subviews.enumerated() {
            let width = unit * ratios[index] + spacing
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            x += width
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

/// 옆 키와의 틈. `KeyButton` 이 이 값의 절반씩을 좌우 안쪽 여백으로 쓴다.
private struct KeyGapKey: EnvironmentKey {
    static let defaultValue: CGFloat = KeyboardTheme.keyGap
}

extension EnvironmentValues {
    var keyGap: CGFloat {
        get { self[KeyGapKey.self] }
        set { self[KeyGapKey.self] = newValue }
    }
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
/// 같은 키를 두 손가락으로 번갈아 칠 때도 마찬가지다. 앞 손가락이 채 떨어지기 전에
/// 닿은 두 번째 터치도 따로 센다.
private struct KeyTouchArea: UIViewRepresentable {
    let onDown: () -> Void
    let onUp: () -> Void

    func makeUIView(context: Context) -> TouchView {
        let view = TouchView()
        // 완전히 투명하면 안 된다. 키보드 확장은 아무것도 그려지지 않은 자리의 터치를
        // 받지 못해서, 키 사이 틈(이 뷰만 덮고 있는 자리)에 닿은 터치가 그대로 버려진다.
        // 눈에 안 보일 만큼만 칠해 둔다.
        view.backgroundColor = UIColor(white: 1, alpha: 0.001)
        // 기본값(false)이면 한 손가락이 닿아 있는 동안 같은 키에 온 다른 터치는 버려진다.
        view.isMultipleTouchEnabled = true
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

        /// 지금 이 키에 닿아 있는 손가락 수.
        private var activeTouches = 0

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches {
                record("Touch down", touch)
                activeTouches += 1
                onDown()
            }
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            touches.forEach { record("Touch up", $0) }
            lift(touches.count)
        }

        /// 시스템이 터치를 가져가는 경우 (전화 수신, 키보드 내려감 등).
        /// 여기서 안 풀면 눌린 표시와 반복 입력이 그대로 남는다.
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            touches.forEach { record("Touch cancel", $0) }
            lift(touches.count)
        }

        /// 손가락이 실제로 닿거나 떨어진 시각부터 이 뷰에 전달되기까지 걸린 시간을 남긴다.
        ///
        /// `UITouch.timestamp` 와 `CACurrentMediaTime()` 은 둘 다 부팅 후 경과 시간이라 바로 뺄 수 있다.
        /// 가장자리 열(x 가 작거나 큰 쪽)만 늦으면 창의 제스처 인식기가 붙잡고 있는 것이다.
        private func record(_ name: StaticString, _ touch: UITouch) {
            let delay = (CACurrentMediaTime() - touch.timestamp) * 1000
            let x = touch.location(in: nil).x
            KeyboardPerf.signposter.emitEvent(
                name,
                "delay=\(delay, format: .fixed(precision: 1))ms x=\(Int(x)) taps=\(touch.tapCount)"
            )
        }

        /// 마지막 손가락이 떨어졌을 때만 눌림을 푼다.
        private func lift(_ count: Int) {
            activeTouches = max(0, activeTouches - count)
            if activeTouches == 0 { onUp() }
        }
    }
}
