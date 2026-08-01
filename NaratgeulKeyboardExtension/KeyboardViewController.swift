import QuartzCore
import SwiftUI
import UIKit

/// 키 누를 때 시스템 클릭음을 내려면 입력 뷰가 이 프로토콜을 따라야 한다.
/// 전체 접근 권한 없이도 동작한다.
extension UIInputView: @retroactive UIInputViewAudioFeedback {
    public var enableInputClicksWhenVisible: Bool { true }
}

final class KeyboardViewController: UIInputViewController {

    private let engine = NaratgeulEngine()

    /// 문서에 마지막으로 써 넣은 조합 중인 글자. 항상 0자 또는 1자.
    private var preeditInDocument = ""

    private var hostingController: UIHostingController<KeyboardRootView>?
    private var heightConstraint: NSLayoutConstraint?

    /// 키 눌림 햅틱. 전체 접근 권한이 있을 때만 실제로 진동한다.
    private let feedback = UIImpactFeedbackGenerator(style: .light)

    /// 마지막으로 진동을 낸 시각.
    private var lastHapticTime: CFTimeInterval = 0

    /// 우리가 문서를 고치는 중인지.
    ///
    /// `textDidChange` 는 우리가 넣고 지운 글자 때문에도 불린다.
    /// 그때마다 문맥을 다시 읽으면 키 하나에 프로세스 왕복이 두어 번 더 붙는다.
    private var isApplying = false

    // MARK: - 생명주기

    override func viewDidLoad() {
        super.viewDidLoad()
        // 높이를 우리가 직접 정한다고 시스템에 알린다.
        inputView?.allowsSelfSizing = true
        installKeyboardView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // viewDidLoad 시점의 traitCollection 은 아직 확정 전이라 높이가 틀릴 수 있다.
        // 그대로 두면 키보드가 한 번 올라온 뒤 한 프레임 뒤에 높이가 튄다.
        updateHeight()
        // 햅틱 엔진을 미리 깨워 둔다. 안 하면 첫 진동이 눈에 띄게 늦다.
        if hasFullAccess { feedback.prepare() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 키보드가 내려갈 때 조합 중인 글자를 확정한다.
        // 이걸 안 하면 다시 올라왔을 때 이전 상태가 남아 오입력이 난다.
        finishComposing()
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateHeight()
        })
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // 우리가 방금 넣거나 지운 글자 때문에도 불린다. 그건 건너뛴다.
        guard !isApplying else { return }
        // 조합 중인 글자가 없으면 확인할 것도 없다. 문맥을 아예 안 읽는다.
        guard !preeditInDocument.isEmpty else { return }
        syncWithDocument(textDocumentProxy.documentContextBeforeInput)
    }

    // MARK: - 뷰 구성

    private func installKeyboardView() {
        let root = KeyboardRootView(
            onAction: { [weak self] action in
                self?.handle(action)
            },
            showsNextKeyboardKey: needsInputModeSwitchKey
        )

        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        // SwiftUI 가 홈 인디케이터 여백을 한 번 더 넣지 않게 막는다.
        // 이걸 빼면 iOS 17 이후 기종에서 아래 행이 잘린다.
        if #available(iOS 16.4, *) {
            host.safeAreaRegions = []
        }

        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)

        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // 시스템이 걸어 두는 제약과 충돌하면 앱이 죽는다. 우선순위를 한 단계 낮춘다.
        let height = view.heightAnchor.constraint(equalToConstant: currentHeight)
        height.priority = .required - 1
        height.isActive = true
        heightConstraint = height

        hostingController = host
    }

    private var currentHeight: CGFloat {
        KeyboardTheme.totalHeight(compact: traitCollection.verticalSizeClass == .compact)
    }

    private func updateHeight() {
        guard let heightConstraint else { return }
        let target = currentHeight
        guard abs(heightConstraint.constant - target) > 0.5 else { return }
        heightConstraint.constant = target
    }

    // MARK: - 키 처리

    private func handle(_ action: KeyAction) {
        // 눌린 느낌이 글자보다 먼저 오도록 피드백을 맨 앞에 둔다.
        // 아래 문서 작업은 호스트 앱과 프로세스를 오가느라 늘 얼마간 걸린다.
        playFeedback()

        switch action {
        case .hangul(let key):
            run(key)

        case .insert(let text):
            run(.literal(text))

        case .cycleSymbol(let options):
            run(.cycle(options))

        case .backspace:
            run(.backspace)

        case .space:
            run(.space)

        case .newline:
            run(.newline)

        case .switchLayer, .cycleLayer:
            // 레이어 전환 자체는 KeyboardRootView 가 처리한다. 여기선 조합만 확정한다.
            finishComposing()

        case .shift:
            break

        case .nextKeyboard:
            finishComposing()
            advanceToNextInputMode()
        }
    }

    /// 엔진에 키를 넘기고 결과를 문서에 반영한다.
    ///
    /// `documentContextBeforeInput` 은 호스트 앱에서 프로세스 너머로 가져오는 값이라
    /// 키 입력 경로에서 제일 비싸다. 예전엔 한 번 누를 때마다 상태 확인용으로 한 번,
    /// 엔진에 넘기려고 또 한 번 읽었다. 이제 한 번만 읽고 돌려 쓴다.
    /// 레이어 전환처럼 문서를 안 건드리는 키는 아예 읽지 않는다.
    private func run(_ key: NaratgeulKey) {
        let context = textDocumentProxy.documentContextBeforeInput
        // 사용자가 커서를 옮겼을 수 있다. 엔진을 부르기 전에 문서와 상태를 맞춘다.
        syncWithDocument(context)
        apply(engine.handle(key, contextBefore: contextBeforeCursor(context)))
    }

    /// 키 눌림 피드백.
    ///
    /// 소리는 권한 없이도 나지만 햅틱은 전체 접근 권한이 있어야 한다.
    /// 권한이 없으면 `impactOccurred` 를 불러도 조용히 무시된다.
    private func playFeedback() {
        UIDevice.current.playInputClick()

        guard hasFullAccess else { return }
        // 백스페이스를 꾹 눌러 연속 삭제할 때는 초당 열대여섯 번씩 불린다.
        // 그 속도로 진동을 다 내면 뭉개져서 오히려 지저분하다. 소리만 따라가게 둔다.
        let now = CACurrentMediaTime()
        guard now - lastHapticTime > 0.07 else { return }
        lastHapticTime = now

        feedback.impactOccurred(intensity: 0.7)
        // 연타할 때 두 번째부터 진동이 약해지지 않게 매번 다시 깨운다.
        feedback.prepare()
    }

    /// 엔진 결과를 문서에 반영한다.
    ///
    /// iOS 에는 안드로이드 IME 같은 preedit API 가 없다.
    /// 조합 중인 글자를 직접 넣었다가 지우고 다시 넣는 식으로 흉내 낸다.
    private func apply(_ output: KeyOutput) {
        let proxy = textDocumentProxy

        isApplying = true
        // 호스트 앱에서 textDidChange 가 돌아온 뒤에 푼다.
        defer { DispatchQueue.main.async { [weak self] in self?.isApplying = false } }

        // 1. 문서에 남아 있는 이전 조합 글자를 지운다
        if !preeditInDocument.isEmpty {
            proxy.deleteBackward()
            preeditInDocument = ""
        }

        // 2. 엔진이 요구한 만큼 확정된 글자를 지운다
        for _ in 0 ..< output.deleteCommitted {
            proxy.deleteBackward()
        }

        // 3. 확정된 글자를 넣는다
        if !output.commit.isEmpty {
            proxy.insertText(output.commit)
        }

        // 4. 새 조합 글자를 넣는다
        if !output.preedit.isEmpty {
            proxy.insertText(output.preedit)
            preeditInDocument = output.preedit
        }
    }

    /// 조합 중인 글자가 아직 커서 바로 앞에 있는지 확인한다.
    ///
    /// 사용자가 화면을 탭해 커서를 옮기면 우리가 넣어 둔 조합 글자는
    /// 더 이상 커서 앞에 없다. 그대로 두면 다음 키 입력 때
    /// 엉뚱한 글자를 지우게 된다. 어긋났으면 조합을 버리고 새로 시작한다.
    private func syncWithDocument(_ context: String?) {
        guard !preeditInDocument.isEmpty else { return }
        // 보안 입력 필드에서는 앞 문맥을 못 읽는다 (nil). 이때는 그대로 믿고 간다.
        guard let context else { return }
        if !context.hasSuffix(preeditInDocument) {
            finishComposing()
        }
    }

    /// 커서 앞 텍스트. 보안 입력 필드에서는 빈 문자열이 올 수 있다.
    ///
    /// 조합 중인 글자는 이미 문서에 들어가 있으므로 잘라내고 넘긴다.
    private func contextBeforeCursor(_ context: String?) -> String? {
        guard var context else { return nil }
        if !preeditInDocument.isEmpty, context.hasSuffix(preeditInDocument) {
            context.removeLast(preeditInDocument.count)
        }
        return context.isEmpty ? nil : context
    }

    /// 조합을 확정하고 상태를 비운다. 문서 내용은 그대로 둔다.
    private func finishComposing() {
        engine.reset()
        preeditInDocument = ""
    }
}
