# Download the binaries from GitHub.
version = "1.4.5"
lib_url = "https://github.com/erikas-taroza/audiotags/releases/download/v#{version}/ios.zip"
lib = "${PODS_ROOT}/../.symlinks/plugins/audiotags/ios/Frameworks/audiotags.xcframework"

`
mkdir -p Frameworks
cd Frameworks
if [ ! -d audiotags.xcframework ]
then
  curl -L "#{lib_url}" -o ios.zip
  unzip ios.zip -d 'audiotags.xcframework'
fi
cd ..
`

Pod::Spec.new do |s|
  s.name             = 'audiotags'
  s.version          = '1.4.5'
  s.summary          = 'A newFlutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '9.0'
  s.static_framework = true

  # dart finds the symbols in the app binary so load all of them and dont strip
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS[sdk=iphoneos*]' => "$(inherited) -force_load \"#{lib}/ios-arm64/libaudiotags.a\"",
    'OTHER_LDFLAGS[sdk=iphonesimulator*]' => "$(inherited) -force_load \"#{lib}/ios-arm64_x86_64-simulator/libaudiotags.a\"",
    'STRIP_STYLE' => 'non-global',
  }
  s.swift_version = '5.0'
end
