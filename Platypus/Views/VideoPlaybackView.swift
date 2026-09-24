//
//  VideoPlaybackView.swift
//  Platypus
//
//  Created by Yann Bernard on 24.09.26.
//

import AVKit
import SwiftUI

struct VideoPlaybackView: View {
    let videoPlayback: VideoPlayback

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer
    @State private var currentSeconds: Double = 0
    @State private var timeObserverToken: Any?

    @State private var uniqueLocationTags = UniqueLocationTags(
        categories: [],
        isInside: false
    )
    @State private var imageDetections = ImageDetections(detections: [])

    init(playback: VideoPlayback) {
        videoPlayback = playback
        _player = State(initialValue: AVPlayer(url: videoPlayback.videoPath))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.clear

                VideoPlayer(player: player)
                    .ignoresSafeArea()

                //                ProgressIndicatorView(uniqueLocationTags: <#T##UniqueLocationTags#>, detectedObjects: <#T##ImageDetections#>)

                ProgressIndicatorView(
                    uniqueLocationTags: uniqueLocationTags,
                    detectedObjects: imageDetections
                ).padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .onAppear {
                player.play()
                addTimeObserver()
            }
            .onDisappear {
                player.pause()
                removeTimeObserver()
            }
        }
    }

    private func addTimeObserver() {
        let interval = CMTime(
            seconds: 0.5,
            preferredTimescale: CMTimeScale(NSEC_PER_SEC)
        )
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { time in
            currentSeconds = time.seconds
        }
    }

    private func removeTimeObserver() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
}
