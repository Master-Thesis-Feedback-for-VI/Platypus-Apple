image_flow_path := "." / "image-flow"
app_source_root := "." / "Platypus"

insert_lib:
    cd {{image_flow_path}} && just swift-build-xcode-bindings 
    mkdir -p {{app_source_root / "Frameworks"}}
    mkdir -p {{app_source_root / "Generated"}}
    rm -rf {{app_source_root / "Frameworks" / "Mobile.xcframework"}}
    ditto {{image_flow_path / "ios" / "Mobile.xcframework"}} {{app_source_root / "Frameworks" / "Mobile.xcframework"}}
    cp {{image_flow_path / "bindings" / "swift" / "image_flow.swift"}} {{app_source_root / "Generated" / "image_flow.swift"}} 

