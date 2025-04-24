require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "RNBluetoothEscposPrinter"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.author       = 'januslo'
  s.homepage     = 'https://github.com/januslo/react-native-bluetooth-escpos-printer'
  s.license      = package["license"]
  s.platform     = :ios, "9.0"
  s.source       = { :git => "https://github.com/ReneMercado/react-native-bluetooth-nest-printer", :tag => "#{s.version}" }
  s.source_files  = "ios/*.{h,m}"
  s.exclude_files = "ios/ZXingObjC-3.2.2/**/*"
  s.dependency "React"
  s.dependency "ZXingObjC", "~> 3.6.5"
end