import CoreHaptics
import os
import QuartzCore
import SwiftUI
import UIKit

/// 입력 반응 속도 측정 지점.
///
/// Instruments 의 Points of Interest(또는 os_signpost) 트랙에 나온다.
/// 기록 중이 아닐 때는 거의 비용이 없어서 릴리스 빌드에도 그대로 둔다.
/// 사용자가 친 글자나 문서 내용은 남기지 않는다. 키 종류와 길이·개수만 남긴다.
///
/// 구간 이름:
/// - `Queue`: 키가 눌린 순간부터 문서 작업을 시작하기까지 (눌린 색 커밋 + 앞 키 대기).
///   레이어 전환 키는 이 구간에 새 레이어를 만드는 시간이 들어간다.
/// - `Dispatch`: 문서 작업 전체. 안쪽에 `Read context` · `Has text` · `Engine` · `Proxy edit`.
/// - `Feedback`: 클릭음 + 햅틱.
/// - `Load` · `Appear` · `Full access`: 키보드가 뜨는 구간.
/// - 이벤트 `Touch down` · `Touch up`: 터치가 실제로 일어난 시각부터 뷰에 닿기까지 걸린 시간.
enum KeyboardPerf {
    static let signposter = OSSignposter(
        subsystem: Bundle.main.bundleIdentifier ?? "NaratgeulKeyboardExtension",
        category: .pointsOfInterest
    )
}

extension KeyAction {
    /// 측정 기록에 남길 키 종류. 어떤 글자를 쳤는지는 남기지 않는다.
    var perfLabel: String {
        switch self {
        case .hangul: return "hangul"
        case .insert: return "insert"
        case .cycleSymbol: return "cycle"
        case .backspace: return "backspace"
        case .space: return "space"
        case .newline: return "newline"
        case .switchLayer, .cycleLayer: return "layer"
        case .nextKeyboard: return "nextKeyboard"
        case .shift: return "shift"
        }
    }
}

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
    private let haptics = KeyHaptics()

    /// 전체 접근 권한이 있는지.
    ///
    /// `hasFullAccess` 는 부를 때마다 시스템에 물어본다. 키마다 묻지 않고
    /// 올라올 때 한 번 받아 둔다. 권한은 설정 앱에서만 바뀌고 그러면 키보드가 다시 뜬다.
    private var fullAccessGranted = false

    /// 눌렸지만 아직 문서에 반영하지 않은 키. `handle` 이 쌓고 `drainPending` 이 비운다.
    /// 키마다 `Queue` 측정 구간을 같이 들고 간다.
    private var pending: [(press: KeyPress, queued: OSSignpostIntervalState)] = []

    /// `viewWillAppear` 에서 `viewDidAppear` 까지의 측정 구간.
    private var appearInterval: OSSignpostIntervalState?

    private var signposter: OSSignposter { KeyboardPerf.signposter }

    // MARK: - 생명주기

    override func viewDidLoad() {
        super.viewDidLoad()
        let loadInterval = signposter.beginInterval("Load")
        defer { signposter.endInterval("Load", loadInterval) }
        // 높이를 우리가 직접 정한다고 시스템에 알린다.
        inputView?.allowsSelfSizing = true
        installKeyboardView()

        // 호스트 앱이 잠깐 다른 앱에 갔다가 돌아올 때. 키보드 뷰는 그대로라
        // viewWillAppear 가 다시 불리지 않는다. 그 사이 호스트가 문서를 바꿨을 수 있으니
        // 조합 상태를 비워 둔다.
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSExtensionHostWillEnterForeground,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.finishComposing()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appearInterval = signposter.beginInterval("Appear", id: signposter.makeSignpostID())
        // 올라올 때마다 조합 상태를 비운다.
        // 보통은 내려갈 때 이미 비웠지만, 메모리 부족으로 확장이 중간에 죽었다 살아나거나
        // 알림 답장 창처럼 호스트가 바뀌는 경우 내려가는 쪽 콜백이 안 올 수 있다.
        // 이전 문서에서 쓰던 조합 글자가 남아 있으면 첫 입력부터 엉뚱한 글자를 지운다.
        finishComposing()
        // viewDidLoad 시점의 traitCollection 은 아직 확정 전이라 높이가 틀릴 수 있다.
        // 그대로 두면 키보드가 한 번 올라온 뒤 한 프레임 뒤에 높이가 튄다.
        updateHeight()
        signposter.withIntervalSignpost("Full access") {
            fullAccessGranted = hasFullAccess
            // 햅틱 엔진을 미리 깨워 둔다. 안 하면 첫 진동이 눈에 띄게 늦다.
            if fullAccessGranted { haptics.warmUp() }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let appearInterval {
            signposter.endInterval("Appear", appearInterval)
            self.appearInterval = nil
        }
        releaseEdgeTouchDelay()
    }

    /// 화면 가장자리 키가 늦게 눌리는 것을 푼다.
    ///
    /// 키보드 창에는 시스템이 화면 가장자리 쓸기(뒤로 가기, 제어 센터 등)를 가려내려고
    /// 걸어 둔 제스처 인식기가 있다. 이 인식기들이 가장자리에서 시작한 터치를 쥐고 있다가
    /// 쓸기가 아니라고 판단한 뒤에야 `touchesBegan` 을 넘겨준다. 그 사이 키는 눌린 표시도
    /// 못 내고 입력도 못 한다. 나랏글은 ㄱ·ㄹ·ㅅ·획 과 ⌫·간격·↵ 가 전부 가장자리 열이라
    /// 이 지연을 그대로 맞는다. 터치를 붙잡지 않게만 바꾼다. 쓸기 인식 자체는 그대로 돈다.
    private func releaseEdgeTouchDelay() {
        let recognizers = view.window?.gestureRecognizers ?? []
        // 터치 끝(`touchesEnded`)을 붙잡는 인식기가 몇 개나 남는지도 같이 남긴다.
        signposter.emitEvent(
            "Window recognizers",
            "count=\(recognizers.count) delaysBegan=\(recognizers.filter(\.delaysTouchesBegan).count) delaysEnded=\(recognizers.filter(\.delaysTouchesEnded).count)"
        )
        recognizers.forEach { $0.delaysTouchesBegan = false }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 키보드가 내려갈 때 조합 중인 글자를 확정한다.
        // 이걸 안 하면 다시 올라왔을 때 이전 상태가 남아 오입력이 난다.
        finishComposing()
        haptics.stop()
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

    // `textDidChange` 는 일부러 안 받는다.
    //
    // 우리가 넣고 지운 글자 때문에도 키마다 불리는데, 거기서 문맥을 읽으면
    // 키 하나에 프로세스 왕복이 하나 더 붙는다. 사용자가 커서를 옮겼는지는
    // 어차피 다음 키를 처리하기 직전에 `run` 이 확인하므로 여기서 미리 볼 이유가 없다.

    // MARK: - 뷰 구성

    private func installKeyboardView() {
        let root = KeyboardRootView(
            onAction: { [weak self] press in
                self?.handle(press)
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

    private func handle(_ press: KeyPress) {
        let queued = signposter.beginInterval(
            "Queue",
            id: signposter.makeSignpostID(),
            "\(press.action.perfLabel, privacy: .public) repeat=\(press.isRepeat)"
        )

        // 눌린 느낌이 글자보다 먼저 오도록 피드백을 맨 앞에 둔다.
        // 꾹 눌러 반복되는 삭제는 조용히 지나간다. 초당 열 번 넘게 딸깍거리면 시끄럽다.
        if !press.isRepeat {
            signposter.withIntervalSignpost("Feedback") { playFeedback() }
        }

        // 문서 작업은 호스트 앱과 프로세스를 오가느라 늘 얼마간 걸린다.
        // 호스트가 직전 입력을 처리하느라 바쁘면 그만큼 더 기다린다.
        // 여기서 바로 하면 키의 눌린 색이 그 뒤에야 그려져서 손가락보다 한 박자 늦게
        // 반응하는 것처럼 보인다. 눌린 색이 들어간 화면 갱신이 먼저 나가고 나서 하도록
        // 이번 트랜잭션이 끝난 직후로 미룬다. 추가 프레임을 기다리지는 않는다.
        //
        // 완료 블록에 키를 직접 물리지 않고 줄에 세운다. 호스트가 바빠 메인 스레드가
        // 막혀 있던 동안 밀린 터치는 한 트랜잭션 안에 몰아서 들어오는데,
        // 완료 블록은 트랜잭션에 하나뿐이라 나중 것이 앞의 것을 덮어쓴다.
        // 키를 블록에 실어 두면 그때 앞의 키가 사라진다.
        pending.append((press, queued))
        CATransaction.setCompletionBlock { [weak self] in
            self?.drainPending()
        }
    }

    private func drainPending() {
        while !pending.isEmpty {
            let (press, queued) = pending.removeFirst()
            // backlog 는 이 키 뒤에 아직 밀려 있는 키 수. 0 이 아니면 메인 스레드가 막혀 있었다는 뜻이다.
            let backlog = pending.count
            signposter.endInterval("Queue", queued, "backlog=\(backlog)")
            let dispatching = signposter.beginInterval(
                "Dispatch",
                id: signposter.makeSignpostID(),
                "\(press.action.perfLabel, privacy: .public) repeat=\(press.isRepeat)"
            )
            dispatch(press)
            signposter.endInterval("Dispatch", dispatching)
        }
    }

    /// 커서 앞 문맥을 읽는다. 측정 구간을 씌우려고 한 곳으로 모았다.
    private func readContext() -> String? {
        let state = signposter.beginInterval("Read context")
        let context = textDocumentProxy.documentContextBeforeInput
        // 길이만 남긴다. 내용은 사용자가 쓴 글이다.
        signposter.endInterval("Read context", state, "length=\(context?.count ?? -1)")
        return context
    }

    private func dispatch(_ press: KeyPress) {
        switch press.action {
        case .hangul(let key):
            run(key)

        case .insert(let text):
            run(.literal(text))

        case .cycleSymbol(let options):
            run(.cycle(options))

        case .backspace:
            // 한 번 누르면 자모 하나, 꾹 누르면 글자 하나씩.
            if press.isRepeat { deleteWholeCharacter() } else { run(.backspace) }

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
        let context = readContext()
        // 사용자가 커서를 옮겼을 수 있다. 엔진을 부르기 전에 문서와 상태를 맞춘다.
        syncWithDocument(context)
        let output = signposter.withIntervalSignpost("Engine") {
            engine.handle(key, contextBefore: contextBeforeCursor(context))
        }
        apply(output)
    }

    /// 꾹 눌러 반복되는 삭제. 자모 단위로 풀지 않고 글자를 통째로 지운다.
    ///
    /// 반복 중에도 자모 단위로 지우면 글자 하나에 두세 박자가 들고, 그때마다
    /// 앞 글자를 지웠다가 덜 지운 모양으로 다시 넣느라 호스트 호출도 두 배가 된다.
    private func deleteWholeCharacter() {
        var count = 1
        if !preeditInDocument.isEmpty {
            // 조합 중이던 글자가 아직 커서 앞에 있는지 확인하고, 있으면 그 글자를 지운다.
            syncWithDocument(readContext())
            count = max(1, preeditInDocument.count)
        }
        finishComposing()
        let state = signposter.beginInterval("Proxy edit")
        for _ in 0 ..< count {
            textDocumentProxy.deleteBackward()
        }
        signposter.endInterval("Proxy edit", state, "delete=\(count) insert=0")
    }

    /// 키 눌림 피드백.
    ///
    /// 소리는 권한 없이도 나지만 햅틱은 전체 접근 권한이 있어야 한다.
    /// 권한이 없으면 `impactOccurred` 를 불러도 조용히 무시된다.
    private func playFeedback() {
        UIDevice.current.playInputClick()

        guard fullAccessGranted else { return }
        haptics.play()
    }

    /// 엔진 결과를 문서에 반영한다.
    ///
    /// iOS 에는 안드로이드 IME 같은 preedit API 가 없다.
    /// 조합 중인 글자를 직접 넣어 두고, 바뀌면 지우고 다시 넣는 식으로 흉내 낸다.
    private func apply(_ output: KeyOutput) {
        let proxy = textDocumentProxy

        // 호스트에 보내는 호출은 하나하나가 프로세스를 건너간다. 꼭 필요한 만큼만 보낸다.
        // 무엇을 지우고 넣을지는 `KeyOutput.edit` 이 정한다.
        let edit = output.edit(replacing: preeditInDocument)
        let state = signposter.beginInterval("Proxy edit")
        for _ in 0 ..< edit.deleteCount {
            proxy.deleteBackward()
        }
        for text in edit.inserts {
            proxy.insertText(text)
        }
        signposter.endInterval(
            "Proxy edit", state, "delete=\(edit.deleteCount) insert=\(edit.inserts.count)"
        )
        preeditInDocument = output.preedit
    }

    /// 조합 중인 글자가 아직 커서 바로 앞에 있는지 확인한다.
    ///
    /// 사용자가 화면을 탭해 커서를 옮기면 우리가 넣어 둔 조합 글자는
    /// 더 이상 커서 앞에 없다. 그대로 두면 다음 키 입력 때
    /// 엉뚱한 글자를 지우게 된다. 어긋났으면 조합을 버리고 새로 시작한다.
    private func syncWithDocument(_ context: String?) {
        // 커서 앞에 글자가 없으면 빈 문자열이 아니라 nil 이 온다. 조합 중에 이렇게 되는 건
        // 호스트가 입력창을 비웠거나(카톡 전송) 사용자가 커서를 맨 앞으로 옮긴 경우다.
        // 그때만 호스트에 한두 번 더 묻는다. 조합 중에 nil 이 오는 일 자체가 드물어서
        // 이 추가 왕복은 키 입력 경로에 거의 안 걸린다.
        let proxy = textDocumentProxy
        let signposter = signposter
        let shouldFinish = PreeditSync.shouldFinishComposing(
            preedit: preeditInDocument,
            contextBefore: context,
            hasText: { signposter.withIntervalSignpost("Has text") { proxy.hasText } },
            contextAfter: {
                signposter.withIntervalSignpost("Context after") { proxy.documentContextAfterInput }
            }
        )
        if shouldFinish { finishComposing() }
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

/// 키 눌림 진동.
///
/// `UIImpactFeedbackGenerator` 는 키를 0.5초쯤 안 누르면 시스템이 햅틱 엔진을 꺼 버린다.
/// `prepare()` 를 매번 불러도 마찬가지였다. 그다음 키는 엔진을 다시 켜느라
/// 진동이 30~100ms 늦게 온다. 생각하다 친 첫 글자마다 진동이 글자보다 한 박자 늦는 셈이다.
///
/// 그래서 엔진을 직접 들고 있는다. 자동 종료를 끄고 키보드가 떠 있는 동안 켜 두되,
/// `idleTimeout` 동안 아무 키도 안 누르면 배터리를 아끼려고 끈다.
/// 재생기는 엔진이 켜질 때 한 번 만들어 두고 키마다 다시 쓴다.
/// 엔진이 꺼져 있는 동안 누른 키는 예전 방식으로 진동하고, 그 사이 엔진을 다시 켠다.
final class KeyHaptics {
    /// 이만큼 키를 안 누르면 엔진을 끈다.
    private let idleTimeout: TimeInterval = 10

    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?
    private var isRunning = false
    private var isStarting = false
    private var idleStop: DispatchWorkItem?

    /// 엔진이 아직 안 켜졌을 때 쓰는 예전 방식.
    private let fallback = UIImpactFeedbackGenerator(style: .light)

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = try? CHHapticEngine()
        else { return }
        engine.isAutoShutdownEnabled = false
        engine.playsHapticsOnly = true
        // 다른 앱이 오디오·햅틱을 가져가는 등 시스템이 엔진을 멈출 때.
        engine.stoppedHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.markStopped() }
        }
        // 햅틱 서버가 재시작되면 재생기가 무효가 된다. 다음 키에 다시 켠다.
        engine.resetHandler = { [weak self] in
            DispatchQueue.main.async { self?.markStopped() }
        }
        self.engine = engine
    }

    /// 키보드가 올라올 때 엔진을 미리 켠다.
    func warmUp() {
        start()
        fallback.prepare()
        scheduleIdleStop()
    }

    func play() {
        scheduleIdleStop()
        if isRunning, let player, (try? player.start(atTime: CHHapticTimeImmediate)) != nil {
            return
        }
        fallback.impactOccurred(intensity: 0.7)
        start()
    }

    func stop() {
        idleStop?.cancel()
        idleStop = nil
        guard let engine, isRunning || isStarting else { return }
        engine.stop(completionHandler: nil)
        markStopped()
    }

    private func start() {
        guard let engine, !isRunning, !isStarting else { return }
        isStarting = true
        engine.start { [weak self] error in
            DispatchQueue.main.async {
                guard let self, self.isStarting else { return }
                self.isStarting = false
                guard error == nil else { return }
                self.player = self.makePlayer(engine)
                self.isRunning = self.player != nil
            }
        }
    }

    private func makePlayer(_ engine: CHHapticEngine) -> CHHapticPatternPlayer? {
        // UIImpactFeedbackGenerator(.light) 를 0.7 세기로 친 것과 비슷하게 맞췄다.
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.55),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
            ],
            relativeTime: 0
        )
        guard let pattern = try? CHHapticPattern(events: [event], parameters: []) else { return nil }
        return try? engine.makePlayer(with: pattern)
    }

    private func markStopped() {
        isRunning = false
        isStarting = false
        player = nil
    }

    private func scheduleIdleStop() {
        idleStop?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.stop() }
        idleStop = work
        DispatchQueue.main.asyncAfter(deadline: .now() + idleTimeout, execute: work)
    }
}
