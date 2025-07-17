fn main() {
    uniffi::generate_scaffolding("./uniffi/anoncreds_uniffi.udl").unwrap();

    let target = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    let min_ios_version = "17.5";
    let macosx_deployment_target = "14.5";

    match target.as_str() {
        "ios" => {
            println!("cargo:rustc-link-arg=-mios-version-min={}", min_ios_version);
            // OpenSSL 빌드에 영향을 미치는 환경 변수 설정
            println!("cargo:rustc-env=IOS_DEPLOYMENT_TARGET={}", min_ios_version);
        },
        "macos" => {
            println!("cargo:rustc-link-arg=-mmacosx-version-min={}", macosx_deployment_target);
            // OpenSSL 빌드에 영향을 미치는 환경 변수 설정
            println!("cargo:rustc-env=MACOSX_DEPLOYMENT_TARGET={}", macosx_deployment_target);
        },
        _ => {}
    }
}
