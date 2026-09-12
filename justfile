image_flow_path := "." / "image-flow"
app_source_root := "." / "Platypus"
frameworks_path := app_source_root / "Frameworks"
generated_path := app_source_root / "Generated"

insert_lib:
    cd {{image_flow_path}} && just swift-build-xcode-bindings 
    rm -rf {{frameworks_path}} {{generated_path}}
    mkdir -p {{frameworks_path}}
    mkdir -p {{generated_path}}
    ditto {{image_flow_path / "ios" / "Mobile.xcframework"}} {{app_source_root / "Frameworks" / "Mobile.xcframework"}}
    cp {{image_flow_path / "bindings" / "swift" / "image_flow.swift"}} {{app_source_root / "Generated" / "image_flow.swift"}} 

