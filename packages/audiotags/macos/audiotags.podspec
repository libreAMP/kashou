# Download the binary from GitHub.
version = "1.4.5"
lib_url = "https://github.com/erikas-taroza/audiotags/releases/download/v#{version}/macos.zip"
lib = "${PODS_ROOT}/../Flutter/ephemeral/.symlinks/plugins/audiotags/macos/Libs/libaudiotags.a"

`
mkdir -p Libs
cd Libs
if [ ! -f libaudiotags.a ]
then
  curl -L "#{lib_url}" -o macos.zip
  unzip macos.zip
  rm macos.zip
fi
cd ..
`

Pod::Spec.new do |s|
  s.name             = 'audiotags'
  s.version          = '1.4.5'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.static_framework = true

  s.platform = :osx, '10.14'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => "$(inherited) -force_load \"#{lib}\"",
    'STRIP_STYLE' => 'non-global',
  }
  s.swift_version = '5.0'
end
