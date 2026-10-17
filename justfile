image_flow_path := "." / "image-flow"
app_source_root := "." / "Platypus"
frameworks_path := app_source_root / "ImageFlowLib" / "Frameworks"
generated_path := app_source_root / "ImageFlowLib" / "Generated"

[group('mqtt')]
post:
    for cmd in 0 1 2; do \
        npx mqtt pub -t 'IoT/device/profile_swap' \
            -m "{\"device\":\"GalaxyWatch\",\"tag\":\"IoT/device/profile_swap\",\"data\":\"{\\\"cmd\\\":$cmd}\"}" \
            -h mqtt.yannbernard.com \
            -p 443 --protocol wss \
            -u iotdevice -P image-flow; \
    done

[group('mqtt')]
sub_left:
    npx mqtt sub -t 'IoT/device/haptic_left' \
        -h mqtt.yannbernard.com -p 443 --protocol wss \
        -u iotdevice -P image-flow -v

[group('mqtt')]
sub_right:
    npx mqtt sub -t 'IoT/device/haptic_right' \
        -h mqtt.yannbernard.com -p 443 --protocol wss \
        -u iotdevice -P image-flow -v


insert_lib:
    cd {{image_flow_path}} && just swift-build-xcode-bindings 
    rm -rf {{frameworks_path}} {{generated_path}}
    mkdir -p {{frameworks_path}}
    mkdir -p {{generated_path}}
    ditto {{image_flow_path / "ios" / "Mobile.xcframework"}} {{frameworks_path / "Mobile.xcframework"}}
    cp {{image_flow_path / "bindings" / "swift" / "image_flow.swift"}} {{generated_path / "image_flow.swift"}} 
