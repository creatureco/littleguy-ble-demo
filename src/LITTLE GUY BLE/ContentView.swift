//
//  ContentView.swift
//  LITTLE GUY BLE
//
//  Created by Daniel Kuntz on 4/13/25.
//

import SwiftUI

struct VerticalDivider: View {
    var body: some View {
        Rectangle()
            .foregroundStyle(Color.white)
            .frame(width: 1.0)
            .opacity(0.1)
    }
}

struct HorizontalDivider: View {
    var body: some View {
        Rectangle()
            .foregroundStyle(Color.white)
            .frame(height: 1.0)
            .opacity(0.1)
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }

    func clamped(toLowerBound lowerBound: Self, upperBound: Self) -> Self {
        return min(max(self, lowerBound), upperBound)
    }
}

struct LookDirectionView: View {
    @StateObject private var ble = LittleGuyBLE.shared
    @State private var lookDirection: CGPoint = .init(x: 0.5, y: 0.5)

    private let CANVAS_WIDTH: CGFloat = 240
    private let CANVAS_HEIGHT: CGFloat = 135

    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 10.0)
                    .fill(Color.white.opacity(0.15))
                    .stroke(Color.white.opacity(0.15), lineWidth: 1.0)

                VerticalDivider()
                HorizontalDivider()

                Circle()
                    .fill(Color.blue)
                    .frame(width: 14.0, height: 14.0)
                    .offset(x: (lookDirection.x * CANVAS_WIDTH) - CGFloat((CANVAS_WIDTH / 2)),
                            y: (lookDirection.y * CANVAS_HEIGHT) - CGFloat((CANVAS_HEIGHT / 2)))
            }
            .frame(width: CGFloat(CANVAS_WIDTH), height: CGFloat(CANVAS_HEIGHT))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let point = CGPoint(x: (value.location.x / CANVAS_WIDTH).clamped(to: 0...1),
                                            y: (value.location.y / CANVAS_HEIGHT).clamped(to: 0...1))
                        self.lookDirection = point
                    }
            )
            .overlay {
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 20.0, height: 20.0)
                            .overlay {
                                Image(systemName: "arrow.uturn.backward")
                                    .foregroundStyle(Color.white)
                                    .font(.system(size: 10.0, weight: .bold))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                lookDirection = .init(x: 0.5, y: 0.5)
                            }
                            .opacity(lookDirection == .init(x: 0.5, y: 0.5) ? 0.0 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: lookDirection)
                    }
                }
                .padding(4.0)
            }

            Text("LOOK")
                .font(.system(size: 10.0, weight: .medium))
                .opacity(0.5)
        }
        .onChange(of: self.lookDirection) { oldValue, newValue in
            ble.setLookDirection(x: Float(newValue.x),
                                 y: Float(1.0 - newValue.y))
        }
    }
}


struct StateTransitionButton: View {
    @StateObject private var ble = LittleGuyBLE.shared
    @State private var commandState: CommandState = .idle
    var state: String

    enum CommandState {
        case idle
        case success
        case error

        var color: Color {
            switch self {
            case .idle:
                return .white
            case .success:
                return .green
            case .error:
                return .red
            }
        }
    }

    var body: some View {
        Button {
            ble.transitionToState(state) { success, error in
                if success {
                    commandState = .success
                } else {
                    if let error = error {
                        print(error.localizedDescription)
                    }
                    commandState = .error
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    commandState = .idle
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8.0)
                    .fill(commandState.color)
                    .opacity(0.15)
                Text(state)
                    .foregroundStyle(commandState.color)

                HStack {
                    Spacer()
                    switch commandState {
                    case .idle:
                        EmptyView()
                    case .success:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(commandState.color)
                    case .error:
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(commandState.color)
                    }
                }
                .padding(.trailing, 12.0)
            }
            .animation(.easeInOut(duration: 0.2), value: commandState)
        }
        .frame(height: 50.0)
    }
}

struct ContentView: View {
    @StateObject var ble = LittleGuyBLE.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                Spacer()

                HStack {
                    Circle()
                        .fill(ble.connected ? .green : .red)
                        .frame(width: 10.0)
                    Text(ble.connected ? "Connected" : "Not connected")
                        .foregroundStyle(Color.white)
                }

                Spacer()

                VStack(spacing: 30.0) {
                    LookDirectionView()

                    VStack {
                        StateTransitionButton(state: "default")
                        StateTransitionButton(state: "angry")
                        StateTransitionButton(state: "eepy")
                        StateTransitionButton(state: "circle")
                        StateTransitionButton(state: "wave")
                    }
                }
                .opacity(ble.connected ? 1.0 : 0.5)
                .allowsHitTesting(ble.connected)
                .animation(.easeInOut(duration: 0.2), value: ble.connected)

                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
