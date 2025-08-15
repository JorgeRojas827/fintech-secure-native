Pod::Spec.new do |s|
  s.name         = "SecureCardNative"
  s.version      = "1.0.15"
  s.summary      = "Secure native view for displaying sensitive card data"
  s.description  = <<-DESC
                   A React Native module that provides secure native views for displaying
                   sensitive card data with screenshot protection and security features.
                   DESC
  s.homepage     = "https://github.com/JorgeRojas827/fintech-secure-native"
  s.license      = "MIT"
  s.author       = { "Jorge Luis Rojas Poma" => "jorgerojaspoma09@gmail.com" }
  s.platform     = :ios, "11.0"
  s.source       = { :git => "https://github.com/JorgeRojas827/fintech-secure-native", :tag => "#{s.version}" }

  s.source_files  = "ios/**/*.{h,m,mm,swift}"
  s.requires_arc = true
  s.swift_version = "5.0"

  s.dependency "React-Core"
  
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
end
